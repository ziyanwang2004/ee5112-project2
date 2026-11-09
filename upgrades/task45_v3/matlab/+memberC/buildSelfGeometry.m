function g=buildSelfGeometry(robot,m)
% Capsules enclose each convex collision mesh. They guide optimization only;
% MATLAB's independent mesh collision checks remain the acceptance authority.
% Public graphics extraction follows the existing buildKinovaSpheres method.
persistent cached cachedKey;
key=struct('bodyNames',{m.bodyNames},'parent',m.parent,'M',m.M);
if ~isempty(cached) && isequal(key,cachedKey), g=cached; return; end
g=struct('body',[],'a',zeros(0,3),'b',zeros(0,3),'radius',[],'pairs',zeros(0,2), ...
    'maxRadialResidual',[],'vertexCount',[]);
for i=1:m.nBodies
    body=copy(robot.Bodies{i}); if isempty(body.Collisions), continue; end
    body.Joint=rigidBodyJoint(['self_capsule_' num2str(i)],'fixed');
    tree=rigidBodyTree('DataFormat','column'); addBody(tree,body,tree.BaseName);
    f=figure('Visible','off'); guard=onCleanup(@()close(f));
    ax=show(tree,'Visuals','off','Collisions','on','Frames','off');
    patches=findobj(ax,'Type','Patch','DisplayName',[body.Name '_coll_mesh']);
    assert(~isempty(patches),'Missing collision vertices.');
    for k=1:numel(patches)
        V=double(patches(k).Vertices);
        center=mean(V,1); [~,~,axes]=svd(V-center,0); axis=axes(:,1);
        axial=(V-center)*axis; transverse=V-center-axial*axis.';
        g.body(end+1,1)=i; g.a(end+1,:)=center+min(axial)*axis.';
        g.b(end+1,:)=center+max(axial)*axis.';
        g.radius(end+1,1)=max(vecnorm(transverse,2,2))+1e-6;
        g.maxRadialResidual(end+1,1)=max(vecnorm(transverse,2,2))-g.radius(end);
        g.vertexCount(end+1,1)=size(V,1);
    end
    clear guard;
end
for i=1:numel(g.body)
    for j=i+1:numel(g.body)
        x=g.body(i); y=g.body(j);
        if x==y || m.parent(x)==y || m.parent(y)==x, continue; end
        g.pairs(end+1,:)=[i j];
    end
end
g.description='Convex-mesh enclosing PCA capsules; direct parents skipped as in MATLAB.';
cached=g; cachedKey=key;
end
