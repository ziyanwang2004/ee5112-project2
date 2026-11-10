root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'scripts'));
release=fullfile(root,'artifacts','runs','task45_v2'); frozen=load(fullfile(release,'frozen_config.mat'));
seed=frozen.frozen.demoSeed; runRoot=fullfile(root,'artifacts','local_runs','task45_v2_public_smoke',char(java.util.UUID.randomUUID()));
result=run_task45_v2('task5','main',seed,false,runRoot);
reference=load(fullfile(release,'demos','main','Task5',sprintf('seed_%d',seed),'planning_result.mat'));
assert(result.main.task5.success && isequal(result.main.task5.theta,reference.result.theta));
files=dir(fullfile(runRoot,'**','*')); files=files(~[files.isdir]); hashes=cell(1,numel(files));
for j=1:numel(files)
    fid=fopen(fullfile(files(j).folder,files(j).name),'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid); hashes{j}=memberC.sha256(bytes);
end
audit=verify_task45_v2(runRoot); assert(audit.passed && audit.successfulRuns==1);
later=dir(fullfile(runRoot,'**','*')); assert(nnz(~[later.isdir])==numel(files),'Verifier added files.');
for j=1:numel(files)
    fid=fopen(fullfile(files(j).folder,files(j).name),'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    assert(strcmp(hashes{j},memberC.sha256(bytes)),'Read-only public verifier changed evidence.');
end
receipt=struct('passed',true,'publicRunnerTrajectoryBitwiseMatchesDemo',true,'publicVerifierReadOnly',true, ...
    'runRoot',runRoot,'replayedCheckpoints',audit.replayedCheckpoints,'hashedFiles',numel(files));
memberC.writeJSON(fullfile(release,'public_entrypoints_qa.json'),receipt);
fprintf('V2 PUBLIC ENTRYPOINTS PASSED\n');
