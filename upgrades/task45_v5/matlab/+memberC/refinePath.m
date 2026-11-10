function [theta,out]=refinePath(theta,R,M,context,scene,w,folder,remaining)
% Strict secondary improvement plus unchanged full acceptance for every update.
c=context.options; N=size(theta,2); model=context.kinematics.model;
Ri=R\eye(N-2); Ri=(Ri+Ri.')/2; sigma=Ri/max(diag(Ri))*c.refineNoiseStd^2;
[~,quality,components]=memberC.qualityCost(theta,context,w);
out=struct('iterations',0,'accepted',0,'elapsedSeconds',0,'qualityBefore',quality, ...
    'qualityAfter',quality,'history',zeros(0,8),'reason','iteration limit', ...
    'samplingSeconds',0,'costSeconds',0,'validationSeconds',0,'traceSeconds',0);
budget=min(c.refineMaxSeconds,remaining); timer=tic;
traceFolder=fullfile(folder,'refinement'); mkdir(traceFolder);
for iter=1:c.refineMaxIterations
    if toc(timer)>=budget, out.reason='time target'; break; end
    thetaBefore=theta; qualityBefore=quality; rngBefore=rng;
    part=tic;
    [theta_samples,em,validSamples,projectionDiagnostics,samplingDiagnostics]=memberC.sampleRollouts(c.refineRollouts,sigma,theta,context);
    out.samplingSeconds=out.samplingSeconds+toc(part); part=tic;
    Stheta=zeros(c.refineRollouts,N); sampleTotals=inf(c.refineRollouts,1);
    for k=find(validSamples).'
        [Stheta(k,:),sampleTotals(k)]=memberC.qualityCost(theta_samples{k},context,w);
    end
    trajProb=memberC.sampleProbabilities(Stheta,validSamples,c.sensitivity);
    dtheta=stompDTheta(trajProb,em); [~,smoothed]=stompUpdateTheta(theta,dtheta,M);
    magnitude=max(abs(smoothed(:)));
    if magnitude>c.refineMaxUpdate, dtheta=dtheta*c.refineMaxUpdate/magnitude; end
    out.costSeconds=out.costSeconds+toc(part);
    acceptedCode=0; acceptedAlpha=0; acceptedSample=0; candidateScores=nan(1,3);
    candidateValid=false(1,3); candidateProjectionDiagnostics=cell(1,3);
    part=tic;
    for ai=1:3
        alphas=[1 .5 .25]; alpha=alphas(ai);
        q=stompUpdateTheta(theta,alpha*dtheta,M);
        q=max(model.limits(:,1),min(model.limits(:,2),q)); q(:,1)=scene.qStart; q(:,end)=scene.qGoal;
        valid=true;
        if ~isempty(c.projectionFcn), [q,valid,candidateProjectionDiagnostics{ai}]=c.projectionFcn(q,context); end
        if ~valid, continue; end
        [~,score,detail]=memberC.qualityCost(q,context,w); candidateScores(ai)=score;
        if score>=quality-1e-9 || detail.minNodeClearance<c.margin-1e-9, continue; end
        candidateValid(ai)=c.validationFcn(q,context,scene,w,c.finalDenseJointStep,false);
        if candidateValid(ai)
            theta=q; quality=score; components=detail; acceptedCode=1; acceptedAlpha=alpha; break;
        end
    end
    fallbackChecked=[]; fallbackValid=[];
    if acceptedCode==0
        [sorted,order]=sort(sampleTotals);
        for rank=1:min(3,numel(order))
            k=order(rank); if ~isfinite(sorted(rank)) || sorted(rank)>=quality-1e-9, break; end
            [~,score,detail]=memberC.qualityCost(theta_samples{k},context,w);
            if detail.minNodeClearance<c.margin-1e-9, continue; end
            ok=c.validationFcn(theta_samples{k},context,scene,w,c.finalDenseJointStep,false);
            fallbackChecked(end+1)=k; fallbackValid(end+1)=ok; %#ok<AGROW>
            if ok
                theta=theta_samples{k}; quality=score; components=detail; acceptedCode=2; acceptedSample=k; break;
            end
        end
    end
    out.validationSeconds=out.validationSeconds+toc(part);
    thetaAfter=theta; qualityAfter=quality; rngAfter=rng;
    assert(qualityAfter<=qualityBefore+1e-9);
    metrics=[iter,quality,components.minNodeClearance,components.jointLength,components.smoothness,components.bufferCost,acceptedCode,acceptedAlpha];
    out.history(end+1,:)=metrics; out.iterations=iter; out.accepted=out.accepted+(acceptedCode~=0);
    part=tic; file=fullfile(traceFolder,sprintf('iteration_%03d.mat',iter));
    save(file,'thetaBefore','thetaAfter','qualityBefore','qualityAfter','Stheta','sampleTotals', ...
        'trajProb','dtheta','metrics','acceptedCode','acceptedAlpha','acceptedSample','rngBefore','rngAfter', ...
        'sigma','R','M','validSamples','projectionDiagnostics','samplingDiagnostics','em', ...
        'candidateScores','candidateValid','candidateProjectionDiagnostics','fallbackChecked','fallbackValid','-v7');
    if c.retainRollouts, save(file,'theta_samples','-append'); end
    out.traceSeconds=out.traceSeconds+toc(part);
    if iter==1 || mod(iter,5)==0
        fprintf('REFINE %d quality %.6f accepted %d elapsed %.1f s\n',iter,quality,out.accepted,toc(timer));
    end
end
out.elapsedSeconds=toc(timer); out.qualityAfter=quality;
end
