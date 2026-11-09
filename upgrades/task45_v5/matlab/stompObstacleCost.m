function [cost,detail]=stompObstacleCost(centers,radius,voxel_world,vel)
% Complete the received Eq. (13) hook using its original four arguments.
% gap is distance from a covering sphere surface to the voxel obstacle.
radius=radius(:); vel=vel(:);
assert(size(centers,1)==numel(radius) && numel(vel)==numel(radius));
gap=queryVoxelSDF(centers,voxel_world)-radius;
hinge=max(voxel_world.margin-gap,0);
detail.velocityWeighted=sum(hinge.*vel);
detail.stationary=voxel_world.stationaryWeight*sum(hinge.^2);
detail.minClearance=min(gap);
cost=detail.velocityWeighted+detail.stationary;
end
