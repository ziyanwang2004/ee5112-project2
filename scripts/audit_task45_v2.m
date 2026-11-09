function audit_task45_v2(runRoot)
root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'upgrades','task45_v2','matlab'),'-begin');
if nargin<1, runRoot=fullfile(root,'artifacts','runs','task45_v2','development','self_filter_60000'); end
addpath(fullfile(root,'upgrades','task45_v2','matlab','tests'));
test_task45();
now=memberC.provenance(); files=dir(fullfile(runRoot,'**','planning_result.mat'));
assert(~isempty(files)); robot=loadrobot('universalUR5','DataFormat','column');
auditedCosts=0; acceptedSafetyReceipts=0; feasibleCostIncreases={};
for k=1:numel(files)
    folder=files(k).folder; d=load(fullfile(folder,'input_checkpoint.mat')); c=d.plannerOptions;
    assert(strcmp(d.metadata.sourceFingerprint,now.sourceFingerprint),'Sources changed during study.');
    context=struct('options',c,'geometry',d.geometry,'selfGeometry',d.selfGeometry, ...
        'selfThreshold',d.selfThreshold,'kinematics',struct('mode','poe','robot',robot,'model',d.poeModel));
    assert(memberC.selfPathSafe([c.qStart,c.qStart],context));
    bad=load(fullfile(root,'artifacts','runs','task45_v2','diagnosis','raw_probe_evidence','collision_probe.mat'));
    assert(~memberC.selfPathSafe([bad.q,bad.q],context),'Hard self filter missed the known collision.');
    w=makeVoxelWorld(d.scene.boxes,c); traces=dir(fullfile(folder,'iterations','*.mat')); previousMetric=[];
    for j=1:numel(traces)
        a=load(fullfile(traces(j).folder,traces(j).name));
        if a.metrics(6)==1
            alphaIndex=find([1 .5 .25]==a.metrics(7));
            assert(a.feasibleAccepted || a.candidateSelfSafe(alphaIndex)==1);
            acceptedSafetyReceipts=acceptedSafetyReceipts+1;
        elseif a.metrics(6)==2
            assert(a.sampleSelfSafe(a.acceptedSample)==1);
            acceptedSafetyReceipts=acceptedSafetyReceipts+1;
        end
        if ~isempty(previousMetric) && a.metrics(1)==previousMetric(1) && a.metrics(3)>previousMetric(3)+1e-8
            assert(a.feasibleAccepted,'Cost increased without a feasibility-priority decision.');
            assert(memberC.validatePath(a.thetaAfter,context,d.scene,w,c.finalDenseJointStep));
            feasibleCostIncreases{end+1}=struct('checkpoint',fullfile(traces(j).folder,traces(j).name), ...
                'before',previousMetric(3),'after',a.metrics(3)); %#ok<AGROW>
        end
        previousMetric=a.metrics;
        if j==1 || j==numel(traces) || mod(j,10)==0
            [~,cost]=stompTrajCost(robot,a.thetaAfter,a.R,w,context);
            assert(abs(cost-a.metrics(3))<1e-8,'Recomputed objective mismatch.');
            auditedCosts=auditedCosts+1;
        end
    end
end
audit=verify_task45(runRoot); audit.sourceFingerprint=now.sourceFingerprint;
audit.recomputedCosts=auditedCosts; audit.acceptedSafetyReceipts=acceptedSafetyReceipts;
audit.hardFilterKnownCollisionPassed=true;
audit.verifiedFeasibleCostIncreases=feasibleCostIncreases;
fid=fopen([mfilename('fullpath') '.m'],'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
audit.auditScriptSha256=memberC.sha256(bytes);
memberC.writeJSON(fullfile(runRoot,'independent_audit.json'),audit);
fprintf('V2 INDEPENDENT AUDIT PASSED: %d runs, %d successes, %d replayed updates\n',audit.runs,audit.successfulRuns,audit.replayedCheckpoints);
end
