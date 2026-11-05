addpath('/home/ziyan/Documents/Codex/2026-11-05/new-chat-2/outputs/EE5112_AB_Integration_R2023b/02_integrated_code');
robot=loadrobot('kinovaGen3','DataFormat','column');
ik=inverseKinematics('RigidBodyTree',robot); ik.SolverParameters.AllowRandomRestart=false;
A=trvec2tform([.4 0 .2])*axang2tform([0 1 0 pi]); B=trvec2tform([.35 .55 .35])*axang2tform([0 1 0 pi]);
[q0,s0]=ik('EndEffector_Link',A,ones(1,6),homeConfiguration(robot)); q0=wrapToPi(q0);
[qT,sT]=ik('EndEffector_Link',B,ones(1,6),q0);qT=wrapToPi(qT);
m=memberB.buildPoeModel(robot,'EndEffector_Link');
box=collisionBox(.16,.16,.16);box.Pose=trvec2tform([.4 .46 .26]);
disp('Q0');disp(q0');disp('QT');disp(qT');disp(s0);disp(sT);
for q={q0,qT}, disp(checkCollision(robot,q{1},{box},'IgnoreSelfCollision','on','Exhaustive','on'));end
V=rigidBodyTree('DataFormat','column'); b=copy(robot.Bodies{4}); b.Joint=rigidBodyJoint('fixed_probe','fixed'); addBody(V,b,V.BaseName);
f=figure('Visible','off');ax=show(V,'Visuals','off','Collisions','on','Frames','off');patches=findobj(ax,'Type','Patch');
fprintf('Body=%s patches=%d\n',b.Name,numel(patches));
for k=1:numel(patches), fprintf('tag=%s, vertices=%d\n',patches(k).Tag,size(patches(k).Vertices,1));disp([min(patches(k).Vertices);max(patches(k).Vertices)]);end
save('/home/ziyan/Documents/Codex/2026-11-05/new-chat-2/work/task1/probe.mat','q0','qT','m','s0','sT','-v7');
close all;
