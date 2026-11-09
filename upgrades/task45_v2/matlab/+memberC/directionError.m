function degrees=directionError(y)
% atan2 is stable both at alignment and at the antipodal direction.
y=y(:); assert(numel(y)==3 && all(isfinite(y)) && norm(y)>0);
y=y/norm(y); z=[0;0;1];
degrees=atan2d(norm(cross(y,z)),max(-1,min(1,dot(y,z))));
end
