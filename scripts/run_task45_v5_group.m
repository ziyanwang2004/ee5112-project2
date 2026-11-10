function run_task45_v5_group(stage,worker)
assert(any(strcmp(stage,{'development','formal'})) && ismember(worker,[0 1]));
root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v5'); base=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat'));
identity=memberC.provenance();
if strcmp(stage,'formal')
    data=load(fullfile(release,'frozen_config.mat')); seeds=data.frozen.formalSeeds;
    assert(strcmp(identity.sourceFingerprint,data.frozen.metadata.sourceFingerprint));
    for row=[data.frozen.drivers,data.frozen.assetFiles]
        fid=fopen(fullfile(root,row.path),'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
        assert(strcmp(memberC.sha256(bytes),row.sha256),'Frozen formal driver changed.');
    end
else
    for name={'unit_tests','geometry_preflight','v4_sampling_regression'}
        receipt=jsondecode(fileread(fullfile(release,[name{1} '.json']))); assert(receipt.passed);
    end
    seeds=5700:5701;
end
variants={'ambient','energy_control','fixed50','fixed75','adaptive'}; scenarios={'workcell','endpoints','layout'}; completed=0;
for caseIndex=1:3
    scenario=scenarios{caseIndex};
    for seed=seeds(mod((seeds-seeds(1))+(caseIndex-1)*numel(seeds),2)==worker)
        order=circshift(1:5,[0 mod(seed+caseIndex,5)]);
        for index=order
            variant=variants{index};
            if strcmp(stage,'formal'), c=data.frozen.options.(scenario).(variant);
            else, c=memberC.caseOptions(memberC.variantOptions(base.frozen.options,variant),scenario); end
            c.retainRollouts=false; folder=fullfile(release,stage,scenario,variant,'Task5',sprintf('seed_%d',seed));
            if exist(fullfile(folder,'planning_result.mat'),'file')
                d=load(fullfile(folder,'planning_result.mat')); r=d.result;
                assert(strcmp(r.metadata.sourceFingerprint,identity.sourceFingerprint),'Existing run source mismatch.');
            else, r=memberC.runOne(5,scenario,seed,c,folder); end
            completed=completed+1;
            memberC.writeJSON(fullfile(release,sprintf('%s_worker_%d_progress.json',stage,worker)), ...
                struct('completed',completed,'lastScenario',scenario,'lastVariant',variant,'lastSeed',seed,'lastSuccess',r.success));
        end
    end
end
fprintf('V5 %s worker %d COMPLETE: %d runs\n',stage,worker,completed);
end
