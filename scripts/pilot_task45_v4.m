root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'scripts'));
run('test_task45_v4.m');
release=fullfile(root,'artifacts','runs','task45_v4');
output=fullfile(release,'development');
result=run_task45_v4('task5','combined',5500,output);
assert(result.task5.success,'V4 first pilot failed; inspect before expanding.');
audit=verify_task45_v4(fullfile(output,'combined'));
memberC.writeJSON(fullfile(release,'pilot_audit.json'),audit);
fprintf('V4 PILOT COMPLETE\n');
