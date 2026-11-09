function audit=verify_task45_v5_paths(runRoot)
% Read-only path validation for the compact Git handoff; raw replay is separate.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
identity=memberC.provenance(); frozen=load(fullfile(root,'artifacts','runs','task45_v5','frozen_config.mat'));
assert(strcmp(identity.sourceFingerprint,frozen.frozen.metadata.sourceFingerprint));
files=dir(fullfile(runRoot,'**','planning_result.mat')); assert(~isempty(files),'No saved paths.');
audit=struct('passed',true,'paths',numel(files),'nominalSuccesses',0,'fineSuccesses',0, ...
    'sourceFingerprint',identity.sourceFingerprint,'fineJointStep',.00625,'details',[]);
robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0'); geometry=memberB.loadUR5Spheres(model); rows=cell(1,numel(files));
for k=1:numel(files)
    folder=files(k).folder; d=load(fullfile(folder,'planning_result.mat')); c=d.plannerOptions;
    assert(strcmp(d.result.metadata.sourceFingerprint,identity.sourceFingerprint));
    assert(isequal(model.S,d.poeModel.S) && isequal(model.M,d.poeModel.M) && isequal(geometry,d.geometry));
    scene=memberC.makeScene(model,c,d.scene.id); assert(isequal(scene,d.scene));
    expected=frozen.frozen.options.(scene.id).(c.variant);
    if d.result.task==4, expected.constraintMode='none'; end
    omit={'seed','constraintFcn','validationFcn','projectionFcn','retainRollouts'};
    assert(isequaln(rmfield(c,omit),rmfield(expected,omit)),'Path options differ from frozen settings.');
    csvTheta=readmatrix(fullfile(folder,'trajectory.csv'));
    assert(isequal(size(csvTheta),size(d.result.theta.')) && max(abs(csvTheta(:)-reshape(d.result.theta.',[],1)))<1e-12);
    context=struct('options',c,'geometry',geometry,'kinematics',struct('mode','poe','robot',robot,'model',model));
    w=makeVoxelWorld(scene.boxes,c);
    initial=scene.qStart+(scene.qGoal-scene.qStart)*linspace(0,1,c.nWaypoints); assert(isequal(initial,d.result.initial));
    initialMesh=memberB.checkMatlabPath(robot,initial,scene,c); assert(~initialMesh.worldCollisionFree);
    [nominal,v0]=memberC.validatePath(d.result.theta,context,scene,w,c.finalDenseJointStep,true);
    assert(nominal==d.result.success && abs(v0.minVoxelClearance-d.result.acceptance.minVoxelClearance)<1e-10);
    [fine,v]=memberC.validatePath(d.result.theta,context,scene,w,.00625,true);
    audit.nominalSuccesses=audit.nominalSuccesses+nominal; audit.fineSuccesses=audit.fineSuccesses+(nominal&&fine);
    rows{k}=struct('scenario',scene.id,'variant',c.variant,'seed',d.result.seed,'nominalSuccess',nominal, ...
        'studySuccess',nominal&&fine,'minGap',v.minVoxelClearance,'maxTilt',v.maxOrientationDeg,'failures',{v.failures});
    fprintf('V5 COMPACT PATH CHECK %s %s seed %d nominal=%d study=%d\n',scene.id,c.variant,d.result.seed,nominal,nominal&&fine);
end
audit.details=rows;
audit.scope='Fresh robot/geometry/scene, frozen settings, CSV identity, colliding initialization and nominal/finer actual collision and direction checks. No raw sampling/update replay is claimed.';
end
