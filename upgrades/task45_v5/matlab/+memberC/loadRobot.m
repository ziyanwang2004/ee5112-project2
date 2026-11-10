function robot=loadRobot()
% UR5 on a 0.20 m rigid pedestal, in the world frame of a z=0 table.
robot=loadrobot('universalUR5','DataFormat','column');
base=getBody(robot,'base_link');
setFixedTransform(base.Joint,[eye(3),[0;0;.20];0 0 0 1]);
pedestal=rigidBody('mount_pedestal');
pedestal.Joint=rigidBodyJoint('mount_pedestal_fixed','fixed');
setFixedTransform(pedestal.Joint,[eye(3),[0;0;-.10];0 0 0 1]);
addCollision(pedestal,collisionBox(.18,.18,.20));
addVisual(pedestal,'Box',[.18 .18 .20]);
addBody(robot,pedestal,'base_link');
assert(strcmp(robot.BaseName,'world'));
pose=getTransform(robot,zeros(6,1),'mount_pedestal');
assert(abs(pose(3,4)-.10)<1e-12,'Incorrect mounting height.');
end
