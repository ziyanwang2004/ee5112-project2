function [J,y,Tee]=directionJacobian(model,q)
[~,Tee,G]=memberB.poeFK(model,q); y=Tee(1:3,2);
J=zeros(3,model.nJoints);
for k=1:model.nJoints
    parent=model.parent(model.movingBody(k)); R=eye(3);
    if parent~=0, R=G(1:3,1:3,parent); end
    J(:,k)=cross(R*model.S(1:3,k),y);
end
end
