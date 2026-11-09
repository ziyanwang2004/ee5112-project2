function summary=run_task45_benchmark(runRoot)
root=fileparts(mfilename('fullpath')); addpath(root);
finalRoot=fullfile(root,'..','artifacts','runs','task45_final');
d=load(fullfile(finalRoot,'frozen_config.mat')); frozen=d.frozen;
now=memberC.provenance(); assert(strcmp(now.sourceFingerprint,frozen.metadata.sourceFingerprint),'MATLAB sources changed after freezing.');
if nargin<1, runRoot=fullfile(finalRoot,'formal'); end
if ~exist(runRoot,'dir'), mkdir(runRoot); end
c=frozen.options; c.retainRollouts=false; scenes={'main','variant'}; rows=struct([]);
for s=1:2
    for seed=frozen.formalSeeds
        for task=4:5
            folder=fullfile(runRoot,scenes{s},sprintf('Task%d',task),sprintf('seed_%d',seed));
            evaluate(task,scenes{s},seed,c,folder);
        end
    end
end
if strcmp(c.constraintMode,'projected')
    ablation=c; ablation.constraintMode='penalty'; ablation.orientationWeight=1000;
    for seed=frozen.formalSeeds
        folder=fullfile(runRoot,'main','penalty_ablation',sprintf('seed_%d',seed));
        evaluate(5,'main',seed,ablation,folder);
    end
end
summary=memberC.aggregateStudy(rows,frozen.options.constraintMode);
memberC.writeJSON(fullfile(runRoot,'study_summary.json'),summary);
save(fullfile(runRoot,'study_results.mat'),'rows','summary','frozen','-v7');
fprintf('FORMAL STUDY COMPLETE: %d runs, %d successful\n',summary.totalRuns,summary.successfulRuns);
    function evaluate(task,id,seed,options,folder)
        resultPath=fullfile(folder,'planning_result.mat');
        if exist(resultPath,'file')
            old=load(resultPath); r=old.result;
            assert(strcmp(r.metadata.sourceFingerprint,frozen.metadata.sourceFingerprint));
            assert(r.task==task && r.seed==seed && strcmp(r.scenarioId,id));
            assert(strcmp(old.plannerOptions.constraintMode,options.constraintMode) || task==4);
        else
            r=memberC.runOne(task,id,seed,options,folder);
        end
        if task==4, options.constraintMode='none'; end
        entry=memberC.summarizeRun(r,options); entry.folder=folder;
        if isempty(rows), rows=entry; else, rows(end+1)=entry; end
        memberC.writeRunTable(fullfile(runRoot,'all_runs.csv'),rows);
        memberC.writeJSON(fullfile(runRoot,'progress.json'),struct('completed',numel(rows),'lastScenario',id,'lastTask',task,'lastSeed',seed));
    end
end
