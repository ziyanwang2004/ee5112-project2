root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v3','matlab'),'-begin');
out=fullfile(root,'artifacts','local_runs','task45_v3_scene_probe'); if ~exist(out,'dir'), mkdir(out); end
robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0'); c=memberC.defaults(); c.constraintMode='projected';
geometry=memberB.loadUR5Spheres(model); scene=memberC.makeScene(model,c,'workcell'); w=makeVoxelWorld(scene.boxes,c);
context=struct('options',c,'geometry',geometry,'kinematics',struct('mode','poe','robot',robot,'model',model));
labels={'start','goal'}; Q=[c.qStart,c.qGoal]; endpoints=cell(1,2);
for k=1:2
    sc=scene; sc.qStart=Q(:,k); sc.qGoal=Q(:,k);
    [ok,v]=memberC.validatePath([Q(:,k),Q(:,k)],context,sc,w,.0125,true);
    endpoints{k}=struct('name',labels{k},'passed',ok,'failures',{v.failures},'gap',v.minVoxelClearance,'tilt',v.maxOrientationDeg,'toolZ',v.minToolHeight);
    fprintf('ENDPOINT %s passed %d failures %s gap %.6f tilt %.6f tool Z %.6f\n',labels{k},ok,strjoin(v.failures,','),v.minVoxelClearance,v.maxOrientationDeg,v.minToolHeight);
end
initial=c.qStart+(c.qGoal-c.qStart)*linspace(0,1,c.nWaypoints);
cc=c; cc.denseJointStep=.0125; mesh=memberB.checkMatlabPath(robot,initial,scene,cc);
fprintf('INITIAL world collisions %d/%d self %d\n',nnz(mesh.worldInCollision),mesh.nStates,nnz(mesh.selfInCollision));
% Geometric existence witness only, never loaded by the planning drivers.
liftStart=[c.qStart(1);-1.5;.8;.7;-pi/2;0]; liftGoal=liftStart; liftGoal(1)=c.qGoal(1);
witness=[c.qStart,liftStart,liftGoal,c.qGoal];
[ok,v]=memberC.validatePath(witness,context,scene,w,.0125,true);
fprintf('WITNESS passed %d failures %s gap %.6f tilt %.6f tool Z %.6f\n',ok,strjoin(v.failures,','),v.minVoxelClearance,v.maxOrientationDeg,v.minToolHeight);
receipt=struct('endpoints',{endpoints},'initialWorldCollisionStates',nnz(mesh.worldInCollision),'initialSelfCollisionStates',nnz(mesh.selfInCollision), ...
    'initialDenseStates',mesh.nStates,'witnessPassed',ok,'witnessGap',v.minVoxelClearance,'witnessFailures',{v.failures}, ...
    'witnessUse','Scene feasibility proof only; prohibited as an optimizer initialization, restart, or output.');
memberC.writeJSON(fullfile(out,'geometry_probe.json'),receipt);
save(fullfile(out,'geometry_probe.mat'),'scene','witness','receipt','-v7');
endpointsPassed=all(cellfun(@(s)s.passed,endpoints)); assert(endpointsPassed && ok && nnz(mesh.worldInCollision)>0 && ~any(mesh.selfInCollision));
fprintf('V3 SCENE FEASIBILITY PASSED\n');
