function [Q,s]=samplePath(theta,maxStep)
assert(maxStep>0 && size(theta,2)>=2 && all(isfinite(theta(:))));
N=size(theta,2); Q=theta(:,1); s=0;
for k=1:N-1
    n=max(1,ceil(max(abs(theta(:,k+1)-theta(:,k)))/maxStep)); a=(1:n)/n;
    Q=[Q,theta(:,k)+(theta(:,k+1)-theta(:,k))*a]; %#ok<AGROW>
    s=[s,((k-1)+a)/(N-1)]; %#ok<AGROW>
end
end
