function [passed,v]=validatePath(theta,context,scene,w,maxStep,fullMesh)
c=context.options; m=context.kinematics.model; g=context.geometry;
if nargin<5, maxStep=c.denseJointStep; end
if nargin<6, fullMesh=true; end
[Q,s]=memberC.samplePath(theta,maxStep); count=size(Q,2);
v=struct('nStates',count,'maxJointStep',maxStep,'s',s,'theta',Q);
v.endpointsUnchanged=isequal(theta(:,1),scene.qStart) && isequal(theta(:,end),scene.qGoal);
v.jointLimitsSatisfied=all(all(Q>=m.limits(:,1)-1e-12 & Q<=m.limits(:,2)+1e-12));
v.voxelClearance=zeros(1,count); v.sphereClearance=v.voxelClearance;
v.orientationDeg=v.voxelClearance; v.toolPosition=zeros(3,count);
for k=1:count
    [T,E]=memberB.poeFK(m,Q(:,k)); C=memberB.sphereCenters(g,T);
    v.voxelClearance(k)=min(queryVoxelSDF(C,w)-g.radius);
    v.sphereClearance(k)=min(memberB.boxSDF(C,scene.boxes)-g.radius);
    v.orientationDeg(k)=memberC.directionError(E(1:3,2)); v.toolPosition(:,k)=E(1:3,4);
end
v.minVoxelClearance=min(v.voxelClearance); v.minSphereClearance=min(v.sphereClearance);
v.maxOrientationDeg=max(v.orientationDeg); v.meanOrientationDeg=trapz(s,v.orientationDeg);
v.orientationSatisfied=strcmp(c.constraintMode,'none') || v.maxOrientationDeg<=c.orientationToleranceDeg+1e-8;
v.proxyMarginSatisfied=v.minVoxelClearance>=c.margin-1e-9 && v.minSphereClearance>0;
v.jointPathLength=sum(vecnorm(diff(theta,1,2),2,1));
v.toolPathLength=sum(vecnorm(diff(v.toolPosition,1,2),2,1));
v.smoothness=.5*sum(diff(theta,2,2).^2,'all');
cheap=v.endpointsUnchanged && v.jointLimitsSatisfied && v.proxyMarginSatisfied && v.orientationSatisfied;
v.meshChecked=fullMesh || cheap;
if v.meshChecked
    cc=c; cc.denseJointStep=maxStep;
    v.mesh=memberB.checkMatlabPath(context.kinematics.robot,theta,scene,cc);
else
    v.mesh=struct('worldCollisionFree',false,'selfCollisionFree',false, ...
        'minWorldSeparation',NaN,'nStates',count);
end
passed=cheap && v.mesh.worldCollisionFree && v.mesh.selfCollisionFree;
v.passed=passed; v.failures={};
if ~v.endpointsUnchanged, v.failures{end+1}='endpoints'; end
if ~v.jointLimitsSatisfied, v.failures{end+1}='joint_limits'; end
if ~v.proxyMarginSatisfied, v.failures{end+1}='proxy_margin'; end
if ~v.orientationSatisfied, v.failures{end+1}='orientation'; end
if v.meshChecked && ~v.mesh.worldCollisionFree, v.failures{end+1}='world_collision'; end
if v.meshChecked && ~v.mesh.selfCollisionFree, v.failures{end+1}='self_collision'; end
end
