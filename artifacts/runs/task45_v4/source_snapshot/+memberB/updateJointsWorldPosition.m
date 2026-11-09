function [X,T,Tee] = updateJointsWorldPosition(model,q)
% Integration adapter: X is nDOF-by-4; T is 1-by-nDOF cell.
% Pass the cached model, rather than a rigidBodyTree, inside the cost loop.
[~,Tee,G]=memberB.poeFK(model,q);
T=cell(1,model.nJoints); X=zeros(model.nJoints,4);
for k=1:model.nJoints
    T{k}=G(:,:,model.movingBody(k))*model.Mjoint(:,:,k);
    X(k,:)=[T{k}(1:3,4).',1];
end
end
