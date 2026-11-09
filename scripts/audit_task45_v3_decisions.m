% Additional objective and in-loop decision audit, separate from full replay.
root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'upgrades','task45_v3','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v3');
frozen=load(fullfile(release,'frozen_config.mat')); identity=memberC.provenance();
assert(strcmp(identity.sourceFingerprint,frozen.frozen.metadata.sourceFingerprint));
files=dir(fullfile(release,'formal','**','planning_result.mat')); assert(numel(files)==40);
costs=0; safety=0; feasibleIncreases=0; checkpoints=0; commits={};
for k=1:numel(files)
    folder=files(k).folder; d=load(fullfile(folder,'input_checkpoint.mat')); c=d.plannerOptions;
    assert(strcmp(d.metadata.sourceFingerprint,identity.sourceFingerprint));
    commits{end+1}=d.metadata.commit; %#ok<SAGROW>
    robot=memberC.loadRobot();
    context=struct('options',c,'geometry',d.geometry,'selfGeometry',d.selfGeometry, ...
        'selfThreshold',d.selfThreshold,'kinematics',struct('mode','poe','robot',robot,'model',d.poeModel));
    w=makeVoxelWorld(d.scene.boxes,c); traces=dir(fullfile(folder,'iterations','*.mat')); previous=[];
    for j=1:numel(traces)
        a=load(fullfile(traces(j).folder,traces(j).name)); checkpoints=checkpoints+1;
        if a.metrics(6)==1
            index=find([1 .5 .25]==a.metrics(7)); assert(isscalar(index));
            assert(a.feasibleAccepted || a.candidateSelfSafe(index)==1); safety=safety+1;
        elseif a.metrics(6)==2
            assert(a.sampleSelfSafe(a.acceptedSample)==1); safety=safety+1;
        end
        if ~isempty(previous) && a.metrics(1)==previous(1) && a.metrics(3)>previous(3)+1e-8
            assert(a.feasibleAccepted,'Cost increase lacks feasible-priority decision.');
            feasibleIncreases=feasibleIncreases+1;
        end
        if j==1 || j==numel(traces) || mod(j,10)==0
            [~,cost]=stompTrajCost(robot,a.thetaAfter,a.R,w,context);
            assert(abs(cost-a.metrics(3))<1e-8,'Recomputed V3 objective differs.'); costs=costs+1;
        end
        previous=a.metrics;
    end
    fprintf('V3 DECISION AUDIT run %d/%d seed %d: %d checkpoints passed\n',k,numel(files),c.seed,numel(traces));
end
scene=d.scene;
memberC.writeJSON(fullfile(release,'scene_definition.json'),scene);
receipt=struct('passed',true,'runs',numel(files),'checkpoints',checkpoints, ...
    'recomputedCosts',costs,'recordedSafetyReceipts',safety,'feasibilityPriorityCostIncreases',feasibleIncreases, ...
    'sourceFingerprint',identity.sourceFingerprint,'recordedGitCommits',{unique(commits)}, ...
    'scope','Recomputed saved accepted-state objectives and checked in-loop decision receipts; full random replay and final path collision checks are separate.');
memberC.writeJSON(fullfile(release,'decision_audit.json'),receipt);
fprintf('V3 DECISION/COST AUDIT PASSED\n');
