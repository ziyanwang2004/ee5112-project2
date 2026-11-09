function E = twistExp(S,q)
% TWISTEXP Closed-form exp([S]*q), S=[omega;v], unit R/P screw.
w=S(1:3); v=S(4:6);
if norm(w)<1e-14
    E=[eye(3),v*q;0 0 0 1];
    return;
end
assert(abs(norm(w)-1)<1e-10,'Revolute screw must have unit omega.');
W=[0 -w(3) w(2);w(3) 0 -w(1);-w(2) w(1) 0];
W2=W*W;
% 2*sin(q/2)^2 avoids cancellation in 1-cos(q).
b=2*sin(q/2)^2;
if abs(q)<1e-4
    a=q^3/6-q^5/120+q^7/5040;
else
    a=q-sin(q);
end
R=eye(3)+sin(q)*W+b*W2;
p=(eye(3)*q+b*W+a*W2)*v;
E=[R,p;0 0 0 1];
end
