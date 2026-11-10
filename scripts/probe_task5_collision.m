root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'matlab'));
out=fullfile(root,'artifacts','local_runs','task5_diagnosis_20261109'); if ~exist(out,'dir'), mkdir(out); end
text=evalc('help rigidBodyTree/checkCollision'); fid=fopen(fullfile(out,'checkCollision_help.txt'),'w','n','UTF-8'); fprintf(fid,'%s',text); fclose(fid);
d=load(fullfile(root,'artifacts','runs','task45_final','formal','main','Task5','seed_5120','planning_result.mat'));
robot=loadrobot('universalUR5','DataFormat','column');
idx=find(d.result.acceptance.mesh.selfInCollision); k=idx(ceil(numel(idx)/2)); q=d.result.acceptance.theta(:,k);
[flag,sep,witness]=checkCollision(robot,q,'IgnoreSelfCollision','off','SkippedSelfCollisions','parent','Exhaustive','on');
fprintf('NUM BODIES %d; FLAG SIZE %s; SEP SIZE %s; WITNESS SIZE %s\n',robot.NumBodies,mat2str(size(flag)),mat2str(size(sep)),mat2str(size(witness)));
for j=1:robot.NumBodies
    b=robot.Bodies{j}; fprintf('%d %s parent %s collision objects %d\n',j,b.Name,b.Parent.Name,numel(b.Collisions));
end
disp(flag); disp(sep); fprintf('Q %s\n',mat2str(q.',12));
save(fullfile(out,'collision_probe.mat'),'flag','sep','witness','q','k','idx','-v7');
