function buildKinovaSpheres(filename)
% Regenerate numeric envelopes using R2023b public collision visualization.
% A copied one-body tree puts each mesh in its own body frame. Public patch
% Vertices include collision-local transforms; no private robot API is used.
robot=loadrobot('kinovaGen3','DataFormat','column');
fid=fopen(filename,'w'); assert(fid>=0); guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'body,x_m,y_m,z_m,radius_m\n');
for i=1:robot.NumBodies
    body=copy(robot.Bodies{i});
    if isempty(body.Collisions), continue; end
    body.Joint=rigidBodyJoint(['fixed_envelope_' num2str(i)],'fixed');
    tree=rigidBodyTree('DataFormat','column'); addBody(tree,body,tree.BaseName);
    f=figure('Visible','off');
    ax=show(tree,'Visuals','off','Collisions','on','Frames','off');
    patches=findobj(ax,'Type','Patch','DisplayName',[body.Name '_coll_mesh']);
    assert(~isempty(patches),'Collision mesh was not found for %s.',body.Name);
    for k=1:numel(patches)
        V=double(patches(k).Vertices);
        [C,R]=memberB.fitSphereEnvelope(V,.015,0);
        for n=1:size(C,1)
            fprintf(fid,'%s,%.16g,%.16g,%.16g,%.16g\n',body.Name,C(n,:),R(n));
        end
    end
    close(f);
end
end
