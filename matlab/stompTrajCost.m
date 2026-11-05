function [Stheta,Qtheta,info]=stompTrajCost(robot_struct,theta,R,voxel_world,context)
% Original four arguments retained; context caches the robot model/settings.
% The active call chain stays updateJointsWorldPosition -> stompRobotSphere
% -> stompObstacleCost, with only the FK mode changing between Tasks 2 and 3.
assert(nargin>=5,'Pass the cached context created by UR5_STOMP_Path_Planning.');
c=context.options; N=size(theta,2); dt=1/(N-1);
centers=zeros(numel(context.geometry.radius),3,N);
localConstraint=zeros(1,N);
for t=1:N
    [X,~,Tee,Tall]=updateJointsWorldPosition(robot_struct,theta(:,t),context.kinematics);
    [centers(:,:,t),radii]=stompRobotSphere(X,context.geometry,Tall);
    if ~isempty(c.constraintFcn)
        localConstraint(t)=c.constraintFcn(theta(:,t),Tee);
    end
end
assert(all(isfinite(localConstraint)) && all(localConstraint>=0));
Stheta=zeros(1,N); minGap=inf; obstacleSum=0;
for t=1:N
    if t==1, v=(centers(:,:,2)-centers(:,:,1))/dt;
    elseif t==N, v=(centers(:,:,N)-centers(:,:,N-1))/dt;
    else, v=(centers(:,:,t+1)-centers(:,:,t-1))/(2*dt); end
    [vCost,detail]=stompObstacleCost(centers(:,:,t),radii,voxel_world,vecnorm(v,2,2));
    Stheta(t)=c.obstacleWeight*vCost*dt+localConstraint(t)*dt;
    obstacleSum=obstacleSum+c.obstacleWeight*vCost*dt;
    minGap=min(minGap,detail.minClearance);
end
% Keep R as the covariance/smoothing metric; fixed endpoints contribute to
% actual acceleration through the full second difference, not zero padding.
assert(isequal(size(R),[N-2 N-2]));
smooth=.5*c.smoothWeight*sum(diff(theta,2,2).^2,1);
Stheta(2:N-1)=Stheta(2:N-1)+smooth;
Qtheta=sum(Stheta);
info.minClearance=minGap; info.obstacleCost=obstacleSum;
info.smoothness=sum(smooth); info.constraintCost=sum(localConstraint)*dt;
end
