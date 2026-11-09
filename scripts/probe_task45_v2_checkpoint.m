root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'artifacts','runs','task45_v2','development','capsule_60000','source_snapshot'),'-begin');
folder=fullfile(root,'artifacts','runs','task45_v2','development','capsule_60000','main','Task5','seed_5150');
d=load(fullfile(folder,'input_checkpoint.mat')); f=dir(fullfile(folder,'iterations','restart_01*.mat')); z=load(fullfile(f(end).folder,f(end).name));
r=loadrobot('universalUR5','DataFormat','column'); ctx=struct('options',d.plannerOptions,'geometry',d.geometry, ...
    'kinematics',struct('mode','poe','robot',r,'model',d.poeModel),'selfGeometry',d.selfGeometry);
w=makeVoxelWorld(d.scene.boxes,d.plannerOptions); [ok,a]=memberC.validatePath(z.thetaAfter,ctx,d.scene,w,.025);
fprintf('CHECKPOINT %s success %d failures %s selfstates %d gap %.6f tilt %.6f\n',f(end).name,ok,strjoin(a.failures,','),sum(a.mesh.selfInCollision),a.minVoxelClearance,a.maxOrientationDeg);
idx=find(a.mesh.selfInCollision);
for k=unique(idx(round(linspace(1,numel(idx),min(3,numel(idx))))))
    [~,sep]=checkCollision(r,a.theta(:,k),'IgnoreSelfCollision','off','SkippedSelfCollisions','parent','Exhaustive','on');
    [ii,jj]=find(triu(isnan(sep),1)); for j=1:numel(ii), fprintf(' %s / %s\n',r.Bodies{ii(j)}.Name,r.Bodies{jj(j)}.Name); end
end
[~,cost,info]=stompTrajCost(copy(r),z.thetaAfter,z.R,w,ctx); disp(cost); disp(info);
