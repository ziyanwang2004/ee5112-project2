root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'upgrades','task45_v2','matlab'),'-begin'); addpath(fullfile(root,'scripts')); clear functions;
release=fullfile(root,'artifacts','runs','task45_v2'); formal=fullfile(release,'formal');
files=dir(fullfile(formal,'**','planning_result.mat')); assert(numel(files)==50,'Formal study incomplete.');
now=memberC.provenance(); data=load(fullfile(release,'frozen_config.mat')); frozen=data.frozen;
assert(strcmp(now.sourceFingerprint,frozen.metadata.sourceFingerprint)); rows=cell(1,50);
for k=1:50
    d=load(fullfile(files(k).folder,files(k).name));
    assert(strcmp(d.result.metadata.sourceFingerprint,now.sourceFingerprint));
    rows{k}=memberC.summarizeRun(d.result,d.plannerOptions); rows{k}.folder=files(k).folder;
end
rows=[rows{:}]; summary=memberC.aggregateStudy(rows,'projected');
memberC.writeRunTable(fullfile(formal,'all_runs.csv'),rows);
memberC.writeJSON(fullfile(formal,'study_summary.json'),summary);
save(fullfile(formal,'study_results.mat'),'summary','rows','frozen','-v7');
audit_task45_v2(formal); audit_task45_v2(fullfile(release,'demos'));
plot_task45_v2_evidence(release,rows);
export_task45(fullfile(release,'demos'),true);
fprintf('V2 STUDY AND EXPORT COMPLETE: %d/%d successes\n',summary.successfulRuns,summary.totalRuns);
