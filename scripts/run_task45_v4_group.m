function run_task45_v4_group(stage,worker)
assert(any(strcmp(stage,{'development','formal'})) && ismember(worker,[0 1]));
root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'upgrades','task45_v4','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v4');
base=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat'));
identity=memberC.provenance();
if strcmp(stage,'formal')
    data=load(fullfile(release,'frozen_config.mat')); seeds=data.frozen.formalSeeds;
    assert(strcmp(identity.sourceFingerprint,data.frozen.metadata.sourceFingerprint));
    for record=data.frozen.drivers
        fid=fopen(fullfile(root,record.path),'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
        assert(strcmp(memberC.sha256(bytes),record.sha256),'Formal driver changed.');
    end
else, seeds=5500:5502; end
variants={'baseline','anytime','tangent','combined'}; completed=0;
for seed=seeds(mod(seeds,2)==worker)
    order=circshift(1:4,[0 mod(seed,4)]);
    for index=order
        variant=variants{index};
        if strcmp(stage,'formal'), c=data.frozen.options.(variant);
        else, c=memberC.variantOptions(base.frozen.options,variant); end
        c.retainRollouts=false;
        folder=fullfile(release,stage,variant,'workcell','Task5',sprintf('seed_%d',seed));
        if exist(fullfile(folder,'planning_result.mat'),'file')
            d=load(fullfile(folder,'planning_result.mat')); r=d.result;
            assert(strcmp(r.metadata.sourceFingerprint,identity.sourceFingerprint),'Existing run has different sources.');
        else, r=memberC.runOne(5,'workcell',seed,c,folder); end
        completed=completed+1;
        memberC.writeJSON(fullfile(release,sprintf('%s_worker_%d_progress.json',stage,worker)), ...
            struct('completed',completed,'lastVariant',variant,'lastSeed',seed,'lastSuccess',r.success));
    end
end
fprintf('V4 %s worker %d COMPLETE: %d runs\n',stage,worker,completed);
end
