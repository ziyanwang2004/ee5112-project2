function m = poeFromRecords(r,baseName,endEffector)
% POEFROMRECORDS Toolbox-free initializer; supports fixed, R and P joints.
% T_parent_body(q)=J*exp([localS]*q)*C. All exported screws use [omega;v].
m.records = r;
m.baseName = baseName;
m.bodyNames = {r.name};
m.nBodies = numel(r);
m.nJoints = max([r.index]);
m.parent = zeros(1,m.nBodies);
m.jointIndex = [r.index];
m.M = zeros(4,4,m.nBodies);
m.Mjoint = zeros(4,4,m.nJoints);
m.S = zeros(6,m.nJoints);
m.limits = zeros(m.nJoints,2);
m.jointNames = cell(1,m.nJoints);
m.movingBody = zeros(1,m.nJoints);
for i=1:m.nBodies
    if ~strcmp(r(i).parent,baseName)
        p=find(strcmp(m.bodyNames,r(i).parent));
        assert(isscalar(p),'Parent body missing or duplicated.');
        m.parent(i)=p;
    end
end
done=false(1,m.nBodies); m.order=[];
while ~all(done)
    progress=false;
    for i=1:m.nBodies
        p=m.parent(i);
        if done(i) || (p~=0 && ~done(p)), continue; end
        Z=eye(4);
        if p~=0, Z=m.M(:,:,p); end
        Tj=Z*r(i).J;
        m.M(:,:,i)=Tj*r(i).C;
        k=r(i).index;
        if k~=0
            a=Tj(1:3,1:3)*r(i).axis(:);
            a=a/norm(a);
            if strcmp(r(i).type,'revolute')
                m.S(:,k)=[a;-cross(a,Tj(1:3,4))];
            elseif strcmp(r(i).type,'prismatic')
                m.S(:,k)=[zeros(3,1);a];
            else
                error('memberB:JointType','Only fixed/R/P joints are supported.');
            end
            m.Mjoint(:,:,k)=Tj;
            m.limits(k,:)=r(i).limits;
            m.jointNames{k}=r(i).jointName;
            m.movingBody(k)=i;
        end
        done(i)=true; m.order(end+1)=i; progress=true; %#ok<AGROW>
    end
    assert(progress,'Robot contains a cycle or a disconnected body.');
end
m.eeIndex=find(strcmp(m.bodyNames,endEffector));
assert(isscalar(m.eeIndex),'End-effector body is missing or ambiguous.');
m.endEffector=endEffector;
% Precompute Rodrigues coefficients once, outside planning loops.
m.W=zeros(3,3,m.nJoints); m.W2=m.W;
for k=1:m.nJoints
    w=m.S(1:3,k);
    m.W(:,:,k)=[0 -w(3) w(2);w(3) 0 -w(1);-w(2) w(1) 0];
    m.W2(:,:,k)=m.W(:,:,k)*m.W(:,:,k);
end
end
