function run_task45_v3_worker(worker)
assert(ismember(worker,[0 1]));
root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v3','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v3'); data=load(fullfile(release,'frozen_config.mat')); f=data.frozen;
identity=memberC.provenance(); assert(strcmp(identity.sourceFingerprint,f.metadata.sourceFingerprint));
completed=0; seeds=f.formalSeeds(mod(f.formalSeeds,2)==worker);
for seed=seeds
    tasks=4:5; if mod(seed,4)>=2, tasks=[5 4]; end
    for task=tasks
        folder=fullfile(release,'formal','workcell',sprintf('Task%d',task),sprintf('seed_%d',seed));
        if exist(fullfile(folder,'planning_result.mat'),'file')
            d=load(fullfile(folder,'planning_result.mat')); r=d.result;
            assert(strcmp(r.metadata.sourceFingerprint,identity.sourceFingerprint));
            assert(r.task==task && r.seed==seed && strcmp(r.scenarioId,'workcell'));
        else, r=memberC.runOne(task,'workcell',seed,f.options,folder); end
        completed=completed+1;
        memberC.writeJSON(fullfile(release,sprintf('worker_%d_progress.json',worker)), ...
            struct('completed',completed,'lastTask',task,'lastSeed',seed,'lastSuccess',r.success));
    end
end
fprintf('V3 WORKER %d COMPLETE: %d runs\n',worker,completed);
end
