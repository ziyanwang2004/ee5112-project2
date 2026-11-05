function [theta_paths,em]=stompSamples(nSamplePaths,sigma,theta,limits)
% Complete the received function without changing its first three arguments.
% em{joint}: nRollouts-by-nWaypoints, with exact zero endpoint perturbations.
[J,N]=size(theta);
assert(isequal(size(sigma),[N-2 N-2]) && mod(nSamplePaths,2)==0);
if nargin<4, limits=repmat([-inf inf],J,1); end
L=chol((sigma+sigma.')/2,'lower');
em=cell(1,J); theta_paths=cell(1,nSamplePaths);
for j=1:J
    z=randn(nSamplePaths/2,N-2)*L.';
    em{j}=[zeros(nSamplePaths,1),[z;-z],zeros(nSamplePaths,1)];
end
for k=1:nSamplePaths
    e=zeros(J,N);
    for j=1:J, e(j,:)=em{j}(k,:); end
    q=max(limits(:,1),min(limits(:,2),theta+e));
    q(:,1)=theta(:,1); q(:,end)=theta(:,end);
    theta_paths{k}=q;
    % Projection changes the perturbation: preserve the actual sampled noise.
    for j=1:J, em{j}(k,:)=q(j,:)-theta(j,:); end
end
end
