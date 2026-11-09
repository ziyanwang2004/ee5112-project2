function [T,Tee] = builtinFK(robot,m,q)
% Task 2/reference only. Never used by the Task 3 planning callback.
T=zeros(4,4,m.nBodies);
for i=1:m.nBodies
    T(:,:,i)=getTransform(robot,q,m.bodyNames{i},m.baseName);
end
Tee=T(:,:,m.eeIndex);
end
