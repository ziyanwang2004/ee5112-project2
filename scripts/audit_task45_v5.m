function audit=audit_task45_v5(runRoot,receiptPath)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
inventory=dir(fullfile(runRoot,'**','planning_result.mat')); assert(~isempty(inventory));
cases={'workcell','endpoints','layout'}; variants={'ambient','energy_control','fixed50','fixed75','adaptive'};
if exist(fullfile(runRoot,'workcell'),'dir') && exist(fullfile(runRoot,'endpoints'),'dir')
    parts=[receiptPath(1:end-5) '_parts']; helper=fullfile(root,'scripts','audit_task45_v5_parallel.ps1');
    status=system(sprintf('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -RunRoot "%s" -ReceiptRoot "%s"',helper,runRoot,parts));
    assert(status==0,'Parallel V5 audit failed.');
    audit=struct('passed',true,'runs',0,'successfulRuns',0,'fineSuccessfulRuns',0,'replayedCheckpoints',0, ...
        'recomputedSearchCosts',0,'verifiedRefineSampleCosts',0,'details',[],'fineDetails',[],'fineJointStep',.00625);
    identity=memberC.provenance(); audit.sourceFingerprint=identity.sourceFingerprint;
    for id=cases
        for variant=variants
            p=jsondecode(fileread(fullfile(parts,[id{1} '_' variant{1} '.json']))); assert(p.passed && strcmp(p.sourceFingerprint,identity.sourceFingerprint));
            for name={'runs','successfulRuns','fineSuccessfulRuns','replayedCheckpoints','recomputedSearchCosts','verifiedRefineSampleCosts'}
                audit.(name{1})=audit.(name{1})+p.(name{1});
            end
            if isempty(audit.details), audit.details=p.details(:); else, audit.details=[audit.details;p.details(:)]; end
            if isempty(audit.fineDetails), audit.fineDetails=p.fineDetails(:); else, audit.fineDetails=[audit.fineDetails;p.fineDetails(:)]; end
        end
    end
    assert(audit.runs==numel(inventory)); memberC.writeJSON(receiptPath,audit); return;
end
audit=verify_task45(runRoot); identity=memberC.provenance(); audit.sourceFingerprint=identity.sourceFingerprint;
fine=cell(1,numel(inventory)); recomputed=0; checkedSamples=0; fineSuccesses=0;
for k=1:numel(inventory)
    folder=inventory(k).folder; d=load(fullfile(folder,'planning_result.mat')); input=load(fullfile(folder,'input_checkpoint.mat')); c=d.plannerOptions;
    assert(strcmp(d.result.metadata.sourceFingerprint,identity.sourceFingerprint));
    robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0'); geometry=memberB.loadUR5Spheres(model);
    selfGeometry=memberC.buildSelfGeometry(robot,model);
    assert(isequal(model.S,input.poeModel.S) && isequal(model.M,input.poeModel.M) && isequal(geometry,input.geometry) && isequal(selfGeometry,input.selfGeometry));
    scene=memberC.makeScene(model,c,d.scene.id); assert(isequal(scene,d.scene)); w=makeVoxelWorld(scene.boxes,c);
    [~,start]=memberC.selfClearance(selfGeometry,memberB.poeFK(model,c.qStart));
    [~,goal]=memberC.selfClearance(selfGeometry,memberB.poeFK(model,c.qGoal)); threshold=min(c.selfMargin,min(start,goal));
    assert(isequal(threshold,input.selfThreshold));
    frozenPath=fullfile(root,'artifacts','runs','task45_v5','frozen_config.mat');
    prefix=[fullfile(root,'artifacts','runs','task45_v5','formal') filesep];
    if exist(frozenPath,'file') && startsWith(folder,prefix,'IgnoreCase',true)
        f=load(frozenPath); omit={'seed','constraintFcn','validationFcn','projectionFcn'};
        assert(isequaln(rmfield(c,omit),rmfield(f.frozen.options.(scene.id).(c.variant),omit)));
    end
    context=struct('options',c,'geometry',geometry,'selfGeometry',selfGeometry,'selfThreshold',threshold, ...
        'kinematics',struct('mode','poe','robot',robot,'model',model));
    [ok,v]=memberC.validatePath(d.result.theta,context,scene,w,.00625,true);
    studySuccess=d.result.success && ok; fineSuccesses=fineSuccesses+studySuccess;
    fine{k}=struct('scenario',scene.id,'variant',c.variant,'task',d.result.task,'seed',d.result.seed, ...
        'nominalSuccess',d.result.success,'fineSuccess',ok,'studySuccess',studySuccess,'fineStates',v.nStates, ...
        'maxTilt',v.maxOrientationDeg,'minGap',v.minVoxelClearance,'minHeight',v.minToolHeight,'failures',{v.failures});
    [~,~,first]=memberC.qualityCost(d.result.searchTheta,context,w);
    fine{k}.firstJointLength=first.jointLength; fine{k}.firstSmoothness=first.smoothness;
    fine{k}.finalJointLength=v.jointPathLength; fine{k}.finalSmoothness=v.smoothness;
    files=dir(fullfile(folder,'iterations','*.mat')); previous=[]; sampling=emptySampling(); controllerHistory=zeros(0,6);
    for j=1:numel(files)
        a=load(fullfile(files(j).folder,files(j).name)); sampling=addSampling(sampling,a.samplingDiagnostics,c.nRollouts,c.nWaypoints);
        if strcmp(c.samplingMode,'adaptive')
            sampling.controllerChanges=sampling.controllerChanges+(a.samplingStateBefore.fraction~=a.samplingStateAfter.fraction);
            sampling.stagnationExploration=sampling.stagnationExploration+strcmp(a.samplingStateAfter.reason,'stagnation exploration');
            controllerHistory(end+1,:)=[a.metrics(1:2),a.samplingStateBefore.fraction,a.samplingStateAfter.fraction,a.samplingStateAfter.advantage,a.stall]; %#ok<AGROW>
        end
        if ~isempty(previous) && a.metrics(1)==previous.restart, assert(isequal(a.rngBefore,previous.state)); end
        if j==1 || j==numel(files) || mod(j,10)==0
            [~,cost]=stompTrajCost(robot,a.thetaAfter,a.R,w,context); assert(abs(cost-a.metrics(3))<1e-8); recomputed=recomputed+1;
        end
        previous=struct('restart',a.metrics(1),'state',a.rngAfter);
    end
    fine{k}.searchSampling=finishSampling(sampling); fine{k}.controllerHistory=controllerHistory; refined=dir(fullfile(folder,'refinement','*.mat'));
    state=previous.state; sampling=emptySampling();
    for j=1:numel(refined)
        a=load(fullfile(refined(j).folder,refined(j).name)); assert(isequal(state,a.rngBefore)); state=a.rngAfter;
        sampling=addSampling(sampling,a.samplingDiagnostics,c.refineRollouts,c.nWaypoints);
        if j==1 || j==numel(refined)
            saved=rng; guard=onCleanup(@()rng(saved)); rng(a.rngBefore);
            [samples,~,valid]=memberC.sampleRollouts(c.refineRollouts,a.sigma,a.thetaBefore,context);
            candidates=find(valid); [~,best]=min(a.sampleTotals);
            if ~isempty(candidates)
                for index=unique([candidates(1);best]).'
                    if ~valid(index), continue; end
                    [local,cost]=memberC.qualityCost(samples{index},context,w);
                    assert(max(abs(local-a.Stheta(index,:)))<1e-9 && abs(cost-a.sampleTotals(index))<1e-9); checkedSamples=checkedSamples+1;
                end
            end
            clear guard;
        end
    end
    fine{k}.refineSampling=finishSampling(sampling);
    fprintf('V5 EXTRA AUDIT %s %s seed %d nominal=%d study=%d passed\n',scene.id,c.variant,d.result.seed,d.result.success,studySuccess);
