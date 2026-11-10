function results=run_task45_v5(whichTask,scenario,variant,seed,runRoot)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
if nargin<1, whichTask='task5'; end
if nargin<2, scenario='workcell'; end
if nargin<3, variant='adaptive'; end
if nargin<4, seed=5700; end
if nargin<5, runRoot=fullfile(root,'artifacts','local_runs','task45_v5',char(java.util.UUID.randomUUID())); end
assert(any(strcmp(whichTask,{'all','task4','task5'})));
frozenPath=fullfile(root,'artifacts','runs','task45_v5','frozen_config.mat');
if exist(frozenPath,'file')
    d=load(frozenPath); identity=memberC.provenance(); assert(strcmp(identity.sourceFingerprint,d.frozen.metadata.sourceFingerprint));
    c=d.frozen.options.(scenario).(variant);
else
    d=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat'));
    c=memberC.caseOptions(memberC.variantOptions(d.frozen.options,variant),scenario);
end
c.retainRollouts=true; tasks=4:5; if ~strcmp(whichTask,'all'), tasks=str2double(whichTask(end)); end
results=struct();
for task=tasks
    folder=fullfile(runRoot,scenario,variant,sprintf('Task%d',task),sprintf('seed_%d',seed));
    results.(sprintf('task%d',task))=memberC.runOne(task,scenario,seed,c,folder);
end
end
