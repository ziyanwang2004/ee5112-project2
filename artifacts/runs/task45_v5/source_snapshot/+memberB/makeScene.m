function scene = makeScene(m,c)
% Geometry-adapted single-cube scenario comparable to the original Task 1.
% Place the cube at wrist_1's origin on the LINEAR initialization midpoint.
% This deterministic rule avoids assuming that KINOVA's workspace fits UR5.
[T,~]=memberB.poeFK(m,(c.qStart+c.qGoal)/2);
b=find(strcmp(m.bodyNames,'wrist_1_link'));
assert(isscalar(b),'Expected the UR5 wrist_1_link frame.');
center=T(1:3,4,b).';
scene.boxes=[center,repmat(c.cubeSide/2,1,3)];
scene.qStart=c.qStart; scene.qGoal=c.qGoal;
scene.description='Single 0.16 m cube at the initial midpoint wrist position';
end
