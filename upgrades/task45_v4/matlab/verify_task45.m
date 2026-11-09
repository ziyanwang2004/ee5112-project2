function audit=verify_task45(runRoot)
% Read-only independent checks. Legitimately failed experiments are allowed.
root=fileparts(mfilename('fullpath')); addpath(root);
files=dir(fullfile(runRoot,'**','planning_result.mat')); assert(~isempty(files),'No saved runs.');
audit=struct('passed',true,'runs',numel(files),'successfulRuns',0,'replayedCheckpoints',0);
audit.details=cell(numel(files),1);
for k=1:numel(files)
    folder=files(k).folder; d=load(fullfile(folder,files(k).name)); c=d.plannerOptions;
    robot=memberC.loadRobot();
    freshModel=memberB.buildPoeModel(robot,'tool0'); freshGeometry=memberB.loadUR5Spheres(freshModel);
    scene=memberC.makeScene(freshModel,c,d.scene.id); assert(isequal(scene.boxes,d.scene.boxes));
    w=makeVoxelWorld(scene.boxes,c);
    context=struct('options',c,'geometry',freshGeometry, ...
        'kinematics',struct('mode','poe','robot',robot,'model',freshModel));
    initial=scene.qStart+(scene.qGoal-scene.qStart)*linspace(0,1,c.nWaypoints);
    assert(isequal(initial,d.result.initial),'Initialization changed.');
    initialMesh=memberB.checkMatlabPath(robot,initial,scene,c);
    assert(~initialMesh.worldCollisionFree,'Trivial initialization.');
    [passed,v]=memberC.validatePath(d.result.theta,context,scene,w,c.finalDenseJointStep);
    assert(passed==d.result.success,'Stored success disagrees with independent validation.');
    assert(abs(v.minVoxelClearance-d.result.acceptance.minVoxelClearance)<1e-10);
    assert(abs(v.maxOrientationDeg-d.result.acceptance.maxOrientationDeg)<1e-9);
    assert(abs(v.minToolHeight-d.result.acceptance.minToolHeight)<1e-10);
    assert(v.toolAboveTable==d.result.acceptance.toolAboveTable);
    if d.result.success
        assert(memberC.validatePath(d.result.searchTheta,context,scene,w,c.finalDenseJointStep));
        [~,first]=memberC.qualityCost(d.result.searchTheta,context,w);
        [~,last]=memberC.qualityCost(d.result.theta,context,w);
        assert(abs(first-d.result.firstFeasibleQuality)<1e-9 && abs(last-d.result.finalQuality)<1e-9);
        assert(last<=first+1e-9,'Quality worsened after first feasible solution.');
    end
    replay=memberC.replayRun(folder);
    audit.successfulRuns=audit.successfulRuns+passed;
    audit.replayedCheckpoints=audit.replayedCheckpoints+replay.checkpoints;
    audit.details{k}=struct('folder',folder,'planningSuccess',passed,'replay',replay,'failures',{v.failures});
    fprintf('AUDIT %s success=%d replay=%d passed\n',folder,passed,replay.checkpoints);
end
end
