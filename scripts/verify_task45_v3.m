function audit=verify_task45_v3(runRoot)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v3','matlab'),'-begin');
audit=verify_task45(runRoot);
end
