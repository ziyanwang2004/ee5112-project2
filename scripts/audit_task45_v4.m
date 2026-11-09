function audit=audit_task45_v4(runRoot,receiptPath)
% Full random/update replay and fresh mesh validation, plus finer final check.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v4','matlab'),'-begin');
inventory=dir(fullfile(runRoot,'**','planning_result.mat'));
if numel(inventory)>8 && exist(fullfile(runRoot,'baseline'),'dir') && exist(fullfile(runRoot,'tangent'),'dir')
    partsRoot=[receiptPath(1:end-5) '_parts'];
    helper=fullfile(root,'scripts','audit_task45_v4_parallel.ps1');
    command=sprintf('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -RunRoot "%s" -ReceiptRoot "%s"',helper,runRoot,partsRoot);
    status=system(command); assert(status==0,'Parallel independent audit failed.');
    audit=struct('passed',true,'runs',0,'successfulRuns',0,'replayedCheckpoints',0, ...
        'details',[],'fineDetails',[],'fineJointStep',.00625,'recomputedSearchCosts',0,'verifiedRefineSampleCosts',0);
    identity=memberC.provenance(); audit.sourceFingerprint=identity.sourceFingerprint;
    for variant={'baseline','anytime','tangent','combined'}
        part=jsondecode(fileread(fullfile(partsRoot,[variant{1} '.json']))); assert(part.passed);
        assert(strcmp(part.sourceFingerprint,identity.sourceFingerprint));
        for key={'runs','successfulRuns','replayedCheckpoints','recomputedSearchCosts','verifiedRefineSampleCosts'}
            audit.(key{1})=audit.(key{1})+part.(key{1});
        end
        if isempty(audit.details), audit.details=part.details(:); else, audit.details=[audit.details;part.details(:)]; end
        if isempty(audit.fineDetails), audit.fineDetails=part.fineDetails(:); else, audit.fineDetails=[audit.fineDetails;part.fineDetails(:)]; end
    end
    assert(audit.runs==numel(inventory)); memberC.writeJSON(receiptPath,audit); return;
