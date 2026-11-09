function audit=verify_task45_v2(runRoot)
% Read-only revalidation and complete RNG/update replay; no saved file edits.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v2','matlab'),'-begin');
assert(contains(which('memberC.plan'),fullfile('upgrades','task45_v2','matlab')));
audit=verify_task45(runRoot);
end
