root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'scripts'));
release=fullfile(root,'artifacts','runs','task45_v3'); data=load(fullfile(release,'frozen_config.mat')); f=data.frozen;
smoke=fullfile(root,'artifacts','local_runs','task45_v3_export_smoke'); assert(~exist(smoke,'dir')); mkdir(smoke);
copyfile(fullfile(release,'frozen_config.mat'),fullfile(smoke,'frozen_config.mat'));
for task=4:5
    source=fullfile(release,'development',sprintf('profile_%d',f.selectedProfile),'workcell',sprintf('Task%d',task),sprintf('seed_%d',f.demoSeed),'planning_result.mat');
    folder=fullfile(smoke,'demos','workcell',sprintf('Task%d',task),sprintf('seed_%d',f.demoSeed)); mkdir(folder);
    copyfile(source,fullfile(folder,'planning_result.mat'));
end
export_task45_v3(smoke,false);
fprintf('V3 EXPORT SMOKE PASSED\n');
