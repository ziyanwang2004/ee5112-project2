root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'scripts'));
addpath(fullfile(root,'upgrades','task45_v4','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v4');
assert(~exist(fullfile(release,'frozen_config.mat'),'file'),'V4 is already frozen.');
files=dir(fullfile(release,'development','**','planning_result.mat')); assert(numel(files)==12);
identity=memberC.provenance(); paired=true(1,3); developmentSuccess=false(3,4);
variants={'baseline','anytime','tangent','combined'};
for j=1:3
    seed=5499+j;
    for index=1:4
        v=variants(index);
        d=load(fullfile(release,'development',v{1},'workcell','Task5',sprintf('seed_%d',seed),'planning_result.mat'));
        assert(strcmp(d.result.metadata.sourceFingerprint,identity.sourceFingerprint));
        developmentSuccess(j,index)=d.result.success; paired(j)=paired(j)&&d.result.success;
    end
end
assert(nnz(developmentSuccess(:,4))>=2 && any(paired),'V4 development gate failed. Do not access formal seeds.');
units=jsondecode(fileread(fullfile(release,'unit_tests.json'))); assert(units.passed);
regression=jsondecode(fileread(fullfile(release,'regression_audit.json'))); assert(regression.v3BaselineBitwiseUnchanged);
audit=audit_task45_v4(fullfile(release,'development'),fullfile(release,'development_audit.json'));
base=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat')); options=struct(); parameters=struct();
for v=variants
    options.(v{1})=memberC.variantOptions(base.frozen.options,v{1}); options.(v{1}).retainRollouts=false;
    parameters.(v{1})=rmfield(options.(v{1}),{'constraintFcn','validationFcn','projectionFcn'});
end
frozen=struct('metadata',identity,'options',options,'developmentSeeds',5500:5502,'formalSeeds',5600:5609, ...
    'demoSeed',5499+find(paired,1),'pairedDevelopmentSuccess',paired,'scenario','workcell', ...
    'protocol','v4-two-by-two-anytime-tangent','workers',2,'clientDate','2026-11-09');
frozen.developmentSuccess=developmentSuccess;
driverPaths={'scripts/run_task45_v4_group.m','scripts/run_task45_v4.m','scripts/freeze_task45_v4.m', ...
    'scripts/continue_task45_v4.ps1','docs/TASK45_V4_PROTOCOL.md'};
drivers=cell(1,numel(driverPaths));
for k=1:numel(driverPaths)
    fid=fopen(fullfile(root,driverPaths{k}),'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    drivers{k}=struct('path',driverPaths{k},'sha256',memberC.sha256(bytes));
end
frozen.drivers=[drivers{:}];
save(fullfile(release,'frozen_config.mat'),'frozen','-v7');
public=rmfield(frozen,'options'); public.parameters=parameters;
memberC.writeJSON(fullfile(release,'frozen_config.json'),public);
copyfile(fullfile(root,'upgrades','task45_v4','matlab'),fullfile(release,'source_snapshot'));
for v=variants
    source=fullfile(release,'development',v{1},'workcell','Task5',sprintf('seed_%d',frozen.demoSeed));
    target=fullfile(release,'demos',v{1},'workcell','Task5',sprintf('seed_%d',frozen.demoSeed));
    parent=fileparts(target); if ~exist(parent,'dir'), mkdir(parent); end; copyfile(source,target);
end
fprintf('V4 DEVELOPMENT AUDIT AND FREEZE PASSED\n');
