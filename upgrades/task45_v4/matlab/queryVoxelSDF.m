function d=queryVoxelSDF(P,w)
% Evaluate the cached EDT and conservatively treat map boundaries as solid.
assert(size(P,2)==3 && all(isfinite(P(:))),'Expected finite N-by-3 positions.');
d=double(w.interpolant(P(:,1),P(:,2),P(:,3)))-w.distanceCorrection;
lo=w.Env_size(1,:); hi=lo+w.Env_size(2,:);
% This signed clearance is positive inside the map and negative outside.
boundary=min([P-lo,hi-P],[],2);
d=min(d,boundary);
end
