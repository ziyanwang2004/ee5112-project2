% Original Task 1 physical scene: keep cube center and dimensions unchanged.
scene.boxes=[.4 .46 .26 .08 .08 .08];
scene.qStart=plannerOptions.qStart; scene.qGoal=plannerOptions.qGoal;
scene.description='Original KINOVA Gen3 scenario from supplied Task 1';
voxel_world=makeVoxelWorld(scene.boxes,plannerOptions);
world={collisionBox(.16,.16,.16)};
world{1}.Pose=trvec2tform([.4 .46 .26]);
