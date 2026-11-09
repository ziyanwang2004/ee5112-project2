function results=run_task45_v4(whichTask,variant,seed,runRoot)
% New outputs only. V1/V2/V3 source and evidence stay untouched.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v4','matlab'),'-begin');
if nargin<1, whichTask='all'; end
if nargin<2, variant='combined'; end
if nargin<3, seed=5500; end
if nargin<4, runRoot=fullfile(root,'artifacts','local_runs','task45_v4',char(java.util.UUID.randomUUID())); end
assert(any(strcmp(whichTask,{'all','task4','task5'})));
frozenPath=fullfile(root,'artifacts','runs','task45_v4','frozen_config.mat');
if exist(frozenPath,'file')
    d=load(frozenPath); identity=memberC.provenance();
    assert(strcmp(identity.sourceFingerprint,d.frozen.metadata.sourceFingerprint));
    assert(isfield(d.frozen.options,variant),'Unknown variant.'); c=d.frozen.options.(variant);
else
    d=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat'));
    c=memberC.variantOptions(d.frozen.options,variant);
end
c.retainRollouts=true;
tasks=4:5; if ~strcmp(whichTask,'all'), tasks=str2double(whichTask(end)); end
results=struct();
for task=tasks
    folder=fullfile(runRoot,variant,'workcell',sprintf('Task%d',task),sprintf('seed_%d',seed));
    results.(sprintf('task%d',task))=memberC.runOne(task,'workcell',seed,c,folder);
end
end
