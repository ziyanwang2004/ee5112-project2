root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v2','matlab'),'-begin');
out=fullfile(root,'artifacts','audits','project_completion_20261109'); if ~exist(out,'dir'), mkdir(out); end
release=fullfile(root,'artifacts','runs','task45_v2'); frozen=load(fullfile(release,'frozen_config.mat'));
identity=memberC.provenance(); assert(strcmp(identity.sourceFingerprint,frozen.frozen.metadata.sourceFingerprint));
robot=loadrobot('universalUR5','DataFormat','column'); model=memberB.buildPoeModel(robot,'tool0'); geometry=memberB.loadUR5Spheres(model);
details={}; successes=0; count=0;
for part={'formal','demos'}
    files=dir(fullfile(release,part{1},'**','planning_result.mat'));
    if strcmp(part{1},'formal'), assert(numel(files)==50); else, assert(numel(files)==4); end
    for k=1:numel(files)
        d=load(fullfile(files(k).folder,files(k).name)); c=d.plannerOptions;
        scene=memberC.makeScene(model,c,d.scene.id); assert(isequal(scene.boxes,d.scene.boxes));
        assert(strcmp(d.result.metadata.sourceFingerprint,identity.sourceFingerprint));
        context=struct('options',c,'geometry',geometry,'kinematics',struct('mode','poe','robot',robot,'model',model));
        w=makeVoxelWorld(scene.boxes,c);
        initial=scene.qStart+(scene.qGoal-scene.qStart)*linspace(0,1,c.nWaypoints);
        assert(isequal(initial,d.result.initial));
        [ok,v]=memberC.validatePath(d.result.theta,context,scene,w,c.finalDenseJointStep,true);
        assert(ok==d.result.success && isequal(v.failures,d.result.acceptance.failures));
        assert(abs(v.minVoxelClearance-d.result.acceptance.minVoxelClearance)<1e-10);
        assert(abs(v.maxOrientationDeg-d.result.acceptance.maxOrientationDeg)<1e-9);
        count=count+1; successes=successes+ok;
        details{count}=struct('part',part{1},'task',d.result.task,'scene',scene.id,'seed',d.result.seed, ...
            'mode',c.constraintMode,'success',ok,'failures',{v.failures},'worldFree',v.mesh.worldCollisionFree, ...
            'selfFree',v.mesh.selfCollisionFree,'gap',v.minVoxelClearance,'maxTilt',v.maxOrientationDeg);
        fprintf('PROJECT V2 AUDIT %d/54 %s %s seed %d mode %s success %d\n',count,part{1},scene.id,d.result.seed,c.constraintMode,ok);
    end
end
assert(count==54 && successes==44);
old=jsondecode(fileread(fullfile(release,'formal','independent_audit.json')));
assert(old.passed && old.replayedCheckpoints==1991);
audit=struct('passed',true,'sourceFingerprint',identity.sourceFingerprint,'revalidatedRuns',count, ...
    'successfulRuns',successes,'formalRngReplayCheckpointsPreviouslyAudited',1991,'details',{details});
memberC.writeJSON(fullfile(out,'task45_audit.json'),audit);
fprintf('PROJECT TASK45 DENSE AUDIT PASSED\n');
