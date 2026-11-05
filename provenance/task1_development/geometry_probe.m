cd('/home/ziyan/Documents/Codex/2026-11-05/new-chat-2/outputs/EE5112_Project2_Task123/matlab');
buildKinovaSpheres(fullfile(pwd,'data','kinova_spheres.csv'));
d=load('/home/ziyan/Documents/Codex/2026-11-05/new-chat-2/work/task1/probe.mat');
robot=loadrobot('kinovaGen3','DataFormat','column');s=loadKinovaSpheres(d.m);
box=collisionBox(.16,.16,.16);box.Pose=trvec2tform([.4 .46 .26]);
for q={d.q0,d.qT}
 [T,~]=memberB.builtinFK(robot,d.m,q{1});C=memberB.sphereCenters(s,T);
 gap=memberB.boxSDF(C,[.4 .46 .26 .08 .08 .08])-s.radius;
 [~,dist]=checkCollision(robot,q{1},{box},'IgnoreSelfCollision','on','Exhaustive','on');
 fprintf('Endpoint sphere gap %.9f m; mesh gap %.9f m\n',min(gap),min(dist(:)));
end
fprintf('Sphere count: %d\n',numel(s.radius));
