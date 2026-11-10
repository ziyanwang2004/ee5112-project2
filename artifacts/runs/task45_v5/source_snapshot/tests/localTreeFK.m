function [T,Tee] = localTreeFK(m,q)
% Independent oracle: multiply local joint transforms using MATLAB expm.
T=zeros(4,4,m.nBodies);
for i=m.order
    r=m.records(i); A=eye(4);
    if m.parent(i)~=0, A=T(:,:,m.parent(i)); end
    U=zeros(4);
    if r.index~=0
        a=r.axis(:)/norm(r.axis);
        if strcmp(r.type,'revolute')
            U(1:3,1:3)=[0 -a(3) a(2);a(3) 0 -a(1);-a(2) a(1) 0];
        else
            U(1:3,4)=a;
        end
        U=U*q(r.index);
    end
    T(:,:,i)=A*r.J*expm(U)*r.C;
end
Tee=T(:,:,m.eeIndex);
end
