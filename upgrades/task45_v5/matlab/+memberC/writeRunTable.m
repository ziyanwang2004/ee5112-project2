function writeRunTable(path,rows)
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0); guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'scenario,task,seed,mode,success,planner_seconds,total_seconds,iterations,restarts,min_voxel_m,min_mesh_m,max_tilt_deg,mean_tilt_deg,joint_length_rad,tool_length_m,smoothness,weight,noise_std,failures\n');
for k=1:numel(rows)
    r=rows(k);
    fprintf(fid,'%s,%d,%d,%s,%d,%.12g,%.12g,%d,%d,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%s\n', ...
        r.scenario,r.task,r.seed,r.mode,r.success,r.plannerSeconds,r.totalSeconds,r.iterations,r.restarts, ...
        r.minVoxelClearance,r.minMeshClearance,r.maxOrientationDeg,r.meanOrientationDeg, ...
        r.jointPathLength,r.toolPathLength,r.smoothness,r.orientationWeight,r.noiseStd,strjoin(r.failures,';'));
end
end
