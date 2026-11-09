root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v3','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v3'); d=load(fullfile(release,'frozen_config.mat')); f=d.frozen;
identity=memberC.provenance(); assert(strcmp(identity.sourceFingerprint,f.metadata.sourceFingerprint));
dev=fullfile(release,'development',sprintf('profile_%d',f.selectedProfile));
audit=verify_task45(dev); assert(audit.runs==6 && audit.successfulRuns>=4);
memberC.writeJSON(fullfile(release,'development_audit.json'),audit);
drivers={'scripts/develop_task45_v3.m','scripts/run_task45_v3_worker.m','scripts/prepare_task45_v3_formal.m','scripts/continue_task45_v3.ps1'};
records=cell(1,numel(drivers));
for j=1:numel(drivers)
    fid=fopen(fullfile(root,drivers{j}),'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    records{j}=struct('path',drivers{j},'sha256',memberC.sha256(bytes));
end
memberC.writeJSON(fullfile(release,'formal_driver_hashes.json'),records);
for task=4:5
    options=f.options; options.retainRollouts=true;
    folder=fullfile(release,'demos','workcell',sprintf('Task%d',task),sprintf('seed_%d',f.demoSeed));
    r=memberC.runOne(task,'workcell',f.demoSeed,options,folder);
    reference=load(fullfile(dev,'workcell',sprintf('Task%d',task),sprintf('seed_%d',f.demoSeed),'planning_result.mat'));
    assert(r.success && isequal(r.theta,reference.result.theta));
end
fprintf('V3 FORMAL GATE PASSED\n');
