function out = checkSpherePath(theta,fk,s,scene,maxStep)
Q=memberB.densify(theta,maxStep);
out.clearance=inf(1,size(Q,2));
for t=1:size(Q,2)
    [T,~]=fk(Q(:,t));
    d=memberB.boxSDF(memberB.sphereCenters(s,T),scene.boxes)-s.radius;
    out.clearance(t)=min(d);
end
out.minClearance=min(out.clearance);
out.nStates=size(Q,2);
out.inCollision=any(out.clearance<=0);
out.theta=Q;
end
