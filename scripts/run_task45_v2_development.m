root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'upgrades','task45_v2','matlab'),'-begin'); clear functions;
runRoot=fullfile(root,'artifacts','runs','task45_v2','development','self_filter_60000');
c=memberC.defaults(); c.constraintMode='projected'; c.orientationWeight=1000; c.retainRollouts=false;
% Unused development seeds; original failed seeds are not fresh holdouts.
for scene={'main','variant'}
    for seed=5150:5152
        folder=fullfile(runRoot,scene{1},'Task5',sprintf('seed_%d',seed));
        if exist(fullfile(folder,'planning_result.mat'),'file'), continue; end
        memberC.runOne(5,scene{1},seed,c,folder);
    end
end
fprintf('V2 DEVELOPMENT COMPLETED\n');
