% Adapted from received helperCreateObstaclesKINOVA.m.
% Keep voxel occupancy -> sEDT, with an unambiguous x/y/z array convention.
scene=memberB.makeScene(poeModel,plannerOptions);
voxel_world=makeVoxelWorld(scene.boxes,plannerOptions);
world=cell(1,size(scene.boxes,1));
for obstacleIndex=1:numel(world)
    box=scene.boxes(obstacleIndex,:);
    world{obstacleIndex}=collisionBox(2*box(4),2*box(5),2*box(6));
    world{obstacleIndex}.Pose=[eye(3),box(1:3).';0 0 0 1];
end
