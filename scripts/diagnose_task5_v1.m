root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'matlab'));
out=fullfile(root,'artifacts','local_runs','task5_diagnosis_20261109'); if ~exist(out,'dir'), mkdir(out); end
robot=loadrobot('universalUR5','DataFormat','column'); records=cell(1,20); n=0;
for scenario={'main','variant'}
    for seed=5120:5129
        d=load(fullfile(root,'artifacts','runs','task45_final','formal',scenario{1},'Task5',sprintf('seed_%d',seed),'planning_result.mat'));
        a=d.result.acceptance; ids=find(a.mesh.selfInCollision); chosen=unique(ids(round(linspace(1,numel(ids),min(3,numel(ids))))));
        pairs={};
        for k=chosen
            [~,sep]=checkCollision(robot,a.theta(:,k),'IgnoreSelfCollision','off','SkippedSelfCollisions','parent','Exhaustive','on');
            [ii,jj]=find(triu(isnan(sep),1));
            for p=1:numel(ii), pairs{end+1}=[robot.Bodies{ii(p)}.Name,' / ',robot.Bodies{jj(p)}.Name]; end %#ok<SAGROW>
        end
        n=n+1; records{n}=struct('scenario',scenario{1},'seed',seed,'denseStates',a.nStates, ...
            'selfCollisionStates',numel(ids),'representativeStates',chosen,'pairs',{unique(pairs)}, ...
            'voxelGap',a.minVoxelClearance,'maxTilt',a.maxOrientationDeg,'failures',{a.failures}); %#ok<SAGROW>
    end
end
memberC.writeJSON(fullfile(out,'v1_collision_diagnosis.json'),[records{:}]);
fprintf('DIAGNOSIS COMPLETE %d runs\n',n);
