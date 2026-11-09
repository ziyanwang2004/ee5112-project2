function [C,R] = fitSphereEnvelope(V,spacing,padding)
% Conservative covering of the entire convex hull, not only mesh vertices.
% A PCA-aligned cylinder contains the convex mesh. Inflate each discrete
% sphere by sqrt(radialBound^2+(axialSpacing/2)^2) to cover that cylinder.
assert(size(V,2)==3 && ~isempty(V),'Expected mesh vertices.');
mu=mean(V,1); P=V-mu;
[~,~,Q]=svd(P,0); a=Q(:,1);
t=P*a;
rho=max(sqrt(sum((P-t*a.').^2,2)));
lo=min(t); hi=max(t);
n=max(2,ceil((hi-lo)/spacing)+1);
s=linspace(lo,hi,n).';
C=mu+s*a.';
h=(hi-lo)/(n-1);
R=repmat(sqrt(rho^2+(h/2)^2)+padding,n,1);
end
