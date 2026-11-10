root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v3','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v3'); robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0'); g=memberB.loadUR5Spheres(model);
files=dir(fullfile(release,'development','profile_1','**','planning_result.mat')); rows=cell(1,numel(files));
for k=1:numel(files)
    d=load(fullfile(files(k).folder,files(k).name)); scene=memberC.makeScene(model,d.plannerOptions,'workcell'); w=makeVoxelWorld(scene.boxes,d.plannerOptions);
    context=struct('options',d.plannerOptions,'geometry',g,'kinematics',struct('mode','poe','robot',robot,'model',model));
    [ok,v]=memberC.validatePath(d.result.theta,context,scene,w,.00625,true);
    rows{k}=struct('task',d.result.task,'seed',d.result.seed,'originalSuccess',d.result.success,'fineSuccess',ok, ...
        'minVoxelGap',v.minVoxelClearance,'tilt',v.maxOrientationDeg,'minToolHeight',v.minToolHeight,'failures',{v.failures});
    fprintf('V3 FINE DEV task %d seed %d original %d fine %d gap %.7f\n',d.result.task,d.result.seed,d.result.success,ok,v.minVoxelClearance);
end
memberC.writeJSON(fullfile(release,'development_fine_probe.json'),rows);
