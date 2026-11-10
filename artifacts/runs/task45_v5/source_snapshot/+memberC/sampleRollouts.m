function [samples,noise,valid,projection,diagnostic]=sampleRollouts(count,sigma,theta,context)
% No extra random draws. Energy control matches post-limit/pre-projection norm.
c=context.options; model=context.kinematics.model;
diagnostic=struct('mode',c.samplingMode,'tangentSamples',0,'validSamples',0, ...
    'projectionCorrections',0,'maxTangentResidual',0,'tangentSeconds',0,'projectionSeconds',0, ...
    'fraction',0,'selectedMask',false(count,1),'ambientEnergy',zeros(count,1), ...
    'counterfactualTangentEnergy',nan(count,1),'preProjectionEnergy',zeros(count,1), ...
    'postProjectionEnergy',zeros(count,1),'energyScale',ones(count,1), ...
    'energyMatchMaxRelativeError',0);
[samples,noise]=stompSamples(count,sigma,theta,model.limits);
for k=1:count, diagnostic.ambientEnergy(k)=sum((samples{k}(:,2:end-1)-theta(:,2:end-1)).^2,'all'); end
if ~strcmp(c.samplingMode,'euclidean') && ~isempty(c.projectionFcn)
    fraction=c.tangentFraction;
    if strcmp(c.samplingMode,'adaptive')
        fraction=c.adaptiveInitialFraction;
        if isfield(context,'samplingState'), fraction=context.samplingState.fraction; end
    end
    diagnostic.fraction=fraction;
    timer=tic; [P,info]=memberC.tangentProjectors(theta,model,c.tangentRankTolerance);
    pairs=floor((count/2)*fraction); indices=[1:pairs,count/2+(1:pairs)];
    diagnostic.selectedMask(indices)=true;
    for k=indices
        q=theta;
        for t=2:size(theta,2)-1
            e=samples{k}(:,t)-theta(:,t); q(:,t)=theta(:,t)+P(:,:,t)*e;
        end
        q=max(model.limits(:,1),min(model.limits(:,2),q));
        q(:,1)=theta(:,1); q(:,end)=theta(:,end);
        target=sum((q(:,2:end-1)-theta(:,2:end-1)).^2,'all');
        diagnostic.counterfactualTangentEnergy(k)=target;
        if strcmp(c.samplingMode,'energy')
            scale=sqrt(target/max(diagnostic.ambientEnergy(k),realmin));
            assert(scale<=1+1e-10); scale=min(1,scale);
            q=theta+scale*(samples{k}-theta); q(:,1)=theta(:,1); q(:,end)=theta(:,end);
            diagnostic.energyScale(k)=scale;
            actual=sum((q(:,2:end-1)-theta(:,2:end-1)).^2,'all');
            diagnostic.energyMatchMaxRelativeError=max(diagnostic.energyMatchMaxRelativeError,abs(actual-target)/max(target,1e-14));
        end
        samples{k}=q;
    end
    if ~strcmp(c.samplingMode,'energy'), diagnostic.tangentSamples=numel(indices); end
    diagnostic.maxTangentResidual=info.maxJacobianResidual; diagnostic.tangentSeconds=toc(timer);
end
for k=1:count, diagnostic.preProjectionEnergy(k)=sum((samples{k}(:,2:end-1)-theta(:,2:end-1)).^2,'all'); end
timer=tic; [samples,noise,valid,projection]=memberC.projectSamples(samples,noise,theta,context);
diagnostic.projectionSeconds=toc(timer); diagnostic.validSamples=nnz(valid);
% Actual post-limit/post-projection disturbances are authoritative in both modes.
for k=1:count
    for j=1:size(theta,1), noise{j}(k,:)=samples{k}(j,:)-theta(j,:); end
    diagnostic.postProjectionEnergy(k)=sum((samples{k}(:,2:end-1)-theta(:,2:end-1)).^2,'all');
    if ~isempty(projection{k}), diagnostic.projectionCorrections=diagnostic.projectionCorrections+projection{k}.iterations; end
end
end
