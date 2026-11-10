function [theta,valid,details]=projectTrajectory(theta,context)
% Deterministic axis projection. No additional random draws.
c=context.options; m=context.kinematics.model;
valid=true; details.failedWaypoints=[]; details.iterations=0; details.reason='';
for t=2:size(theta,2)-1
    q=theta(:,t); good=false;
    for iter=1:c.projectionMaxIterations
        [J,y]=memberC.directionJacobian(m,q);
        angle=memberC.directionError(y);
        if angle<=c.projectionToleranceDeg, good=true; break; end
        e=[0;0;1]-y;
        if dot(y,[0;0;1])<-.9999
            [~,j]=min(abs(y)); reference=zeros(3,1); reference(j)=1;
            axis=cross(y,reference); axis=axis/norm(axis);
            e=cross(axis,y); % deterministic tangent away from the antipode
        end
        delta=J.'*((J*J.'+c.projectionDamping^2*eye(3))\e);
        scale=max(abs(delta)); if scale>c.projectionMaxStep, delta=delta*c.projectionMaxStep/scale; end
        q=max(m.limits(:,1),min(m.limits(:,2),q+delta));
        details.iterations=details.iterations+1;
    end
    [~,Tee]=memberB.poeFK(m,q);
    good=good || memberC.directionError(Tee(1:3,2))<=c.projectionToleranceDeg;
    theta(:,t)=q;
    if ~good, valid=false; details.failedWaypoints(end+1)=t; end %#ok<AGROW>
end
if ~valid, details.reason='orientation projection did not converge within the joint limits and iteration budget'; end
end
