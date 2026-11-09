function result=KINOVA_STOMP_Path_Planning(showFigures,runFolder)
% TASK 1: original KINOVA Gen3, exact supplied target poses and obstacle.
% Default run completes STOMP, independent dense mesh checks and animation.
if nargin<1, showFigures=true; end
assert(strcmp(version('-release'),'2023b'),'Use MATLAB R2023b.');
root=fileparts(mfilename('fullpath')); addpath(root);
plannerOptions=sharedDefaults();
plannerOptions.robotName='kinovaGen3'; plannerOptions.endEffector='EndEffector_Link';
plannerOptions.showFigures=showFigures; plannerOptions.margin=.01;
plannerOptions.acceptanceMode='mesh';
if nargin<2
    stamp=char(datetime('now','TimeZone','Asia/Shanghai','Format','yyyyMMdd_HHmmss_SSS'));
    runFolder=fullfile(root,'..','artifacts','local_runs',stamp,'Task1');
end
assert(~exist(fullfile(runFolder,'planning_result.mat'),'file'),'Use a new run folder.');
if ~exist(runFolder,'dir'), mkdir(runFolder); end
diary(fullfile(runFolder,'run_log.txt')); guard=onCleanup(@()diary('off')); %#ok<NASGU>
[robot,robotData]=loadrobot('kinovaGen3','DataFormat','column');
taskInit=trvec2tform([.4 0 .2])*axang2tform([0 1 0 pi]);
taskFinal=trvec2tform([.35 .55 .35])*axang2tform([0 1 0 pi]);
ik=inverseKinematics('RigidBodyTree',robot);
ik.SolverParameters.AllowRandomRestart=false;
[q0,ikStart]=ik('EndEffector_Link',taskInit,ones(1,6),homeConfiguration(robot));
q0=wrapToPi(q0);
[qT,ikGoal]=ik('EndEffector_Link',taskFinal,ones(1,6),q0);
qT=wrapToPi(qT);
assert(strcmp(ikStart.Status,'success') && strcmp(ikGoal.Status,'success'),'Original IK failed.');
plannerOptions.qStart=q0; plannerOptions.qGoal=qT;
poeModel=memberB.buildPoeModel(robot,'EndEffector_Link');
% Continuous joints use a finite exploration interval, without wrapping a
% trajectory through a discontinuity. The physical limit remains unbounded.
physicalJointLimits=poeModel.limits;
poeModel.limits(:,1)=max(poeModel.limits(:,1),-2*pi);
poeModel.limits(:,2)=min(poeModel.limits(:,2),2*pi);
geometry=loadKinovaSpheres(poeModel);
robot_struct=copy(robot); robot_struct.DataFormat='struct';
context.options=plannerOptions; context.geometry=geometry;
context.kinematics=struct('mode','builtin','robot',robot,'model',poeModel);
fk=@(q)memberB.builtinFK(robot,poeModel,q);
helperCreateObstaclesKINOVA;
for q={q0,qT}
    e=memberB.checkMatlabPath(robot,[q{1},q{1}],scene,plannerOptions);
    assert(e.worldCollisionFree,'An original fixed endpoint is in collision.');
end
initial=q0+(qT-q0)*linspace(0,1,plannerOptions.nWaypoints);
initialMesh=memberB.checkMatlabPath(robot,initial,scene,plannerOptions);
memberB.exportScrews(poeModel,runFolder);
voxelStored=rmfield(voxel_world,'interpolant');
save(fullfile(runFolder,'input_checkpoint.mat'),'plannerOptions','scene','geometry', ...
    'poeModel','robotData','physicalJointLimits','taskInit','taskFinal','ikStart','ikGoal','voxelStored','-v7');
helperSTOMP;
result=plannerResult; result.backend='builtin'; result.task=1;
result.matlabVersion=version; result.runFolder=runFolder;
result.initialMeshValidation=initialMesh;
result.meshValidation=memberB.checkMatlabPath(robot,result.theta,scene,plannerOptions);
result.success=result.success && result.meshValidation.worldCollisionFree;
result.ikStart=ikStart; result.ikGoal=ikGoal;
result.callChain={'helperSTOMP','stompSamples','stompTrajCost', ...
    'updateJointsWorldPosition','stompRobotSphere','stompObstacleCost', ...
    'stompUpdateProb','stompDTheta','stompUpdateTheta'};
save(fullfile(runFolder,'planning_result.mat'),'result','poeModel','geometry','scene', ...
    'plannerOptions','voxelStored','R','M','taskInit','taskFinal','physicalJointLimits','-v7');
memberB.writeCSV(fullfile(runFolder,'trajectory.csv'), ...
    'q1_rad,q2_rad,q3_rad,q4_rad,q5_rad,q6_rad,q7_rad',result.theta.');
memberB.writeCSV(fullfile(runFolder,'cost_history.csv'), ...
    'restart,iteration,total_cost,conservative_voxel_gap_m,smoothness,accepted_code,alpha',result.history);
memberB.writeCSV(fullfile(runFolder,'dense_validation.csv'), ...
    'state,exact_sphere_gap_m,conservative_voxel_gap_m,mesh_world_collision,mesh_self_collision,mesh_world_separation_m', ...
    [(1:result.validation.nStates).',result.validation.clearance.',result.voxelValidation.clearance.', ...
    result.meshValidation.worldInCollision.',result.meshValidation.selfInCollision.',result.meshValidation.worldSeparation.']);
fprintf('Task 1 initial collisions %d / %d; final states %d\n', ...
    nnz(initialMesh.worldInCollision),initialMesh.nStates,result.meshValidation.nStates);
fprintf('Task 1 world free %d; self free %d; minimum mesh separation %.9f m\n', ...
    result.meshValidation.worldCollisionFree,result.meshValidation.selfCollisionFree,result.meshValidation.minWorldSeparation);
fprintf('Task 1 proxy margin satisfied %d (original fixed goal is closer than 1 cm).\n',result.proxyMarginSatisfied);
assert(result.success,'Task 1 failed mesh validation; diagnostics preserved.');
if showFigures
    memberB.plotComparison(robot,scene,result,runFolder);
    memberB.plotResults(robot,poeModel,geometry,scene,result,plannerOptions,runFolder);
end
end
