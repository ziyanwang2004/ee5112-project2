root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'scripts'));
release=fullfile(root,'artifacts','runs','task45_v4'); output=fullfile(release,'regression');
for task=4:5
    folder=fullfile(output,'baseline','workcell',sprintf('Task%d',task),'seed_5300');
    if exist(fullfile(folder,'planning_result.mat'),'file'), d=load(fullfile(folder,'planning_result.mat')); r=d.result;
    else, results=run_task45_v4(sprintf('task%d',task),'baseline',5300,output); r=results.(sprintf('task%d',task)); end
    old=load(fullfile(root,'artifacts','runs','task45_v3','demos','workcell',sprintf('Task%d',task),'seed_5300','planning_result.mat'));
    assert(isequal(r.theta,old.result.theta) && isequal(r.history,old.result.history),'V3 baseline trajectory or history changed.');
end
folder=fullfile(output,'anytime','workcell','Task4','seed_5300');
if ~exist(fullfile(folder,'planning_result.mat'),'file'), run_task45_v4('task4','anytime',5300,output); end
audit=verify_task45_v4(output); audit.v3BaselineBitwiseUnchanged=true;
memberC.writeJSON(fullfile(release,'regression_audit.json'),audit);
fprintf('V4 BASELINE COMPATIBILITY AND TASK4 REFINEMENT PASSED\n');
