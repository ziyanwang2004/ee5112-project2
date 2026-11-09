function [X,T,Tee,Tall]=updateJointsWorldPosition(robot_struct,theta,kinematics)
% Received function name and first two arguments retained.
% Cache kinematics outside the STOMP loop. Fixed bodies consume no q entries.
if nargin<3
    robot=copy(robot_struct); robot.DataFormat='column';
    model=memberB.buildPoeModel(robot,robot.BodyNames{end});
    kinematics=struct('mode','builtin','robot',robot,'model',model);
end
m=kinematics.model;
if strcmp(kinematics.mode,'poe')
    [Tall,Tee,G]=memberB.poeFK(m,theta);
    T=cell(1,m.nJoints); X=zeros(m.nJoints,4);
    for j=1:m.nJoints
        T{j}=G(:,:,m.movingBody(j))*m.Mjoint(:,:,j);
        X(j,:)=[T{j}(1:3,4).',1];
    end
else
    [Tall,Tee]=memberB.builtinFK(kinematics.robot,m,theta);
    T=cell(1,m.nJoints); X=zeros(m.nJoints,4);
    for j=1:m.nJoints
        b=m.movingBody(j); parent=m.parent(b); Tp=eye(4);
        if parent~=0, Tp=Tall(:,:,parent); end
        rec=m.records(b); E=eye(4); a=rec.axis(:);
        if strcmp(rec.type,'revolute')
            W=[0 -a(3) a(2);a(3) 0 -a(1);-a(2) a(1) 0];
            E(1:3,1:3)=eye(3)+sin(theta(j))*W+(1-cos(theta(j)))*W*W;
        else
            E(1:3,4)=a*theta(j);
        end
        T{j}=Tp*rec.J*E;
        X(j,:)=[T{j}(1:3,4).',1];
    end
end
end
