function [local,total,info]=qualityCost(theta,context,w)
% Fixed secondary objective. Orientation/world/self validity are hard gates.
c=context.options; N=size(theta,2); local=zeros(1,N);
lengths=vecnorm(diff(theta,1,2),2,1);
local(1:end-1)=local(1:end-1)+.5*c.qualityLengthWeight*lengths;
local(2:end)=local(2:end)+.5*c.qualityLengthWeight*lengths;
smooth=.5*sum(diff(theta,2,2).^2,1);
local(2:end-1)=local(2:end-1)+c.qualitySmoothWeight*smooth;
g=context.geometry; gap=zeros(1,N);
for t=1:N
    T=memberB.poeFK(context.kinematics.model,theta(:,t)); C=memberB.sphereCenters(g,T);
    gap(t)=min(queryVoxelSDF(C,w)-g.radius);
end
buffer=c.qualityClearanceWeight*max(0,c.qualityClearanceTarget-gap).^2/(N-1);
local=local+buffer; total=sum(local);
info=struct('jointLength',sum(lengths),'smoothness',sum(smooth),'bufferCost',sum(buffer), ...
    'minNodeClearance',min(gap),'total',total);
end
