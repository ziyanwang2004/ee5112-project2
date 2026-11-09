function result=UR5_STOMP_Path_Planning(backend,plannerOptions,runFolder)
% UR5 adaptation of received KINOVA_STOMP_Path_Planning.m, for Tasks 2/3.
% Uses the received named STOMP stages, not the previous standalone planner.
if nargin<1, backend='poe'; end
if nargin<2, plannerOptions=sharedDefaults(); end
assert(strcmp(version('-release'),'2023b'),'Use MATLAB R2023b.');
assert(any(strcmp(backend,{'builtin','poe'})),'Use builtin or poe FK.');
root=fileparts(mfilename('fullpath')); addpath(root);
if nargin<3
    stamp=char(datetime('now','TimeZone','Asia/Shanghai','Format','yyyyMMdd_HHmmss_SSS'));
    runFolder=fullfile(root,'..','artifacts','local_runs',stamp,backend);
end
assert(~exist(fullfile(runFolder,'planning_result.mat'),'file'), ...
    'Do not overwrite a previous run. Choose a new run folder.');
if ~exist(runFolder,'dir'), mkdir(runFolder); end
diary(fullfile(runFolder,'run_log.txt')); diaryGuard=onCleanup(@()diary('off')); %#ok<NASGU>
[robot,robotData]=loadrobot(plannerOptions.robotName,'DataFormat','column');
poeModel=memberB.buildPoeModel(robot,plannerOptions.endEffector);
geometry=memberB.loadUR5Spheres(poeModel);
robot_struct=copy(robot); robot_struct.DataFormat='struct';
context.options=plannerOptions; context.geometry=geometry;
context.kinematics=struct('mode',backend,'robot',robot,'model',poeModel);
if strcmp(backend,'poe'), fk=@(q)memberB.poeFK(poeModel,q);
else, fk=@(q)memberB.builtinFK(robot,poeModel,q); end

helperCreateObstaclesUR5;
initial=scene.qStart+(scene.qGoal-scene.qStart)*linspace(0,1,plannerOptions.nWaypoints);
for q={scene.qStart,scene.qGoal}
    e=checkVoxelPath([q{1},q{1}],fk,geometry,voxel_world,plannerOptions.denseJointStep);
    assert(e.minClearance>plannerOptions.margin,'A fixed endpoint is infeasible.');
end
initialMesh=memberB.checkMatlabPath(robot,initial,scene,plannerOptions);
assert(~initialMesh.worldCollisionFree,'Expected a nontrivial colliding initialization.');
memberB.exportScrews(poeModel,runFolder);
if strcmp(backend,'poe'), fkValidation=memberB.validatePoe(robot,poeModel,runFolder);
else, fkValidation=[]; end
voxelStored=rmfield(voxel_world,'interpolant');
save(fullfile(runFolder,'input_checkpoint.mat'),'plannerOptions','scene', ...
    'poeModel','geometry','robotData','voxelStored','-v7');

helperSTOMP;

result=plannerResult; result.backend=backend;
if strcmp(backend,'builtin'), result.task=2; else, result.task=3; end
result.matlabVersion=version; result.runFolder=runFolder;
result.initialMeshValidation=initialMesh; result.fkValidation=fkValidation;
result.meshValidation=memberB.checkMatlabPath(robot,result.theta,scene,plannerOptions);
result.success=result.success && result.meshValidation.worldCollisionFree;
result.callChain={'helperSTOMP','stompSamples','stompTrajCost', ...
    'updateJointsWorldPosition','stompRobotSphere','stompObstacleCost', ...
    'stompUpdateProb','stompDTheta','stompUpdateTheta'};
save(fullfile(runFolder,'planning_result.mat'),'result','poeModel','geometry', ...
    'scene','plannerOptions','voxelStored','R','M','-v7');
memberB.writeCSV(fullfile(runFolder,'trajectory.csv'), ...
    'q1_rad,q2_rad,q3_rad,q4_rad,q5_rad,q6_rad',result.theta.');
memberB.writeCSV(fullfile(runFolder,'cost_history.csv'), ...
    'restart,iteration,total_cost,conservative_voxel_gap_m,smoothness,accepted_code,alpha',result.history);
memberB.writeCSV(fullfile(runFolder,'dense_validation.csv'), ...
    'state,exact_sphere_gap_m,conservative_voxel_gap_m,mesh_world_collision,mesh_self_collision,mesh_world_separation_m', ...
    [(1:result.validation.nStates).',result.validation.clearance.', ...
     result.voxelValidation.clearance.',result.meshValidation.worldInCollision.', ...
     result.meshValidation.selfInCollision.',result.meshValidation.worldSeparation.']);
fprintf('Initial mesh collisions: %d / %d; final dense states: %d\n', ...
    nnz(initialMesh.worldInCollision),initialMesh.nStates,result.validation.nStates);
fprintf('Final exact sphere gap %.6f m, conservative voxel gap %.6f m\n', ...
    result.validation.minClearance,result.voxelValidation.minClearance);
fprintf('World collision free %d; self collision free %d\n', ...
    result.meshValidation.worldCollisionFree,result.meshValidation.selfCollisionFree);
assert(result.success,'Validation failed; diagnostics were preserved.');
if plannerOptions.showFigures
    memberB.plotComparison(robot,scene,result,runFolder);
    memberB.plotResults(robot,poeModel,geometry,scene,result,plannerOptions,runFolder);
end
end
