root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v3','matlab'),'-begin'); clear functions;
out=fullfile(root,'artifacts','runs','task45_v3'); if ~exist(out,'dir'), mkdir(out); end
robot=memberC.loadRobot(); m=memberB.buildPoeModel(robot,'tool0'); c=memberC.defaults(); c.constraintMode='projected';
g=memberB.loadUR5Spheres(m); scene=memberC.makeScene(m,c,'workcell'); w=makeVoxelWorld(scene.boxes,c);
context=struct('options',c,'geometry',g,'kinematics',struct('mode','poe','robot',robot,'model',m));
maxFkError=0;
for q={zeros(6,1),c.qStart,c.qGoal,[.2;-1.2;1.4;-.2;-pi/2;0]}
    [T,~]=memberB.poeFK(m,q{1});
    for b=1:m.nBodies
        reference=getTransform(robot,q{1},m.bodyNames{b}); maxFkError=max(maxFkError,max(abs(reference-T(:,:,b)),[],'all'));
    end
end
assert(maxFkError<1e-9 && m.nBodies==11);
for endpoint={c.qStart,c.qGoal}
    sc=scene; sc.qStart=endpoint{1}; sc.qGoal=endpoint{1};
    [ok,a]=memberC.validatePath([endpoint{1},endpoint{1}],context,sc,w,.0125,true); assert(ok && a.minToolHeight>0);
end
bad=[.1;1;-.5;-.5;-pi/2;0]; sc=scene; sc.qStart=bad; sc.qGoal=bad;
[ok,a]=memberC.validatePath([bad,bad],context,sc,w,.0125,true);
assert(~ok && ~a.toolAboveTable && ~a.mesh.worldCollisionFree && any(strcmp(a.failures,'below_table')));
sc=scene; sc.allowedWorldContactBody='forearm_link'; rejected=false;
try, memberB.checkMatlabPath(robot,[c.qStart,c.qStart],sc,c); catch, rejected=true; end
assert(rejected,'Invalid broad contact exemption accepted.');
floor=collisionBox(2,2,.4); floor.Pose=[eye(3),[0;0;-.2];0 0 0 1];
[~,sep]=checkCollision(robot,c.qStart,{floor},'IgnoreSelfCollision','on','Exhaustive','on');
mount=find(strcmp(robot.BodyNames,'mount_pedestal'));
assert(all(~isnan(sep(setdiff(1:size(sep,1),mount),:)),'all'));
context.selfGeometry=memberC.buildSelfGeometry(robot,m);
assert(any(context.selfGeometry.body==mount),'Pedestal missing from self-collision proxy.');
memberC.writeJSON(fullfile(out,'geometry_tests.json'),struct('passed',true,'allBodyFkError',maxFkError, ...
    'belowTableRejected',true,'onlyFixedMountContactAllowed',true,'pedestalIncludedInSelfChecks',true));
fprintf('V3 GEOMETRY/CONTACT TESTS PASSED\n');
