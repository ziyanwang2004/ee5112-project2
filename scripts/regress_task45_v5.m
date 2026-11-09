root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
base=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat'));
robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0'); rows={};
for pair={{'anytime','ambient'},{'combined','fixed75'}}
    names=pair{1}; folder=fullfile(root,'artifacts','runs','task45_v4','demos',names{1},'workcell','Task5','seed_5500');
    d=load(fullfile(folder,'input_checkpoint.mat')); assert(isequal(model.S,d.poeModel.S) && isequal(model.M,d.poeModel.M));
    c=memberC.variantOptions(base.frozen.options,names{2}); c.projectionFcn=@memberC.projectTrajectory;
    context=struct('options',c,'kinematics',struct('mode','poe','robot',robot,'model',model));
    files=dir(fullfile(folder,'iterations','*.mat')); maximum=0;
    for k=1:numel(files)
        a=load(fullfile(files(k).folder,files(k).name)); rng(a.rngBefore);
        [samples,noise,valid]=memberC.sampleRollouts(c.nRollouts,a.sigma,a.thetaBefore,context);
        assert(isequal(rng,a.rngAfter) && isequal(valid,a.validSamples));
        for j=1:6, maximum=max(maximum,max(abs(noise{j}(:)-a.em{j}(:)))); end
        if isfield(a,'theta_samples')
            for j=1:numel(samples), maximum=max(maximum,max(abs(samples{j}(:)-a.theta_samples{j}(:)))); end
        end
    end
    assert(maximum<1e-12); rows{end+1}=struct('v4Variant',names{1},'v5Variant',names{2},'checkpoints',numel(files),'maximumNoiseError',maximum); %#ok<SAGROW>
end
memberC.writeJSON(fullfile(root,'artifacts','runs','task45_v5','v4_sampling_regression.json'),struct('passed',true,'details',{rows}));
fprintf('V4 AMBIENT AND FIXED75 SEARCH SAMPLING REPLAY COMPATIBILITY PASSED\n');
