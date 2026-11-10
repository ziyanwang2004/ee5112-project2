function results=run_task45_v3(whichTask,seed,runRoot)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v3','matlab'),'-begin');
if nargin<1, whichTask='all'; end
if nargin<2, seed=5300; end
if nargin<3, runRoot=fullfile(root,'artifacts','local_runs','task45_v3',char(java.util.UUID.randomUUID())); end
assert(any(strcmp(whichTask,{'all','task4','task5'})));
d=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat')); identity=memberC.provenance();
assert(strcmp(identity.sourceFingerprint,d.frozen.metadata.sourceFingerprint));
tasks=4:5; if ~strcmp(whichTask,'all'), tasks=str2double(whichTask(end)); end
results=struct(); options=d.frozen.options; options.retainRollouts=true;
for task=tasks
    folder=fullfile(runRoot,'workcell',sprintf('Task%d',task),sprintf('seed_%d',seed));
    results.(sprintf('task%d',task))=memberC.runOne(task,'workcell',seed,options,folder);
end
end
