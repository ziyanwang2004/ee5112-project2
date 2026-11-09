function results=run_task45(whichTask,scenarioId,seed,showFigures,runRoot)
% Task4/5 entry. Original run_all_tasks retains its Task1/2/3 contract.
if nargin<1, whichTask='all'; end
if nargin<2, scenarioId='main'; end
if nargin<3, seed=5112; end
if nargin<4, showFigures=true; end
root=fileparts(mfilename('fullpath')); addpath(root);
if nargin<5, runRoot=fullfile(root,'..','artifacts','local_runs','task45',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))); end
assert(any(strcmp(whichTask,{'all','task4','task5'})));
assert(any(strcmp(scenarioId,{'all','main','variant'})));
c=memberC.defaults();
frozen=fullfile(root,'..','artifacts','runs','task45_final','frozen_config.mat');
if exist(frozen,'file'), d=load(frozen); c=d.frozen.options; end
scenarios={scenarioId}; if strcmp(scenarioId,'all'), scenarios={'main','variant'}; end
tasks=[4 5]; if ~strcmp(whichTask,'all'), tasks=str2double(whichTask(end)); end
results=struct();
for j=1:numel(scenarios)
    for t=tasks
        folder=fullfile(runRoot,scenarios{j},sprintf('Task%d',t),sprintf('seed_%d',seed));
        r=memberC.runOne(t,scenarios{j},seed,c,folder);
        results.(scenarios{j}).(sprintf('task%d',t))=r;
    end
end
if showFigures, export_task45(runRoot,false); end
end
