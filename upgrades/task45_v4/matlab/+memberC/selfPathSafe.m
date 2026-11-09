function [safe,checks]=selfPathSafe(theta,context)
% Actual mesh self-collision rejection inside optimization, early exit.
% Coarse interpolation here saves time; the final unified gate stays .0125.
robot=context.kinematics.robot; checks=0; safe=false;
for k=1:size(theta,2)
    checks=checks+1;
    if checkCollision(robot,theta(:,k),'IgnoreSelfCollision','off', ...
            'SkippedSelfCollisions','parent','Exhaustive','off'), return; end
end
Q=memberB.densify(theta,context.options.selfCheckJointStep);
for k=1:size(Q,2)
    checks=checks+1;
    if checkCollision(robot,Q(:,k),'IgnoreSelfCollision','off', ...
            'SkippedSelfCollisions','parent','Exhaustive','off'), return; end
end
safe=true;
end
