root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v3','matlab'),'-begin'); clear functions;
release=fullfile(root,'artifacts','runs','task45_v3'); if ~exist(release,'dir'), mkdir(release); end
profiles=[61 64 200 300 .55;61 64 200 300 .35;61 64 200 300 .80;81 96 300 600 .55];
identity=memberC.provenance(); seeds=5300:5302; paired=false(1,3); selected=false;
for profile=1:size(profiles,1)
    c=memberC.defaults(); c.nWaypoints=profiles(profile,1); c.nRollouts=profiles(profile,2);
    c.maxIterations=profiles(profile,3); c.maxWallSeconds=profiles(profile,4); c.noiseStd=profiles(profile,5);
    c.constraintMode='projected'; c.orientationWeight=1000; c.retainRollouts=false;
    for j=1:3
        success=false(1,2);
        for task=4:5
            folder=fullfile(release,'development',sprintf('profile_%d',profile),'workcell',sprintf('Task%d',task),sprintf('seed_%d',seeds(j)));
            if exist(fullfile(folder,'planning_result.mat'),'file')
                d=load(fullfile(folder,'planning_result.mat')); r=d.result;
                assert(strcmp(r.metadata.sourceFingerprint,identity.sourceFingerprint));
            else, r=memberC.runOne(task,'workcell',seeds(j),c,folder); end
            success(task-3)=r.success;
        end
        paired(j)=all(success);
        memberC.writeJSON(fullfile(release,'development_progress.json'),struct('profile',profile,'seed',seeds(j),'paired',paired));
    end
    if nnz(paired)>=2, selected=true; break; end
end
assert(selected,'V3 development gate exhausted; reserved formal seeds remain untouched.');
demo=seeds(find(paired,1));
frozen=struct('options',c,'metadata',identity,'developmentSeeds',seeds,'formalSeeds',5400:5419, ...
    'demoSeed',demo,'selectedProfile',profile,'pairedDevelopmentSuccess',paired,'scenario','workcell', ...
    'protocol','v3-mounted-workcell-new-endpoints-20-paired-holdouts','workers',2,'clientDate','2026-11-09');
assert(~exist(fullfile(release,'frozen_config.mat'),'file'),'Do not overwrite frozen V3.');
save(fullfile(release,'frozen_config.mat'),'frozen','-v7');
public=rmfield(frozen,'options'); public.parameters=rmfield(c,{'constraintFcn','validationFcn','projectionFcn'});
memberC.writeJSON(fullfile(release,'frozen_config.json'),public);
copyfile(fullfile(root,'upgrades','task45_v3','matlab'),fullfile(release,'source_snapshot'));
fprintf('V3 FROZEN profile %d demo %d paired %s\n',profile,demo,mat2str(paired));
