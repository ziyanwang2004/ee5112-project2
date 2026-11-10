function model = buildPoeModel(robot, endEffector)
% BUILDPOEMODEL Cache zero poses and space screws WITHOUT getTransform.
% q=0 is used, NOT homeConfiguration (which may contain nonzero home angles).
assert(strcmp(robot.DataFormat,'column'),'Use DataFormat = column.');
r = copy(robot);
r.DataFormat = 'struct';
h = homeConfiguration(r);
jointNames = {h.JointName};
blank = struct('name','','parent','','jointName','','type','fixed', ...
    'axis',[0;0;1],'J',eye(4),'C',eye(4),'index',0,'limits',[0 0]);
records = repmat(blank,1,robot.NumBodies);
for i = 1:robot.NumBodies
    b = robot.Bodies{i};
    j = b.Joint;
    records(i).name = b.Name;
    records(i).parent = b.Parent.Name;
    records(i).jointName = j.Name;
    records(i).type = j.Type;
    records(i).J = j.JointToParentTransform;
    records(i).C = j.ChildToJointTransform;
    if ~strcmp(j.Type,'fixed')
        k = find(strcmp(jointNames,j.Name));
        assert(isscalar(k),'Joint-to-configuration mapping is ambiguous.');
        records(i).index = k;
        records(i).axis = j.JointAxis(:);
        records(i).limits = j.PositionLimits;
    end
end
model = memberB.poeFromRecords(records,robot.BaseName,endEffector);
end
