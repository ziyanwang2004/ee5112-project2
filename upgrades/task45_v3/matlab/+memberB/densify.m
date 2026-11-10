function dense = densify(theta,maxStep)
% Every interpolated joint increment has absolute magnitude <= maxStep.
assert(maxStep>0 && size(theta,2)>=2,'Invalid densification request.');
dense=theta(:,1);
for k=1:size(theta,2)-1
    n=max(1,ceil(max(abs(theta(:,k+1)-theta(:,k)))/maxStep));
    alpha=(1:n)/n;
    dense=[dense,theta(:,k)+(theta(:,k+1)-theta(:,k))*alpha]; %#ok<AGROW>
end
end
