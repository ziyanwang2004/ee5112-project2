function [samples,noise,valid,diagnostics]=projectSamples(samples,noise,theta,context)
valid=true(numel(samples),1); c=context.options;
diagnostics=cell(numel(samples),1);
if isempty(c.projectionFcn), return; end
for k=1:numel(samples)
    [samples{k},valid(k),diagnostics{k}]=c.projectionFcn(samples{k},context);
    for j=1:size(theta,1), noise{j}(k,:)=samples{k}(j,:)-theta(j,:); end
end
end
