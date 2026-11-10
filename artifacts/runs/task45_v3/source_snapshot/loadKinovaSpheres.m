function s=loadKinovaSpheres(m)
root=fileparts(mfilename('fullpath'));
fid=fopen(fullfile(root,'data','kinova_spheres.csv'),'r'); assert(fid>=0);
guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
d=textscan(fid,'%s%f%f%f%f','Delimiter',',','HeaderLines',1);
s.local=[d{2},d{3},d{4}]; s.radius=d{5}; s.body=zeros(numel(d{1}),1);
for k=1:numel(d{1})
    b=find(strcmp(m.bodyNames,d{1}{k})); assert(isscalar(b)); s.body(k)=b;
end
s.uniqueBodies=unique(s.body).';
end