end
audit.fineJointStep=.00625; audit.fineDetails=fine; audit.fineSuccessfulRuns=fineSuccesses;
audit.recomputedSearchCosts=recomputed; audit.verifiedRefineSampleCosts=checkedSamples;
memberC.writeJSON(receiptPath,audit);
end
function s=emptySampling()
s=struct('iterations',0,'samples',0,'validSamples',0,'waypoints',0,'elements',0,'corrections',0, ...
    'preEnergy',0,'postEnergy',0,'ambientEnergy',0,'projectionSeconds',0,'tangentSeconds',0, ...
    'fractionSum',0,'minFraction',1,'maxFraction',0,'maxEnergyMatchError',0,'controllerChanges',0,'stagnationExploration',0);
end
function s=addSampling(s,d,count,N)
s.iterations=s.iterations+1; s.samples=s.samples+count; s.validSamples=s.validSamples+d.validSamples;
s.waypoints=s.waypoints+count*(N-2); s.elements=s.elements+count*(N-2)*6;
s.corrections=s.corrections+d.projectionCorrections; s.preEnergy=s.preEnergy+sum(d.preProjectionEnergy);
s.postEnergy=s.postEnergy+sum(d.postProjectionEnergy); s.ambientEnergy=s.ambientEnergy+sum(d.ambientEnergy);
s.projectionSeconds=s.projectionSeconds+d.projectionSeconds; s.tangentSeconds=s.tangentSeconds+d.tangentSeconds;
s.fractionSum=s.fractionSum+d.fraction; s.minFraction=min(s.minFraction,d.fraction); s.maxFraction=max(s.maxFraction,d.fraction);
s.maxEnergyMatchError=max(s.maxEnergyMatchError,d.energyMatchMaxRelativeError);
end
function s=finishSampling(s)
s.meanProjectionCorrectionsPerWaypoint=s.corrections/max(1,s.waypoints); s.meanFraction=s.fractionSum/max(1,s.iterations);
s.preProjectionRms=sqrt(s.preEnergy/max(1,s.elements)); s.postProjectionRms=sqrt(s.postEnergy/max(1,s.elements));
s.ambientRms=sqrt(s.ambientEnergy/max(1,s.elements)); s.validFraction=s.validSamples/max(1,s.samples);
end
