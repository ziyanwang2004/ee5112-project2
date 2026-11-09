function summary=replay_saved_process(runFolder)
% Reproduce saved stochastic samples and accepted updates, without replanning.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
input=load(fullfile(runFolder,'input_checkpoint.mat'));
files=dir(fullfile(runFolder,'iterations','*.mat'));
assert(~isempty(files),'No iteration checkpoints found.');
state=rng; guard=onCleanup(@()rng(state)); %#ok<NASGU>
for i=1:numel(files)
    d=load(fullfile(files(i).folder,files(i).name));
    rng(d.rngBefore);
    [paths,noise]=stompSamples(numel(d.theta_samples),d.sigma,d.thetaBefore,input.poeModel.limits);
    for k=1:numel(paths), assert(isequal(paths{k},d.theta_samples{k}),'Sample replay mismatch.'); end
    assert(isequal(noise,d.em) && isequal(rng,d.rngAfter),'RNG replay mismatch.');
    P=stompUpdateProb(d.Stheta,input.plannerOptions.sensitivity);
    assert(max(abs(P(:)-d.trajProb(:)))<1e-14,'Probability replay mismatch.');
    if d.metrics(6)==0
        q=d.thetaBefore;
    elseif d.metrics(6)==2
        q=d.theta_samples{d.acceptedSample};
    else
        [q,~]=stompUpdateTheta(d.thetaBefore,d.metrics(7)*d.dtheta,d.M);
        q=max(input.poeModel.limits(:,1),min(input.poeModel.limits(:,2),q));
        q(:,1)=input.scene.qStart; q(:,end)=input.scene.qGoal;
    end
    assert(max(abs(q(:)-d.thetaAfter(:)))<1e-13,'Accepted-update replay mismatch.');
end
summary.checkpoints=numel(files); summary.sampleReplay=true;
summary.probabilityReplay=true; summary.acceptedUpdateReplay=true;
save(fullfile(runFolder,'replay_validation.mat'),'summary','-v7');
fprintf('Replayed %d checkpoints: samples/RNG/probabilities/accepted updates passed.\n',numel(files));
end
