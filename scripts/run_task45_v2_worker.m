function run_task45_v2_worker(worker)
assert(ismember(worker,[0 1]));
root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'upgrades','task45_v2','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v2'); data=load(fullfile(release,'frozen_config.mat')); frozen=data.frozen;
now=memberC.provenance(); assert(strcmp(now.sourceFingerprint,frozen.metadata.sourceFingerprint));
c=frozen.options; formal=fullfile(release,'formal'); seeds=frozen.formalSeeds(mod(frozen.formalSeeds,2)==worker);
completed=0;
for scene={'main','variant'}
    for seed=seeds
        tasks=4:5; if mod(seed,4)>=2, tasks=[5 4]; end
        for task=tasks
            folder=fullfile(formal,scene{1},sprintf('Task%d',task),sprintf('seed_%d',seed));
            evaluate(task,scene{1},seed,c,folder);
        end
    end
end
ablation=c; ablation.constraintMode='penalty'; ablation.orientationWeight=1000;
for seed=seeds
    folder=fullfile(formal,'main','penalty_ablation',sprintf('seed_%d',seed));
    evaluate(5,'main',seed,ablation,folder);
end
fprintf('V2 WORKER %d COMPLETE: %d cases\n',worker,completed);
    function evaluate(task,scene,seed,options,folder)
        file=fullfile(folder,'planning_result.mat');
        if exist(file,'file')
            old=load(file); r=old.result; assert(strcmp(r.metadata.sourceFingerprint,now.sourceFingerprint));
            assert(r.task==task && r.seed==seed && strcmp(r.scenarioId,scene));
            assert(strcmp(old.plannerOptions.constraintMode,options.constraintMode) || task==4);
        else
            r=memberC.runOne(task,scene,seed,options,folder);
        end
        completed=completed+1;
        memberC.writeJSON(fullfile(release,sprintf('worker_%d_progress.json',worker)), ...
            struct('completed',completed,'lastScene',scene,'lastTask',task,'lastSeed',seed,'lastSuccess',r.success));
    end
end
