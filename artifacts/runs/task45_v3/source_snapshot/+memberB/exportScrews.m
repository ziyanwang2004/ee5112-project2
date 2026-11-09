function exportScrews(m,folder)
if ~exist(folder,'dir'), mkdir(folder); end
memberB.writeCSV(fullfile(folder,'space_screws.csv'), ...
    'joint,wx,wy,wz,vx,vy,vz,axis_point_x,axis_point_y,axis_point_z', ...
    [(1:m.nJoints).',m.S.',reshape(m.Mjoint(1:3,4,:),3,[]).']);
memberB.writeCSV(fullfile(folder,'M_end_effector.csv'),'c1,c2,c3,c4',m.M(:,:,m.eeIndex));
save(fullfile(folder,'poe_model.mat'),'m','-v7');
fid=fopen(fullfile(folder,'joint_mapping.txt'),'w');
guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'Space/base frame: %s\nEnd-effector: %s\nTwist order: [omega; v]\n', ...
    m.baseName,m.endEffector);
for j=1:m.nJoints
    fprintf(fid,'%d: %s -> %s\n',j,m.jointNames{j},m.bodyNames{m.movingBody(j)});
end
end
