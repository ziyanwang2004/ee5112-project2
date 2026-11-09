function v = checkMatlabPath(robot,theta,scene,c)
% Independent dense check against MATLAB's loaded collision geometry.
% IgnoreSelfCollision matches the supplied project baseline; world collisions
% are the Task 2 acceptance gate. Self-collision is reported separately.
world=cell(1,size(scene.boxes,1));
for b=1:numel(world)
    box=scene.boxes(b,:);
    world{b}=collisionBox(2*box(4),2*box(5),2*box(6));
    world{b}.Pose=[eye(3),box(1:3).';0 0 0 1];
end
Q=memberB.densify(theta,c.denseJointStep);
v.worldInCollision=false(1,size(Q,2));
v.selfInCollision=v.worldInCollision;
v.worldSeparation=inf(1,size(Q,2));
for k=1:size(Q,2)
    [flag,sep]=checkCollision(robot,Q(:,k),world,'IgnoreSelfCollision','on','Exhaustive','on');
    collisionMask=isnan(sep);
    assert(any(flag(:))==any(collisionMask(:)),'Unexpected collision matrix semantics.');
    if isfield(scene,'allowedWorldContactBody')
        mount=find(strcmp(robot.BodyNames,scene.allowedWorldContactBody));
        assert(isscalar(mount) && strcmp(scene.allowedWorldContactBody,'mount_pedestal'));
        assert(scene.allowedWorldContactObstacle==scene.floorIndex && scene.tableHeight==0);
        collisionMask(mount,scene.floorIndex)=false;
        sep(mount,scene.floorIndex)=Inf;
    end
    v.worldInCollision(k)=any(collisionMask(:));
    finite=sep(isfinite(sep));
    if v.worldInCollision(k), v.worldSeparation(k)=0;
    elseif ~isempty(finite), v.worldSeparation(k)=min(finite); end
    flag=checkCollision(robot,Q(:,k),'IgnoreSelfCollision','off', ...
        'SkippedSelfCollisions','parent','Exhaustive','on');
    v.selfInCollision(k)=any(flag(:));
end
v.nStates=size(Q,2);
v.worldCollisionFree=~any(v.worldInCollision);
v.selfCollisionFree=~any(v.selfInCollision);
v.minWorldSeparation=min(v.worldSeparation);
v.theta=Q;
end