end
audit=verify_task45(runRoot); files=dir(fullfile(runRoot,'**','planning_result.mat'));
identity=memberC.provenance(); audit.sourceFingerprint=identity.sourceFingerprint;
fine=cell(1,numel(files)); recomputedSearchCosts=0; verifiedRefineSamples=0;
for k=1:numel(files)
    folder=files(k).folder; d=load(fullfile(folder,'planning_result.mat')); c=d.plannerOptions;
    assert(strcmp(d.result.metadata.sourceFingerprint,identity.sourceFingerprint),'Audit source mismatch.');
    input=load(fullfile(folder,'input_checkpoint.mat')); robot=memberC.loadRobot();
    model=memberB.buildPoeModel(robot,'tool0'); geometry=memberB.loadUR5Spheres(model);
    assert(isequal(input.geometry,geometry) && isequal(input.poeModel.S,model.S) && isequal(input.poeModel.M,model.M),'Saved and freshly rebuilt geometry differ.');
    frozenPath=fullfile(root,'artifacts','runs','task45_v4','frozen_config.mat');
    formalPrefix=[fullfile(root,'artifacts','runs','task45_v4','formal') filesep];
    if exist(frozenPath,'file') && startsWith(folder,formalPrefix,'IgnoreCase',true)
        settings=load(frozenPath); omitted={'seed','constraintFcn','validationFcn','projectionFcn'};
        assert(isequaln(rmfield(c,omitted),rmfield(settings.frozen.options.(c.variant),omitted)),'Formal parameters differ from frozen arm.');
    end
    scene=memberC.makeScene(model,c,'workcell'); w=makeVoxelWorld(scene.boxes,c);
    context=struct('options',c,'geometry',geometry,'selfGeometry',input.selfGeometry,'selfThreshold',input.selfThreshold, ...
        'kinematics',struct('mode','poe','robot',robot,'model',model));
    [ok,v]=memberC.validatePath(d.result.theta,context,scene,w,.00625,true);
    fine{k}=struct('variant',c.variant,'task',d.result.task,'seed',d.result.seed,'nominalSuccess',d.result.success, ...
        'fineSuccess',ok,'maxTilt',v.maxOrientationDeg,'minGap',v.minVoxelClearance,'minHeight',v.minToolHeight,'failures',{v.failures});
    if d.result.success && ~ok
        memberC.writeJSON(strrep(receiptPath,'.json','_fine_failure.json'),fine{k});
        error('A nominal success failed the finer check; diagnostic saved.');
    end
    [firstLocal,firstQ,firstInfo]=memberC.qualityCost(d.result.searchTheta,context,w); %#ok<ASGLU>
    fine{k}.firstJointLength=firstInfo.jointLength; fine{k}.firstSmoothness=firstInfo.smoothness;
    fine{k}.finalJointLength=v.jointPathLength; fine{k}.finalSmoothness=v.smoothness;
    traces=dir(fullfile(folder,'iterations','*.mat')); previous=[];
    sampling=struct('requestedSamples',0,'validSamples',0,'projectionCorrections',0, ...
        'sampledInteriorWaypoints',0,'projectionSeconds',0,'tangentSeconds',0, ...
        'noiseSquaredSum',0,'noiseElements',0);
    for j=1:numel(traces)
        a=load(fullfile(traces(j).folder,traces(j).name));
        diagnostic=a.samplingDiagnostics;
        sampling.requestedSamples=sampling.requestedSamples+c.nRollouts;
        sampling.validSamples=sampling.validSamples+diagnostic.validSamples;
        sampling.projectionCorrections=sampling.projectionCorrections+diagnostic.projectionCorrections;
        sampling.sampledInteriorWaypoints=sampling.sampledInteriorWaypoints+c.nRollouts*(c.nWaypoints-2);
        sampling.projectionSeconds=sampling.projectionSeconds+diagnostic.projectionSeconds;
        sampling.tangentSeconds=sampling.tangentSeconds+diagnostic.tangentSeconds;
        if isfield(a,'em')
            for joint=1:numel(a.em)
                noise=a.em{joint}(:,2:end-1); sampling.noiseSquaredSum=sampling.noiseSquaredSum+sum(noise.^2,'all');
                sampling.noiseElements=sampling.noiseElements+numel(noise);
            end
        end
        if ~isempty(previous) && a.metrics(1)==previous.restart, assert(isequal(a.rngBefore,previous.state)); end
        if j==1 || j==numel(traces) || mod(j,10)==0
            [~,cost]=stompTrajCost(robot,a.thetaAfter,a.R,w,context); assert(abs(cost-a.metrics(3))<1e-8);
            recomputedSearchCosts=recomputedSearchCosts+1;
        end
        previous=struct('restart',a.metrics(1),'state',a.rngAfter);
    end
    sampling.meanProjectionCorrectionsPerWaypoint=sampling.projectionCorrections/max(1,sampling.sampledInteriorWaypoints);
    sampling.actualNoiseRms=sqrt(sampling.noiseSquaredSum/max(1,sampling.noiseElements));
    fine{k}.searchSampling=sampling;
    refined=dir(fullfile(folder,'refinement','*.mat')); state=previous.state;
    for j=1:numel(refined)
        a=load(fullfile(refined(j).folder,refined(j).name)); assert(isequal(a.rngBefore,state)); state=a.rngAfter;
        if j==1 || j==numel(refined)
            saved=rng; guard=onCleanup(@()rng(saved)); rng(a.rngBefore);
            [samples,~,valid]=memberC.sampleRollouts(c.refineRollouts,a.sigma,a.thetaBefore,context);
            candidates=find(valid); [~,best]=min(a.sampleTotals);
            if isempty(candidates), continue; end
            for index=unique([candidates(1);best]).'
                if ~valid(index), continue; end
                [local,cost]=memberC.qualityCost(samples{index},context,w);
                assert(max(abs(local-a.Stheta(index,:)))<1e-9 && abs(cost-a.sampleTotals(index))<1e-9);
                verifiedRefineSamples=verifiedRefineSamples+1;
            end
            clear guard;
        end
    end
    fprintf('V4 EXTRA AUDIT %s seed %d passed\n',c.variant,d.result.seed);
end
audit.fineJointStep=.00625; audit.fineDetails=fine;
audit.recomputedSearchCosts=recomputedSearchCosts; audit.verifiedRefineSampleCosts=verifiedRefineSamples;
memberC.writeJSON(receiptPath,audit);
end
