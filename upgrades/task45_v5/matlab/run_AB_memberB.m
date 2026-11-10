function results=run_AB_memberB(whichTask,showFigures)
% Run the integrated Tasks 2/3 and retain every iteration in a new run folder.
if nargin<1, whichTask='all'; end
if nargin<2, showFigures=true; end
root=fileparts(mfilename('fullpath')); addpath(root);
c=sharedDefaults(); c.showFigures=showFigures;
stamp=char(datetime('now','TimeZone','Asia/Shanghai','Format','yyyyMMdd_HHmmss_SSS'));
runRoot=fullfile(root,'..','artifacts','local_runs',stamp);
results=struct();
if any(strcmpi(whichTask,{'all','task2'}))
    results.task2=UR5_STOMP_Path_Planning('builtin',c,fullfile(runRoot,'Task2'));
end
if any(strcmpi(whichTask,{'all','task3'}))
    results.task3=UR5_STOMP_Path_Planning('poe',c,fullfile(runRoot,'Task3'));
end
assert(~isempty(fieldnames(results)),'Choose all, task2 or task3.');
save(fullfile(runRoot,'combined_results.mat'),'results','-v7');
fid=fopen(fullfile(root,'..','artifacts','latest_run.txt'),'w');
fprintf(fid,'%s\n',runRoot); fclose(fid);
fprintf('All process files saved in %s\n',runRoot);
end
