root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'scripts')); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v5'); assert(~exist(fullfile(release,'frozen_config.mat'),'file'),'V5 already frozen.');
identity=memberC.provenance(); files=dir(fullfile(release,'development','**','planning_result.mat')); assert(numel(files)==30);
for name={'unit_tests','geometry_preflight','v4_sampling_regression','sampling_ablation'}
    r=jsondecode(fileread(fullfile(release,[name{1} '.json']))); assert(r.passed);
    if isfield(r,'sourceFingerprint'), assert(strcmp(r.sourceFingerprint,identity.sourceFingerprint)); end
end
audit_task45_v5_sampling(); regress_task45_v5_task4();
audit=audit_task45_v5(fullfile(release,'development'),fullfile(release,'development_audit.json'));
rows=audit.fineDetails; cases={'workcell','endpoints','layout'}; variants={'ambient','energy_control','fixed50','fixed75','adaptive'};
successes=zeros(3,5); common=false(1,2);
for ci=1:3
    for vi=1:5
        selected=strcmp({rows.scenario},cases{ci}) & strcmp({rows.variant},variants{vi});
        successes(ci,vi)=nnz([rows(selected).studySuccess]);
    end
end
for seed=5700:5701
    selected=strcmp({rows.scenario},'workcell') & [rows.seed]==seed & (strcmp({rows.variant},'adaptive') | strcmp({rows.variant},'fixed50'));
    common(seed-5699)=all([rows(selected).studySuccess]);
end
gate=all(successes(:,4)>=1 & successes(:,5)>=1) && any(common);
memberC.writeJSON(fullfile(release,'development_gate.json'),struct('passed',gate,'scenarios',{cases},'variants',{variants},'successes',successes,'commonAdaptiveFixed50Workcell',common));
assert(gate,'V5 development gate failed. Formal seeds remain reserved.');
base=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat')); options=struct(); parameters=struct();
for id=cases
    for variant=variants
        c=memberC.caseOptions(memberC.variantOptions(base.frozen.options,variant{1}),id{1}); c.retainRollouts=false;
        options.(id{1}).(variant{1})=c; parameters.(id{1}).(variant{1})=rmfield(c,{'constraintFcn','projectionFcn','validationFcn'});
    end
end
frozen=struct('metadata',identity,'options',options,'parameters',parameters,'developmentSeeds',5700:5701,'formalSeeds',5800:5804, ...
    'probeSeeds',5760:5764,'scenarios',{cases},'variants',{variants},'demoSeed',5699+find(common,1), ...
    'protocol','v5-cost-feedback-and-input-energy-control','workers',2,'clientDate','2026-11-09');
paths={'scripts/run_task45_v5.m','scripts/run_task45_v5_group.m','scripts/freeze_task45_v5.m','scripts/continue_task45_v5.ps1','docs/TASK45_V5_PROTOCOL.md'};
drivers=cell(1,numel(paths));
for k=1:numel(paths)
    fid=fopen(fullfile(root,paths{k}),'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    drivers{k}=struct('path',paths{k},'sha256',memberC.sha256(bytes));
end
frozen.drivers=[drivers{:}];
assets=dir(fullfile(root,'upgrades','task45_v5','matlab','**','*')); records={};
for k=1:numel(assets)
    if assets(k).isdir || endsWith(assets(k).name,'.m'), continue; end
    path=fullfile(assets(k).folder,assets(k).name); fid=fopen(path,'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    records{end+1}=struct('path',strrep(path(numel(root)+2:end),'\','/'),'sha256',memberC.sha256(bytes)); %#ok<SAGROW>
end
frozen.assetFiles=[records{:}]; save(fullfile(release,'frozen_config.mat'),'frozen','-v7');
memberC.writeJSON(fullfile(release,'frozen_config.json'),rmfield(frozen,'options'));
copyfile(fullfile(root,'upgrades','task45_v5','matlab'),fullfile(release,'source_snapshot'));
for variant={'fixed50','adaptive'}
    source=fullfile(release,'development','workcell',variant{1},'Task5',sprintf('seed_%d',frozen.demoSeed));
    target=fullfile(release,'demos','workcell',variant{1},'Task5',sprintf('seed_%d',frozen.demoSeed));
    parent=fileparts(target); if ~exist(parent,'dir'), mkdir(parent); end; copyfile(source,target);
end
fprintf('V5 DEVELOPMENT AND INDEPENDENT AUDITS PASSED; FORMAL CONFIGURATION FROZEN\n');
