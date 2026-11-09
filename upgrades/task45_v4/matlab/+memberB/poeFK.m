function [T,Tee,G] = poeFK(m,q)
% POEFK All-body PoE. One exponential per DOF, shared ancestor products.
q=q(:);
assert(numel(q)==m.nJoints && all(isfinite(q)),'Invalid joint vector.');
E=zeros(4,4,m.nJoints);
for k=1:m.nJoints
    if norm(m.S(1:3,k))<1e-14
        E(:,:,k)=[eye(3),m.S(4:6,k)*q(k);0 0 0 1];
    else
        x=q(k); b=2*sin(x/2)^2;
        if abs(x)<1e-4, a=x^3/6-x^5/120+x^7/5040;
        else, a=x-sin(x); end
        W=m.W(:,:,k); W2=m.W2(:,:,k);
        E(:,:,k)=[eye(3)+sin(x)*W+b*W2, ...
            (eye(3)*x+b*W+a*W2)*m.S(4:6,k);0 0 0 1];
    end
end
T=zeros(4,4,m.nBodies); G=T;
for i=m.order
    p=m.parent(i); A=eye(4);
    if p~=0, A=G(:,:,p); end
    k=m.jointIndex(i);
    if k~=0, A=A*E(:,:,k); end
    G(:,:,i)=A;
    T(:,:,i)=A*m.M(:,:,i);
end
Tee=T(:,:,m.eeIndex);
end
