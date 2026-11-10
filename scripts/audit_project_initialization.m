root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v2','matlab'),'-begin');
out=fullfile(root,'artifacts','audits','project_completion_20261109');
data=load(fullfile(root,'artifacts','runs','task45_v2','frozen_config.mat')); c=data.frozen.options; c.denseJointStep=.0125;
robot=loadrobot('universalUR5','DataFormat','column'); model=memberB.buildPoeModel(robot,'tool0'); rows=cell(1,2);
for i=1:2
    ids={'main','variant'}; scene=memberC.makeScene(model,c,ids{i});
    initial=scene.qStart+(scene.qGoal-scene.qStart)*linspace(0,1,c.nWaypoints);
    check=memberB.checkMatlabPath(robot,initial,scene,c);
    assert(~check.worldCollisionFree && check.selfCollisionFree);
    [~,start]=memberB.poeFK(model,scene.qStart); [~,goal]=memberB.poeFK(model,scene.qGoal);
    assert(memberC.directionError(start(1:3,2))<1e-6 && memberC.directionError(goal(1:3,2))<1e-6);
    rows{i}=struct('scene',ids{i},'denseStates',check.nStates,'worldCollisionStates',nnz(check.worldInCollision), ...
        'selfCollisionStates',nnz(check.selfInCollision),'endpointsUpright',true);
end
memberC.writeJSON(fullfile(out,'initialization_audit.json'),struct('passed',true,'details',{rows}));
fprintf('PROJECT INITIALIZATION AUDIT PASSED\n');
