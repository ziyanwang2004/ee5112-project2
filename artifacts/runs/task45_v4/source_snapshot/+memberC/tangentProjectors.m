function [P,details]=tangentProjectors(theta,model,tolerance)
% Orthogonal null-space projectors of the direction Jacobian at each node.
Joints=size(theta,1); N=size(theta,2); P=repmat(eye(Joints),1,1,N);
details=struct('ranks',zeros(1,N),'maxJacobianResidual',0,'maxIdempotenceError',0);
for t=2:N-1
    J=memberC.directionJacobian(model,theta(:,t));
    [~,S,V]=svd(J,'econ'); keep=diag(S)>tolerance;
    B=V(:,keep); P(:,:,t)=eye(Joints)-B*B.';
    details.ranks(t)=nnz(keep);
    details.maxJacobianResidual=max(details.maxJacobianResidual,norm(J*P(:,:,t),'fro'));
    details.maxIdempotenceError=max(details.maxIdempotenceError,norm(P(:,:,t)^2-P(:,:,t),'fro'));
end
end
