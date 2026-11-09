function results=run_task45_v2(whichTask,scenarioId,seed,showFigures,runRoot)
% Explicit V2 public entry, isolated from the original run_task45.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v2','matlab'),'-begin');
assert(contains(which('memberC.plan'),fullfile('upgrades','task45_v2','matlab')));
if nargin<1, whichTask='all'; end
if nargin<2, scenarioId='main'; end
if nargin<3, seed=5150; end
if nargin<4, showFigures=true; end
if nargin<5, runRoot=fullfile(root,'artifacts','local_runs','task45_v2',char(java.util.UUID.randomUUID())); end
assert(any(strcmp(whichTask,{'task4','task5','all'})) && any(strcmp(scenarioId,{'main','variant','all'})));
release=fullfile(root,'artifacts','runs','task45_v2'); c=memberC.defaults(); c.constraintMode='projected'; c.orientationWeight=1000;
if exist(fullfile(release,'frozen_config.mat'),'file')
    data=load(fullfile(release,'frozen_config.mat')); now=memberC.provenance();
    assert(strcmp(now.sourceFingerprint,data.frozen.metadata.sourceFingerprint)); c=data.frozen.options;
end
c.retainRollouts=true; results=struct(); tasks=4:5; if ~strcmp(whichTask,'all'), tasks=str2double(whichTask(end)); end
scenes={scenarioId}; if strcmp(scenarioId,'all'), scenes={'main','variant'}; end
for scene=scenes
    for task=tasks
        folder=fullfile(runRoot,scene{1},sprintf('Task%d',task),sprintf('seed_%d',seed));
        results.(scene{1}).(sprintf('task%d',task))=memberC.runOne(task,scene{1},seed,c,folder);
    end
end
if showFigures, export_task45(runRoot,false); end
end
