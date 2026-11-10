function v=checkVoxelPath(theta,fk,geometry,w,maxStep)
Q=memberB.densify(theta,maxStep);
v.clearance=inf(1,size(Q,2));
for t=1:size(Q,2)
    [T,~]=fk(Q(:,t));
    C=memberB.sphereCenters(geometry,T);
    v.clearance(t)=min(queryVoxelSDF(C,w)-geometry.radius);
end
v.minClearance=min(v.clearance); v.nStates=size(Q,2);
v.inCollision=any(v.clearance<=0); v.theta=Q;
end
