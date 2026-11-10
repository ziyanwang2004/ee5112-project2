function results=run_all_tasks(whichTask,showFigures,runRoot)
% MATLAB R2023b entry point. Task1=KINOVA; Task2=UR5 RBT; Task3=UR5 PoE.
% Examples: run_all_tasks; run_all_tasks('task1',false).
if nargin<1, whichTask='all'; end
if nargin<2, showFigures=true; end
root=fileparts(mfilename('fullpath')); addpath(root);
assert(any(strcmpi(whichTask,{'all','task1','task2','task3'})),'Choose all or task1/2/3.');
assert(strcmp(version('-release'),'2023b'),'Use MATLAB R2023b.');
if nargin<3
    stamp=char(datetime('now','TimeZone','Asia/Shanghai','Format','yyyyMMdd_HHmmss_SSS'));
    runRoot=fullfile(root,'..','artifacts','local_runs',stamp);
end
results=struct(); c=sharedDefaults(); c.showFigures=showFigures;
if any(strcmpi(whichTask,{'all','task1'}))
    results.task1=KINOVA_STOMP_Path_Planning(showFigures,fullfile(runRoot,'Task1'));
end
if any(strcmpi(whichTask,{'all','task2'}))
    results.task2=UR5_STOMP_Path_Planning('builtin',c,fullfile(runRoot,'Task2'));
end
if any(strcmpi(whichTask,{'all','task3'}))
    results.task3=UR5_STOMP_Path_Planning('poe',c,fullfile(runRoot,'Task3'));
end
save(fullfile(runRoot,'combined_results.mat'),'results','-v7');
fid=fopen(fullfile(root,'..','artifacts','latest_run.txt'),'w');
assert(fid>=0,'Cannot write latest_run.txt.');
fprintf(fid,'%s\n',runRoot); fclose(fid);
fprintf('All process files saved in %s\n',runRoot);
end
