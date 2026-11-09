function C = sphereCenters(s,T)
% Fixed sphere count/order: finite-difference sphere velocities stay aligned.
C=zeros(size(s.local));
for b=s.uniqueBodies
    k=s.body==b;
    C(k,:)=s.local(k,:)*T(1:3,1:3,b).'+T(1:3,4,b).';
end
end
