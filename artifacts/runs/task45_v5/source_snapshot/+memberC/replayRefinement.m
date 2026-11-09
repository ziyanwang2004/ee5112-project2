function out=replayRefinement(folder,d,context,result)
c=d.plannerOptions; files=dir(fullfile(folder,'refinement','*.mat'));
q=result.searchTheta; w=makeVoxelWorld(d.scene.boxes,c);
out=struct('checkpoints',numel(files),'accepted',0,'maxAcceptedError',0,'passed',true);
for i=1:numel(files)
    a=load(fullfile(files(i).folder,files(i).name)); assert(max(abs(q(:)-a.thetaBefore(:)))<1e-12);
    rng(a.rngBefore);
    [samples,noise,valid,~,diagnostic]=memberC.sampleRollouts(c.refineRollouts,a.sigma,a.thetaBefore,context);
    memberC.checkSamplingDiagnostics(diagnostic,a.samplingDiagnostics);
    assert(isequal(valid,a.validSamples) && isequal(rng,a.rngAfter));
    for j=1:numel(noise), assert(max(abs(noise{j}(:)-a.em{j}(:)))<1e-12); end
    if isfield(a,'theta_samples')
        for k=1:numel(samples), assert(max(abs(samples{k}(:)-a.theta_samples{k}(:)))<1e-12); end
    end
    P=memberC.sampleProbabilities(a.Stheta,valid,c.sensitivity);
    assert(max(abs(P(:)-a.trajProb(:)))<1e-13);
    delta=stompDTheta(P,noise); [~,smooth]=stompUpdateTheta(a.thetaBefore,delta,a.M);
    if max(abs(smooth(:)))>c.refineMaxUpdate, delta=delta*c.refineMaxUpdate/max(abs(smooth(:))); end
    assert(max(abs(delta(:)-a.dtheta(:)))<1e-12);
    if a.acceptedCode==1
        q=stompUpdateTheta(a.thetaBefore,a.acceptedAlpha*delta,a.M);
        q=max(d.poeModel.limits(:,1),min(d.poeModel.limits(:,2),q)); q(:,1)=d.scene.qStart; q(:,end)=d.scene.qGoal;
        if ~isempty(c.projectionFcn), [q,ok]=c.projectionFcn(q,context); assert(ok); end
    elseif a.acceptedCode==2, q=samples{a.acceptedSample};
    else, assert(a.acceptedCode==0); end
    out.maxAcceptedError=max(out.maxAcceptedError,max(abs(q(:)-a.thetaAfter(:))));
    [~,before]=memberC.qualityCost(a.thetaBefore,context,w); [~,after]=memberC.qualityCost(q,context,w);
    assert(abs(before-a.qualityBefore)<1e-9 && abs(after-a.qualityAfter)<1e-9);
    assert(after<=before+1e-9);
    if a.acceptedCode~=0
        assert(after<before && c.validationFcn(q,context,d.scene,w,c.finalDenseJointStep,false));
        out.accepted=out.accepted+1;
    end
end
assert(out.maxAcceptedError<1e-12 && max(abs(q(:)-result.theta(:)))<1e-12);
assert(numel(files)==result.refinement.iterations);
end
