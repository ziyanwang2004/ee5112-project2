function [samples,noise,valid,projection,diagnostic]=sampleRollouts(count,sigma,theta,context)
% Keep identical Gaussian RNG draws; change only selected interior directions.
c=context.options; model=context.kinematics.model;
diagnostic=struct('mode','euclidean','tangentSamples',0,'validSamples',0, ...
    'projectionCorrections',0,'maxTangentResidual',0,'tangentSeconds',0,'projectionSeconds',0);
[samples,noise]=stompSamples(count,sigma,theta,model.limits);
if strcmp(c.samplingMode,'tangent') && ~isempty(c.projectionFcn)
    timer=tic; [P,info]=memberC.tangentProjectors(theta,model,c.tangentRankTolerance);
    pairs=floor((count/2)*c.tangentFraction); indices=[1:pairs,count/2+(1:pairs)];
    for k=indices
        q=theta;
        for t=2:size(theta,2)-1
            e=samples{k}(:,t)-theta(:,t); q(:,t)=theta(:,t)+P(:,:,t)*e;
        end
        q=max(model.limits(:,1),min(model.limits(:,2),q));
        q(:,1)=theta(:,1); q(:,end)=theta(:,end); samples{k}=q;
    end
    diagnostic.mode='tangent-mixture'; diagnostic.tangentSamples=numel(indices);
    diagnostic.maxTangentResidual=info.maxJacobianResidual; diagnostic.tangentSeconds=toc(timer);
end
timer=tic; [samples,noise,valid,projection]=memberC.projectSamples(samples,noise,theta,context);
diagnostic.projectionSeconds=toc(timer); diagnostic.validSamples=nnz(valid);
% Actual post-limit/post-projection disturbances are authoritative in both modes.
for k=1:count
    for j=1:size(theta,1), noise{j}(k,:)=samples{k}(j,:)-theta(j,:); end
    if ~isempty(projection{k}), diagnostic.projectionCorrections=diagnostic.projectionCorrections+projection{k}.iterations; end
end
end
