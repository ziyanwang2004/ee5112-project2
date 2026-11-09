root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'upgrades','task45_v2','matlab'),'-begin'); clear functions;
addpath(fullfile(root,'scripts'));
release=fullfile(root,'artifacts','runs','task45_v2'); dev=fullfile(release,'development','self_filter_60000');
c=memberC.defaults(); c.constraintMode='projected'; c.orientationWeight=1000; c.retainRollouts=false;
identity=memberC.provenance(); paired=false(2,3); scenes={'main','variant'}; seeds=5150:5152;
for s=1:2
    for k=1:3
        folder=fullfile(dev,scenes{s},'Task5',sprintf('seed_%d',seeds(k)));
        d=load(fullfile(folder,'planning_result.mat')); assert(strcmp(d.result.metadata.sourceFingerprint,identity.sourceFingerprint));
        b=d.result.success;
        folder=fullfile(dev,scenes{s},'Task4',sprintf('seed_%d',seeds(k)));
        if exist(fullfile(folder,'planning_result.mat'),'file'), d=load(fullfile(folder,'planning_result.mat')); r=d.result;
        else, r=memberC.runOne(4,scenes{s},seeds(k),c,folder); end
        assert(strcmp(r.metadata.sourceFingerprint,identity.sourceFingerprint)); paired(s,k)=b && r.success;
    end
end
audit_task45_v2(dev);
memberC.writeJSON(fullfile(dev,'development_gate.json'),struct('pairedSuccess',paired,'passed',all(sum(paired,2)>=2)));
assert(all(sum(paired,2)>=2),'V2 paired development gate failed; do not launch formal trials.');
demo=find(all(paired,1),1); assert(~isempty(demo));
frozen=struct('options',c,'metadata',identity,'developmentSeeds',seeds,'formalSeeds',5200:5209, ...
    'demoSeed',seeds(demo),'pairedDevelopmentSuccess',paired,'developmentRoot',dev, ...
    'protocol','v2-self-aware-fresh-holdouts-two-workers','clientDate','2026-11-09', ...
    'workers',2,'workerAssignment','mod(seed,2)','comparisonsToV1','Success counts descriptive; no cross-version timing inference.');
path=fullfile(release,'frozen_config.mat'); assert(~exist(path,'file'),'Frozen config already exists.');
drivers={'scripts/freeze_task45_v2.m','scripts/run_task45_v2_worker.m','scripts/finalize_task45_v2.m','scripts/continue_task45_v2.ps1'};
frozen.drivers=cell(1,numel(drivers));
for j=1:numel(drivers)
    fid=fopen(fullfile(root,drivers{j}),'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    frozen.drivers{j}=struct('path',drivers{j},'sha256',memberC.sha256(bytes));
end
save(path,'frozen','-v7'); public=rmfield(frozen,'options');
public.parameters=rmfield(c,{'constraintFcn','validationFcn','projectionFcn'});
memberC.writeJSON(fullfile(release,'frozen_config.json'),public);
% Save a source snapshot once before accessing reserved holdouts.
copyfile(fullfile(root,'upgrades','task45_v2','matlab'),fullfile(release,'source_snapshot'));
for s=1:2
    for task=4:5
        folder=fullfile(release,'demos',scenes{s},sprintf('Task%d',task),sprintf('seed_%d',frozen.demoSeed));
        demoOptions=c; demoOptions.retainRollouts=true;
        r=memberC.runOne(task,scenes{s},frozen.demoSeed,demoOptions,folder);
        old=load(fullfile(dev,scenes{s},sprintf('Task%d',task),sprintf('seed_%d',frozen.demoSeed),'planning_result.mat'));
        assert(r.success && isequal(r.theta,old.result.theta),'Demo differs from development trajectory.');
    end
end
fprintf('V2 CONFIGURATION FROZEN; demo %d; paired successes %s\n',frozen.demoSeed,mat2str(paired));
