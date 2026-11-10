function out=replayRun(folder)
% Read-only replay of raw RNG draws, projected samples, weights, accepted steps.
d=load(fullfile(folder,'input_checkpoint.mat')); c=d.plannerOptions;
robot=memberC.loadRobot();
context=struct('options',c,'geometry',d.geometry, ...
    'kinematics',struct('mode','poe','robot',robot,'model',d.poeModel));
context.selfGeometry=d.selfGeometry;
context.selfThreshold=d.selfThreshold;
files=dir(fullfile(folder,'iterations','*.mat')); assert(~isempty(files));
state=rng; guard=onCleanup(@()rng(state)); %#ok<NASGU>
out=struct('checkpoints',numel(files),'sampleMaxError',0,'probabilityMaxError',0,'acceptedMaxError',0,'rngIdentical',true);
previous=[]; final=load(fullfile(folder,'planning_result.mat'),'result');
matchesResult=isequal(final.result.searchTheta,final.result.initial);
for i=1:numel(files)
    a=load(fullfile(files(i).folder,files(i).name)); rng(a.rngBefore);
    [samples,noise,valid]=memberC.sampleRollouts(c.nRollouts,a.sigma,a.thetaBefore,context);
    assert(isequal(valid,a.validSamples),'Projection validity replay mismatch.');
    assert(isequal(rng,a.rngAfter),'Random-state replay mismatch.');
    if isfield(a,'theta_samples')
        for k=1:numel(samples)
            out.sampleMaxError=max(out.sampleMaxError,max(abs(samples{k}(:)-a.theta_samples{k}(:))));
        end
    end
    if isfield(a,'em')
        for j=1:numel(noise), assert(max(abs(noise{j}(:)-a.em{j}(:)))<1e-12); end
    end
    P=memberC.sampleProbabilities(a.Stheta,valid,c.sensitivity);
    out.probabilityMaxError=max(out.probabilityMaxError,max(abs(P(:)-a.trajProb(:))));
    delta=stompDTheta(P,noise); [~,smooth]=stompUpdateTheta(a.thetaBefore,delta,a.M);
    if max(abs(smooth(:)))>c.maxUpdate, delta=delta*c.maxUpdate/max(abs(smooth(:))); end
    assert(max(abs(delta(:)-a.dtheta(:)))<1e-12);
    if a.metrics(6)==0
        q=a.thetaBefore;
    elseif a.metrics(6)==2
        q=samples{a.acceptedSample};
    else
        q=stompUpdateTheta(a.thetaBefore,a.metrics(7)*delta,a.M);
        q=max(d.poeModel.limits(:,1),min(d.poeModel.limits(:,2),q));
        q(:,1)=d.scene.qStart; q(:,end)=d.scene.qGoal;
        if ~isempty(c.projectionFcn), [q,ok]=c.projectionFcn(q,context); assert(ok); end
    end
    out.acceptedMaxError=max(out.acceptedMaxError,max(abs(q(:)-a.thetaAfter(:))));
    matchesResult=matchesResult || max(abs(q(:)-final.result.searchTheta(:)))<1e-12;
    if ~isempty(previous) && a.metrics(1)==previous.restart
        assert(max(abs(a.thetaBefore(:)-previous.q(:)))<1e-12,'Trace chain discontinuity.');
    end
    previous=struct('restart',a.metrics(1),'q',a.thetaAfter);
end
assert(out.sampleMaxError<1e-12 && out.probabilityMaxError<1e-13 && out.acceptedMaxError<1e-12);
assert(matchesResult,'Final output is absent from the accepted optimizer states.');
refinement=memberC.replayRefinement(folder,d,context,final.result);
out.searchCheckpoints=out.checkpoints; out.refinement=refinement;
out.checkpoints=out.checkpoints+refinement.checkpoints; out.passed=true;
end
