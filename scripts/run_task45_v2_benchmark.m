function summary=run_task45_v2_benchmark(runRoot)
% Reproduce the frozen 50-case V2 study into a new directory, sequentially.
% The recorded study used two workers; compare timings only within a setup.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v2','matlab'),'-begin');
assert(nargin==1 && ~exist(runRoot,'dir'),'Provide a new, unused output directory.'); mkdir(runRoot);
d=load(fullfile(root,'artifacts','runs','task45_v2','frozen_config.mat')); frozen=d.frozen;
now=memberC.provenance(); assert(strcmp(now.sourceFingerprint,frozen.metadata.sourceFingerprint));
c=frozen.options; rows=cell(1,50); n=0;
for scene={'main','variant'}
    for seed=frozen.formalSeeds
        tasks=4:5; if mod(seed,4)>=2, tasks=[5 4]; end
        for task=tasks
            folder=fullfile(runRoot,scene{1},sprintf('Task%d',task),sprintf('seed_%d',seed));
            r=memberC.runOne(task,scene{1},seed,c,folder); cc=c; if task==4, cc.constraintMode='none'; end
            n=n+1; rows{n}=memberC.summarizeRun(r,cc);
        end
    end
end
c.constraintMode='penalty';
for seed=frozen.formalSeeds
    folder=fullfile(runRoot,'main','penalty_ablation',sprintf('seed_%d',seed));
    r=memberC.runOne(5,'main',seed,c,folder); n=n+1; rows{n}=memberC.summarizeRun(r,c);
end
rows=[rows{:}]; summary=memberC.aggregateStudy(rows,'projected');
memberC.writeRunTable(fullfile(runRoot,'all_runs.csv'),rows);
memberC.writeJSON(fullfile(runRoot,'study_summary.json'),summary);
end
