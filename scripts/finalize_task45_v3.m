root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v3','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v3'); data=load(fullfile(release,'frozen_config.mat')); frozen=data.frozen;
identity=memberC.provenance(); assert(strcmp(identity.sourceFingerprint,frozen.metadata.sourceFingerprint));
files=dir(fullfile(release,'formal','**','planning_result.mat')); assert(numel(files)==40);
rows=cell(1,40); fine={}; robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0'); geometry=memberB.loadUR5Spheres(model);
fineFolder=fullfile(release,'verification','fine_profiles'); if ~exist(fineFolder,'dir'), mkdir(fineFolder); end
for k=1:numel(files)
    d=load(fullfile(files(k).folder,files(k).name)); assert(strcmp(d.result.metadata.sourceFingerprint,identity.sourceFingerprint));
    rows{k}=memberC.summarizeRun(d.result,d.plannerOptions); rows{k}.folder=files(k).folder;
    if d.result.success
        scene=memberC.makeScene(model,d.plannerOptions,'workcell'); w=makeVoxelWorld(scene.boxes,d.plannerOptions);
        context=struct('options',d.plannerOptions,'geometry',geometry,'kinematics',struct('mode','poe','robot',robot,'model',model));
        [ok,a]=memberC.validatePath(d.result.theta,context,scene,w,.00625,true); assert(ok,'Fine verification rejected a successful path.');
        fine{end+1}=struct('task',d.result.task,'seed',d.result.seed,'minToolHeight',a.minToolHeight, ...
            'minVoxelClearance',a.minVoxelClearance,'maxOrientationDeg',a.maxOrientationDeg,'denseStates',a.nStates); %#ok<SAGROW>
        memberB.writeCSV(fullfile(fineFolder,sprintf('task%d_seed_%d.csv',d.result.task,d.result.seed)), ...
            'path_parameter,tool_x_m,tool_y_m,tool_z_m,tilt_deg,proxy_gap_m,world_collision,self_collision', ...
            [a.s.',a.toolPosition.',a.orientationDeg.',a.voxelClearance.',a.mesh.worldInCollision.',a.mesh.selfInCollision.']);
    end
end
rows=[rows{:}]; summary=memberC.aggregateStudy(rows,'projected');
memberC.writeRunTable(fullfile(release,'formal','all_runs.csv'),rows);
memberC.writeJSON(fullfile(release,'formal','study_summary.json'),summary);
save(fullfile(release,'formal','study_results.mat'),'rows','summary','frozen','-v7');
memberC.writeJSON(fullfile(release,'fine_validation.json'),struct('passed',true,'jointStep',.00625,'checkedSuccessfulPaths',numel(fine),'details',{fine}));
audit=verify_task45(fullfile(release,'formal')); memberC.writeJSON(fullfile(release,'formal_audit.json'),audit);
audit=verify_task45(fullfile(release,'demos')); memberC.writeJSON(fullfile(release,'demo_audit.json'),audit);
addpath(fullfile(root,'scripts')); export_task45_v3(release,true);
fprintf('V3 STUDY AND EXPORT COMPLETE: %d/%d formal successes\n',summary.successfulRuns,summary.totalRuns);
