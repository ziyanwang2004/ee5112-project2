function audit=audit_task45_v4(runRoot,receiptPath)
% Full random/update replay and fresh mesh validation, plus finer final check.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v4','matlab'),'-begin');
audit=verify_task45(runRoot); files=dir(fullfile(runRoot,'**','planning_result.mat'));
fine=cell(1,numel(files)); recomputedSearchCosts=0; verifiedRefineSamples=0;
for k=1:numel(files)
    folder=files(k).folder; d=load(fullfile(folder,'planning_result.mat')); c=d.plannerOptions;
    input=load(fullfile(folder,'input_checkpoint.mat')); robot=memberC.loadRobot();
    model=memberB.buildPoeModel(robot,'tool0'); geometry=memberB.loadUR5Spheres(model);
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
    for j=1:numel(traces)
        a=load(fullfile(traces(j).folder,traces(j).name));
        if ~isempty(previous) && a.metrics(1)==previous.restart, assert(isequal(a.rngBefore,previous.state)); end
        if j==1 || j==numel(traces) || mod(j,10)==0
            [~,cost]=stompTrajCost(robot,a.thetaAfter,a.R,w,context); assert(abs(cost-a.metrics(3))<1e-8);
            recomputedSearchCosts=recomputedSearchCosts+1;
        end
        previous=struct('restart',a.metrics(1),'state',a.rngAfter);
    end
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
