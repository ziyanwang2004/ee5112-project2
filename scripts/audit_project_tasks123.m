root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'matlab')); addpath(fullfile(root,'matlab','tests'));
out=fullfile(root,'artifacts','audits','project_completion_20261109'); if ~exist(out,'dir'), mkdir(out); end
fresh=fullfile(out,'fresh_task123'); assert(~exist(fresh,'dir'),'Do not overwrite an audit run.');
run_all_tasks('all',false,fresh);
audit=struct('freshVerification',verify_task123(fresh),'originalPaths',{{}},'windowsRegression',{{}},'media',{{}});
for task=1:3
    name=sprintf('Task%d',task); folder=fullfile(root,'artifacts','runs','final_r2023b',name);
    d=load(fullfile(folder,'planning_result.mat')); c=d.plannerOptions;
    robot=loadrobot(c.robotName,'DataFormat','column'); m=memberB.buildPoeModel(robot,c.endEffector);
    if task==1, geometry=loadKinovaSpheres(m); else, geometry=memberB.loadUR5Spheres(m); end
    w=makeVoxelWorld(d.scene.boxes,c); fk=@(q)memberB.poeFK(m,q);
    mesh=memberB.checkMatlabPath(robot,d.result.theta,d.scene,c);
    voxel=checkVoxelPath(d.result.theta,fk,geometry,w,c.denseJointStep);
    assert(mesh.worldCollisionFree && mesh.selfCollisionFree);
    assert(isequal(d.result.theta(:,1),d.scene.qStart) && isequal(d.result.theta(:,end),d.scene.qGoal));
    assert(all(d.result.theta>=m.limits(:,1)-1e-12 & d.result.theta<=m.limits(:,2)+1e-12,'all'));
    if task>1, assert(voxel.minClearance>=c.margin-1e-9); end
    assert(abs(mesh.minWorldSeparation-d.result.meshValidation.minWorldSeparation)<1e-8);
    audit.originalPaths{task}=struct('task',task,'worldFree',mesh.worldCollisionFree,'selfFree',mesh.selfCollisionFree, ...
        'minMeshGap',mesh.minWorldSeparation,'minVoxelGap',voxel.minClearance,'denseStates',mesh.nStates);
    r=load(fullfile(fresh,name,'planning_result.mat'));
    reference=load(fullfile(root,'artifacts','local_runs','task45_baseline_20261105','after_hook',name,'planning_result.mat'));
    delta=max(abs(r.result.theta(:)-reference.result.theta(:)));
    assert(delta<1e-9,'Unexpected Windows baseline regression.');
    audit.windowsRegression{task}=struct('task',task,'maxTrajectoryDifference',delta, ...
        'trajectoryBitwiseIdentical',isequal(r.result.theta,reference.result.theta), ...
        'historyBitwiseIdentical',isequal(r.result.history,reference.result.history));
    videos=dir(fullfile(folder,'*.avi')); assert(numel(videos)==1);
    reader=VideoReader(fullfile(videos(1).folder,videos(1).name)); count=0;
    while hasFrame(reader)
        rgb=readFrame(reader); count=count+1;
        if ismember(count,[1 21 41]), imwrite(rgb,fullfile(out,sprintf('%s_frame_%02d.png',name,count))); end
    end
    assert(count==41 && reader.FrameRate==12);
    figures=dir(fullfile(folder,'*.fig'));
    for j=1:numel(figures), f=openfig(fullfile(figures(j).folder,figures(j).name),'invisible'); close(f); end
    audit.media{task}=struct('task',task,'decodedFrames',count,'fps',reader.FrameRate,'editableFiguresOpened',numel(figures));
end
% Isolate the PoE objective profile from setup and independent RBT checks.
d=load(fullfile(fresh,'Task3','planning_result.mat'));
robot=loadrobot('universalUR5','DataFormat','column'); w=makeVoxelWorld(d.scene.boxes,d.plannerOptions);
context=struct('options',d.plannerOptions,'geometry',d.geometry, ...
    'kinematics',struct('mode','poe','robot',robot,'model',d.poeModel));
profile clear; profile on; stompTrajCost(robot,d.result.theta,d.R,w,context); profile off;
p=profile('info'); names={p.FunctionTable.FunctionName};
assert(~any(contains(names,'getTransform')) && any(contains(names,'poeFK')) && any(contains(names,'stompObstacleCost')));
audit.poeCostProfile=struct('getTransformAbsent',true,'poeFKPresent',true,'obstacleCostPresent',true);
audit.passed=true; memberC.writeJSON(fullfile(out,'task123_audit.json'),audit);
fprintf('PROJECT TASK123 AUDIT PASSED\n');
