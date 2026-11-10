function [centers,radi]=stompRobotSphere(X,geometry,Tall)
% UR5 extension keeps the original one-input signature available.
% Runtime UR5 costs use fixed body-attached spheres (constant count/order).
if nargin>=3
    centers=memberB.sphereCenters(geometry,Tall); radi=geometry.radius; return;
end
% Original KINOVA-style polyline approximation for legacy callers only.
centers=[]; radi=[]; p=[0 0 0]; rad=.05;
for j=1:size(X,1)
    q=X(j,1:3); n=ceil(norm(q-p)/rad)+1;
    C=p+(q-p).*linspace(0,1,n).';
    centers=[centers;C]; radi=[radi;repmat(rad,n,1)]; %#ok<AGROW>
    p=q;
end
end
