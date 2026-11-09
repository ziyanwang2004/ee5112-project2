function w=makeVoxelWorld(boxes,c)
% World arrays use dimension 1=x, dimension 2=y, dimension 3=z (ndgrid).
assert(max(abs(c.voxelSize-c.voxelSize(1)))<1e-12, ...
    'sEDT_3d assumes cubic voxels.');
n=round(c.worldExtent./c.voxelSize);
assert(all(abs(n.*c.voxelSize-c.worldExtent)<1e-12));
axes=cell(1,3);
for j=1:3, axes{j}=c.worldCorner(j)+((1:n(j))-.5)*c.voxelSize(j); end
X=reshape(axes{1},[],1,1); Y=reshape(axes{2},1,[],1); Z=reshape(axes{3},1,1,[]);
occupied=false(n);
for k=1:size(boxes,1)
    b=boxes(k,:);
    occupied=occupied | (abs(X-b(1))<=b(4) & abs(Y-b(2))<=b(5) & abs(Z-b(3))<=b(6));
end
assert(any(occupied(:)) && ~all(occupied(:)),'The voxel map is empty or full.');
w.voxel=occupied; w.voxel_size=c.voxelSize; w.world_size=n;
w.Env_size=[c.worldCorner;c.worldExtent]; w.axes=axes; w.boxes=boxes;
w.sEDT=single(c.voxelSize(1)*sEDT_3d(occupied));
w.interpolant=griddedInterpolant(axes,w.sEDT,'linear','nearest');
% Center-to-center EDT can overestimate distance to the continuous obstacle.
% Subtract half the voxel diagonal, plus interpolation uncertainty. The total
% conservative correction is one full voxel diagonal = sqrt(3)*voxelSize.
w.distanceCorrection=norm(c.voxelSize);
w.margin=c.margin; w.stationaryWeight=c.stationaryWeight;
end
