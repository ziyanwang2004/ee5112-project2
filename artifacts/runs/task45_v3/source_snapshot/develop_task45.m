function frozen=develop_task45(runRoot)
% Fixed development protocol. Never consumes the formal seed set.
root=fileparts(mfilename('fullpath')); addpath(root);
if nargin<1, runRoot=fullfile(root,'..','artifacts','local_runs','task45_development',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))); end
if ~exist(runRoot,'dir'), mkdir(runRoot); end
identity=memberC.provenance(); identityPath=fullfile(runRoot,'source_identity.json');
if exist(identityPath,'file')
    previous=jsondecode(fileread(identityPath));
    assert(strcmp(previous.sourceFingerprint,identity.sourceFingerprint),'Sources changed; use a new development directory.');
else
    memberC.writeJSON(identityPath,identity);
end
seeds=5112:5114; scenes={'main','variant'}; c=memberC.defaults(); rows=struct([]);
state=struct('phase','task4','developmentSeeds',seeds,'formalSeeds',5120:5129,'runRoot',runRoot);
selected=false; baseline=cell(2,3); baselineFolders=cell(2,3);
for profile=1:4
    if profile<=3, noises=[.55 .35 .80]; c.noiseStd=noises(profile);
    else, c.noiseStd=.55; c.nWaypoints=81; c.nRollouts=96; c.maxIterations=300; c.maxWallSeconds=600; end
    wins=false(2,3);
    for s=1:2
        for k=1:3
            folder=fullfile(runRoot,sprintf('profile_%d',profile),scenes{s},'Task4',sprintf('seed_%d',seeds(k)));
            r=evaluate(4,scenes{s},seeds(k),c,folder);
            baseline{s,k}=r; baselineFolders{s,k}=folder; wins(s,k)=r.success;
            record(r,c,folder);
        end
    end
    if all(sum(wins,2)>=2), selected=true; break; end
end
if ~selected, block('Task4 exhausted the prescribed profiles.'); end
state.phase='orientation_weights'; state.selectedProfile=profile; state.noiseStd=c.noiseStd; saveState();
paired=false(2,3); chosenFolders=cell(2,3); chosen=false;
for weight=[200 1000 5000 20000]
    c.constraintMode='penalty'; c.orientationWeight=weight;
    paired(:)=false;
    for s=1:2
        for k=1:3
            folder=fullfile(runRoot,sprintf('weight_%d',weight),scenes{s},'Task5',sprintf('seed_%d',seeds(k)));
            r=evaluate(5,scenes{s},seeds(k),c,folder);
            chosenFolders{s,k}=folder; paired(s,k)=baseline{s,k}.success && r.success;
            record(r,c,folder);
        end
    end
    if all(sum(paired,2)>=2), chosen=true; break; end
end
if ~chosen
    state.phase='projection'; saveState(); c.constraintMode='projected'; c.orientationWeight=1000;
    for s=1:2
        for k=1:3
            folder=fullfile(runRoot,'projected',scenes{s},'Task5',sprintf('seed_%d',seeds(k)));
            r=evaluate(5,scenes{s},seeds(k),c,folder);
            chosenFolders{s,k}=folder; paired(s,k)=baseline{s,k}.success && r.success;
            record(r,c,folder);
        end
    end
    if ~all(sum(paired,2)>=2), block('Task5 projection exhausted the prescribed development budget.'); end
end
demo=find(all(paired,1),1); assert(~isempty(demo));
frozen=struct('options',c,'demoSeed',seeds(demo),'developmentSeeds',seeds, ...
    'formalSeeds',5120:5129,'developmentRoot',runRoot,'metadata',memberC.provenance(), ...
    'protocol','paired-scenarios-v2-stall10','pairedDevelopmentSuccess',paired);
finalRoot=fullfile(root,'..','artifacts','runs','task45_final');
assert(~exist(finalRoot,'dir'),'Do not overwrite a frozen study.'); mkdir(finalRoot);
save(fullfile(finalRoot,'frozen_config.mat'),'frozen','-v7');
public=frozen; public=rmfield(public,'options'); public.parameters=rmfield(c,{'constraintFcn','validationFcn','projectionFcn'});
memberC.writeJSON(fullfile(finalRoot,'frozen_config.json'),public);
for s=1:2
    for t=4:5
        destination=fullfile(finalRoot,'demos',scenes{s},sprintf('Task%d',t),sprintf('seed_%d',seeds(demo)));
        if t==4, source=baselineFolders{s,demo}; else, source=chosenFolders{s,demo}; end
        mkdir(fileparts(destination)); copyfile(source,destination);
    end
end
state.phase='frozen'; state.demoSeed=seeds(demo); state.constraintMode=c.constraintMode; saveState();
fprintf('FROZEN demo seed %d mode %s weight %.0f noise %.2f\n',frozen.demoSeed,c.constraintMode,c.orientationWeight,c.noiseStd);
    function r=evaluate(task,id,seed,options,folder)
        path=fullfile(folder,'planning_result.mat');
        if exist(path,'file')
            saved=load(path); r=saved.result;
            assert(strcmp(r.metadata.sourceFingerprint,identity.sourceFingerprint));
            assert(r.task==task && r.seed==seed && strcmp(r.scenarioId,id));
        else
            r=memberC.runOne(task,id,seed,options,folder);
        end
    end
    function record(r,options,folder)
        entry=memberC.summarizeRun(r,options); entry.folder=folder;
        if isempty(rows), rows=entry; else, rows(end+1)=entry; end
        memberC.writeRunTable(fullfile(runRoot,'development_results.csv'),rows);
        saveState();
    end
    function saveState()
        state.completedRuns=numel(rows); memberC.writeJSON(fullfile(runRoot,'development_state.json'),state);
    end
    function block(message)
        state.phase='blocked'; state.reason=message; saveState(); error('memberC:DevelopmentGate','%s',message);
    end
end
