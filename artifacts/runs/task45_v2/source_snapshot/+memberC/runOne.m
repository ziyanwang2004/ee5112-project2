function result=runOne(taskId,scenarioId,seed,c,folder)
assert(strcmp(version('-release'),'2023b'),'Use MATLAB R2023b.');
assert(ismember(taskId,[4 5]) && isscalar(seed));
assert(~exist(folder,'dir'),'Choose a new output directory: %s',folder);
mkdir(folder); diary(fullfile(folder,'run_log.txt')); diaryGuard=onCleanup(@()diary('off')); %#ok<NASGU>
totalTimer=tic; c.seed=seed; c.showFigures=false; c.writeVideo=false;
if taskId==4, c.constraintMode='none'; end
if taskId==5 && strcmp(c.constraintMode,'none'), c.constraintMode='penalty'; end
c.constraintFcn=[]; c.projectionFcn=[];
if ~strcmp(c.constraintMode,'none')
    weight=c.orientationWeight;
    c.constraintFcn=@(q,Tee)weight*norm(Tee(1:3,2)-[0;0;1],1);
end
if strcmp(c.constraintMode,'projected'), c.projectionFcn=@memberC.projectTrajectory; end
robot=loadrobot('universalUR5','DataFormat','column');
poeModel=memberB.buildPoeModel(robot,'tool0'); geometry=memberB.loadUR5Spheres(poeModel);
scene=memberC.makeScene(poeModel,c,scenarioId); voxel_world=makeVoxelWorld(scene.boxes,c);
plannerOptions=c; robot_struct=copy(robot); robot_struct.DataFormat='struct';
context=struct('options',c,'geometry',geometry, ...
    'kinematics',struct('mode','poe','robot',robot,'model',poeModel));
context.selfGeometry=memberC.buildSelfGeometry(robot,poeModel);
[~,startGaps]=memberC.selfClearance(context.selfGeometry,memberB.poeFK(poeModel,scene.qStart));
[~,goalGaps]=memberC.selfClearance(context.selfGeometry,memberB.poeFK(poeModel,scene.qGoal));
% Avoid penalizing unavoidable conservative overlaps already present at the
% independently mesh-validated endpoints. This never relaxes the mesh gate.
context.selfThreshold=min(c.selfMargin,min(startGaps,goalGaps));
fk=@(q)memberB.poeFK(poeModel,q); runFolder=folder; metadata=memberC.provenance();
for q={scene.qStart,scene.qGoal}
    [ok,~]=memberC.validatePath([q{1},q{1}],context, ...
        struct('qStart',q{1},'qGoal',q{1},'boxes',scene.boxes),voxel_world,c.finalDenseJointStep);
    assert(ok,'A fixed endpoint is infeasible.');
end
initial=scene.qStart+(scene.qGoal-scene.qStart)*linspace(0,1,c.nWaypoints);
initialMesh=memberB.checkMatlabPath(robot,initial,scene,c);
assert(~initialMesh.worldCollisionFree,'Initialization must actually collide.');
voxelStored=rmfield(voxel_world,'interpolant');
selfGeometry=context.selfGeometry; selfThreshold=context.selfThreshold;
save(fullfile(folder,'input_checkpoint.mat'),'plannerOptions','scene','poeModel','geometry','selfGeometry','selfThreshold','voxelStored','metadata','-v7');
fprintf('TASK%d %s seed %d mode %s weight %.0f noise %.2f\n',taskId,scenarioId,seed,c.constraintMode,c.orientationWeight,c.noiseStd);
helperSTOMP;
result=plannerResult; result.task=taskId; result.scenarioId=scenarioId; result.seed=seed;
result.constraintMode=c.constraintMode; result.initialMeshValidation=initialMesh;
[result.success,result.acceptance]=memberC.validatePath(result.theta,context,scene,voxel_world,c.finalDenseJointStep);
result.meshValidation=result.acceptance.mesh; result.matlabVersion=version;
result.totalSeconds=toc(totalTimer); result.metadata=metadata;
save(fullfile(folder,'planning_result.mat'),'result','plannerOptions','scene','poeModel','geometry','voxelStored','R','M','-v7');
memberB.writeCSV(fullfile(folder,'trajectory.csv'),'q1_rad,q2_rad,q3_rad,q4_rad,q5_rad,q6_rad',result.theta.');
memberB.writeCSV(fullfile(folder,'cost_history.csv'),'restart,iteration,total_cost,voxel_gap_m,smoothness,accepted_code,alpha',result.history);
v=result.acceptance;
memberB.writeCSV(fullfile(folder,'dense_validation.csv'), ...
    'path_parameter,voxel_gap_m,sphere_gap_m,orientation_deg,world_collision,self_collision,mesh_gap_m', ...
    [v.s.',v.voxelClearance.',v.sphereClearance.',v.orientationDeg.',v.mesh.worldInCollision.',v.mesh.selfInCollision.',v.mesh.worldSeparation.']);
brief=memberC.summarizeRun(result,c);
memberC.writeJSON(fullfile(folder,'summary.json'),brief);
fprintf('RESULT success=%d voxel=%.6f m tilt=%.4f deg iterations=%d time=%.2f s\n', ...
    result.success,v.minVoxelClearance,v.maxOrientationDeg,size(result.history,1),result.elapsedSeconds);
end
