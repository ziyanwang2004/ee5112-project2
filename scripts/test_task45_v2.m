root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'upgrades','task45_v2','matlab'),'-begin'); clear functions;
out=fullfile(root,'artifacts','local_runs','task5_diagnosis_20261109');
if ~exist(out,'dir'), mkdir(out); end
d=memberC.segmentDistance([0 0 0;0 0 0;0 0 0;0 0 0], ...
    [1 0 0;1 0 0;0 0 0;1 0 0], ...
    [.5 -1 0;0 2 0;0 0 2;2 1 0], [.5 1 0;1 2 0;0 0 2;2 2 0]);
assert(max(abs(d-[0;2;2;sqrt(2)]))<1e-12);
robot=loadrobot('universalUR5','DataFormat','column'); m=memberB.buildPoeModel(robot,'tool0');
g=memberC.buildSelfGeometry(robot,m); c=memberC.defaults();
saved=load(fullfile(out,'collision_probe.mat'));
Q=[c.qStart,saved.q]; gaps=zeros(1,2); collisions=false(1,2);
for j=1:2
    T=memberB.poeFK(m,Q(:,j)); [gaps(j),pairGaps]=memberC.selfClearance(g,T);
    collisions(j)=checkCollision(robot,Q(:,j),'IgnoreSelfCollision','off','SkippedSelfCollisions','parent','Exhaustive','on');
    fprintf('STATE %d self proxy gap %.6f actual collision %d\n',j,gaps(j),collisions(j));
    for k=find(pairGaps<.005).'
        pair=g.pairs(k,:); fprintf(' %s / %s: %.6f\n',m.bodyNames{g.body(pair(1))},m.bodyNames{g.body(pair(2))},pairGaps(k));
    end
end
assert(~collisions(1) && collisions(2) && gaps(2)<0);
assert(all(g.maxRadialResidual<0) && all(g.vertexCount>0),'Mesh not enclosed.');
receipt=struct('segmentCases',4,'meshEnclosurePassed',true,'badStateDetected',true,'gaps',gaps, ...
    'capsules',numel(g.body),'pairs',size(g.pairs,1));
memberC.writeJSON(fullfile(out,'v2_geometry_tests.json'),receipt);
fprintf('V2 GEOMETRY TESTS PASSED\n');
