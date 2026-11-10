function test_task45()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
assert(memberC.directionError([0;0;1])==0);
assert(memberC.directionError([0;0;-1])==180);
assert(abs(memberC.directionError([1;0;0])-90)<1e-12);
robot=loadrobot('universalUR5','DataFormat','column'); model=memberB.buildPoeModel(robot,'tool0');
c=memberC.defaults(); geometry=memberB.loadUR5Spheres(model);
context=struct('options',c,'geometry',geometry,'kinematics',struct('mode','poe','robot',robot,'model',model));
rng(90); maxJacError=0;
for k=1:12
    q=randn(6,1); [J,~]=memberC.directionJacobian(model,q); numeric=J;
    for j=1:6
        a=q; b=q; a(j)=a(j)+1e-6; b(j)=b(j)-1e-6;
        [~,A]=memberB.poeFK(model,a); [~,B]=memberB.poeFK(model,b);
        numeric(:,j)=(A(1:3,2)-B(1:3,2))/2e-6;
    end
    maxJacError=max(maxJacError,max(abs(J(:)-numeric(:))));
end
assert(maxJacError<1e-8);
theta=[c.qStart,zeros(6,1),c.qGoal]; theta(6,2)=pi;
[q,valid]=memberC.projectTrajectory(theta,context);
assert(valid && isequal(q(:,[1 end]),theta(:,[1 end])));
[~,T]=memberB.poeFK(model,q(:,2)); assert(memberC.directionError(T(1:3,2))<=1);
[Q,s]=memberC.samplePath([c.qStart,c.qGoal],.0125);
assert(max(abs(diff(Q,1,2)),[],'all')<=.0125+1e-12 && s(1)==0 && s(end)==1);
S=[ones(1,5);zeros(1,5);ones(1,5)]; P=memberC.sampleProbabilities(S,[true;false;true],10);
assert(all(P(2,:)==0) && all(abs(sum(P,1)-1)<1e-14));
P=memberC.sampleProbabilities(S,false(3,1),10); assert(all(P(:)==0));
for id={'main','variant'}
    scene=memberC.makeScene(model,c,id{1}); w=makeVoxelWorld(scene.boxes,c);
    for k=1:3, assert(queryVoxelSDF(scene.boxes(k,1:3),w)<0); end
    [ok,v]=memberC.validatePath([c.qStart,c.qGoal],context,scene,w,.025);
    assert(~ok && ~v.mesh.worldCollisionFree);
    for endpoint={c.qStart,c.qGoal}
        sc=scene; sc.qStart=endpoint{1}; sc.qGoal=endpoint{1};
        [ok,~]=memberC.validatePath([endpoint{1},endpoint{1}],context,sc,w,.0125); assert(ok);
    end
end
% An obstacle-free but tilted path must fail specifically the orientation gate.
scene=memberC.makeScene(model,c,'main'); scene.boxes=[-.8 .8 .8 .02 .02 .02];
c.constraintMode='penalty'; context.options=c; w=makeVoxelWorld(scene.boxes,c);
theta=[c.qStart,(c.qStart+c.qGoal)/2,c.qGoal]; theta(6,2)=.4;
[ok,v]=memberC.validatePath(theta,context,scene,w,.025);
assert(~ok && ~v.orientationSatisfied && v.mesh.worldCollisionFree);
% A failed projection is rejected, and limits remain part of acceptance.
context.options.projectionMaxIterations=0;
[~,valid,details]=memberC.projectTrajectory(theta,context);
assert(~valid && ~isempty(details.failedWaypoints) && ~isempty(details.reason));
context.options=c; context.options.constraintMode='none';
outside=c.qStart; outside(1)=model.limits(1,2)+.1;
scene.qStart=outside; scene.qGoal=outside;
[ok,v]=memberC.validatePath([outside,outside],context,scene,w,.025);
assert(~ok && ~v.jointLimitsSatisfied);
% Detect an actual self collision using the independent robot geometry.
rng(432); found=false;
for k=1:100
    q=-pi+2*pi*rand(6,1);
    flag=checkCollision(robot,q,'IgnoreSelfCollision','off','SkippedSelfCollisions','parent','Exhaustive','on');
    if any(flag(:)), found=true; break; end
end
assert(found); scene.qStart=q; scene.qGoal=q;
for mode={'none','penalty'}
    context.options.constraintMode=mode{1};
    [ok,v]=memberC.validatePath([q,q],context,scene,w,.025);
    assert(~ok && ~v.mesh.selfCollisionFree && any(strcmp(v.failures,'self_collision')));
end
fprintf('Task45 tests PASSED; direction Jacobian maximum error %.3g\n',maxJacError);
end
