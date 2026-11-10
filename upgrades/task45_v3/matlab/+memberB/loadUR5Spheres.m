function s = loadUR5Spheres(m)
% Numeric envelopes fitted to upstream UR5 collision meshes; see provenance.
root=fileparts(fileparts(mfilename('fullpath')));
fid=fopen(fullfile(root,'data','ur5_spheres.csv'),'r');
assert(fid>=0,'Sphere data missing.'); guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
d=textscan(fid,'%s%f%f%f%f','Delimiter',',','HeaderLines',1);
s.local=[d{2},d{3},d{4}]; s.radius=d{5};
s.body=zeros(numel(d{1}),1);
for j=1:numel(d{1})
    k=find(strcmp(m.bodyNames,d{1}{j}));
    % MATLAB's base is not part of Bodies. A stationary base is away from
    % this scene's obstacle and can be omitted from the optimization proxy.
    if isempty(k) && strcmp(d{1}{j},m.baseName), continue; end
    assert(isscalar(k),'UR5 body name mismatch: %s',d{1}{j});
    s.body(j)=k;
end
keep=s.body~=0; s.local=s.local(keep,:); s.radius=s.radius(keep); s.body=s.body(keep);
s.uniqueBodies=unique(s.body).';
end
