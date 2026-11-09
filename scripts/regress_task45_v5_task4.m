function receipt=regress_task45_v5_task4()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v5'); folder=fullfile(release,'regression','workcell','adaptive','Task4','seed_5300');
if ~exist(fullfile(folder,'planning_result.mat'),'file')
    base=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat')); c=memberC.variantOptions(base.frozen.options,'adaptive');
    c.retainRollouts=true; memberC.runOne(4,'workcell',5300,c,folder);
end
d=load(fullfile(folder,'planning_result.mat')); prior=load(fullfile(root,'artifacts','runs','task45_v3','demos','workcell','Task4','seed_5300','planning_result.mat'));
assert(d.result.success && isequal(d.result.searchTheta,prior.result.theta) && isequal(d.result.history,prior.result.history));
audit=audit_task45_v5(fileparts(folder),fullfile(release,'task4_regression_audit.json')); assert(audit.passed && audit.fineSuccessfulRuns==1);
receipt=struct('passed',true,'v3PrimaryPathAndHistoryBitwiseUnchanged',true,'fineSuccess',true, ...
    'refinementImprovement',d.result.firstFeasibleQuality-d.result.finalQuality);
memberC.writeJSON(fullfile(release,'task4_regression.json'),receipt);
end
