root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'upgrades','task45_v4','matlab'),'-begin');
base=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat'));
c=memberC.variantOptions(base.frozen.options,'combined');
c.projectionFcn=@memberC.projectTrajectory; c.constraintMode='projected';
robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0');
g=memberB.loadUR5Spheres(model); scene=memberC.makeScene(model,c,'workcell'); w=makeVoxelWorld(scene.boxes,c);
context=struct('options',c,'geometry',g,'kinematics',struct('mode','poe','robot',robot,'model',model));
theta=c.qStart+(c.qGoal-c.qStart)*linspace(0,1,9);
[P,detail]=memberC.tangentProjectors(theta,model,c.tangentRankTolerance);
assert(detail.maxJacobianResidual<1e-9 && detail.maxIdempotenceError<1e-10);
assert(all(detail.ranks(2:end-1)==2));
q=theta(:,5); e=(1:6).'; e=e/norm(e); h=1e-4;
[~,a]=memberB.poeFK(model,q); [~,b]=memberB.poeFK(model,q+h*e);
[~,d]=memberB.poeFK(model,q+h*P(:,:,5)*e);
assert(norm(d(1:3,2)-a(1:3,2))<.01*norm(b(1:3,2)-a(1:3,2)));
sigma=.001*eye(7); rng(71); saved=rng;
ambient=context; ambient.options.samplingMode='euclidean';
[s0,n0]=stompSamples(8,sigma,theta,model.limits);
[s0,n0,v0]=memberC.projectSamples(s0,n0,theta,ambient); after=rng;
rng(saved); [s1,n1,v1]=memberC.sampleRollouts(8,sigma,theta,ambient);
assert(isequal(s0,s1) && isequal(n0,n1) && isequal(v0,v1) && isequal(after,rng));
rng(saved); [s2,n2,v2,~,samplingDetail]=memberC.sampleRollouts(8,sigma,theta,context);
assert(isequal(after,rng) && samplingDetail.tangentSamples==6 && nnz(v2)>0);
for k=1:8
    assert(isequal(s2{k}(:,[1 end]),theta(:,[1 end])));
    assert(all(s2{k}>=model.limits(:,1)-1e-12 & s2{k}<=model.limits(:,2)+1e-12,'all'));
    for j=1:6, assert(isequal(n2{j}(k,:),s2{k}(j,:)-theta(j,:))); end
end
ambient.options.projectionFcn=[]; context.options.projectionFcn=[];
rng(saved); [s1,n1]=memberC.sampleRollouts(8,sigma,theta,ambient);
rng(saved); [s2,n2]=memberC.sampleRollouts(8,sigma,theta,context);
assert(isequal(s1,s2) && isequal(n1,n2),'Task 4 sampling changed.');
context.options=c;
demo=load(fullfile(root,'artifacts','runs','task45_v3','demos','workcell','Task5','seed_5300','planning_result.mat'));
[local,total,info]=memberC.qualityCost(demo.result.theta,context,w);
assert(abs(sum(local)-total)<1e-12);
assert(abs(total-(info.jointLength+5*info.smoothness+info.bufferCost))<1e-12);
out=fullfile(root,'artifacts','local_runs','task45_v4_units',char(java.util.UUID.randomUUID()));
assert(~exist(out,'dir'),'Use a fresh unit folder.'); mkdir(out);
N=size(demo.result.theta,2); A=-2*eye(N)+diag(ones(N-1,1),1)+diag(ones(N-1,1),-1);
A=A(:,2:end-1); R=A.'*A; Ri=R\eye(N-2); Ri=(Ri+Ri.')/2; M=Ri./max(Ri,[],1)/N;
[unchanged,receipt]=memberC.refinePath(demo.result.theta,R,M,context,scene,w,out,0);
assert(isequal(unchanged,demo.result.theta) && receipt.iterations==0 && receipt.qualityBefore==receipt.qualityAfter);
release=fullfile(root,'artifacts','runs','task45_v4'); if ~exist(release,'dir'), mkdir(release); end
memberC.writeJSON(fullfile(release,'unit_tests.json'),struct('passed',true,'tangentProjectorResidual',detail.maxJacobianResidual, ...
    'rngDrawsUnchanged',true,'actualNoiseSaved',true,'task4SamplingUnchanged',true,'zeroBudgetRetainsIncumbent',true));
fprintf('V4 SAMPLING, RNG, LIMITS, QUALITY AND INCUMBENT TESTS PASSED\n');
