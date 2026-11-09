function summary=verify_task123(runRoot)
% Audit the saved final runs, including Task 1's unchanged original targets.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); addpath(fullfile(root,'tests'));
assert(strcmp(version('-release'),'2023b'),'Use MATLAB R2023b.');
summary.numeric=run_numeric_tests(); test_shared_helpers();
summary.matlabVersion=version; summary.release=version('-release');
for n=1:3
    name=sprintf('Task%d',n); folder=fullfile(runRoot,name);
    d=load(fullfile(folder,'planning_result.mat')); r=d.result;
    assert(r.success && r.meshValidation.worldCollisionFree && r.meshValidation.selfCollisionFree);
    assert(isequal(r.theta(:,1),d.scene.qStart) && isequal(r.theta(:,end),d.scene.qGoal));
    assert(all(all(r.theta>=d.poeModel.limits(:,1)-1e-12 & r.theta<=d.poeModel.limits(:,2)+1e-12)));
    delta=diff(r.meshValidation.theta,1,2);
    assert(max(abs(delta(:)))<=d.plannerOptions.denseJointStep+1e-12);
    replay=replay_saved_process(folder);
    s=struct('worldCollisionFree',true,'selfCollisionFree',true, ...
        'initialCollidingStates',nnz(r.initialMeshValidation.worldInCollision), ...
        'initialStates',r.initialMeshValidation.nStates,'denseStates',r.meshValidation.nStates, ...
        'minMeshSeparation',r.meshValidation.minWorldSeparation, ...
        'minSphereClearance',r.validation.minClearance,'minVoxelClearance',r.voxelValidation.minClearance, ...
        'initialCost',r.initialCost,'finalCost',r.cost,'iterations',size(r.history,1), ...
        'plannerSeconds',r.elapsedSeconds,'replay',replay);
    if n==1
        expectedStart=trvec2tform([.4 0 .2])*axang2tform([0 1 0 pi]);
        expectedGoal=trvec2tform([.35 .55 .35])*axang2tform([0 1 0 pi]);
        assert(isequal(d.taskInit,expectedStart) && isequal(d.taskFinal,expectedGoal));
        assert(isequal(d.scene.boxes,[.4 .46 .26 .08 .08 .08]));
        robot=loadrobot('kinovaGen3','DataFormat','column');
        s.startPoseMatrixError=norm(getTransform(robot,r.theta(:,1),'EndEffector_Link')-expectedStart,'fro');
        s.goalPoseMatrixError=norm(getTransform(robot,r.theta(:,end),'EndEffector_Link')-expectedGoal,'fro');
        assert(s.startPoseMatrixError<1e-6 && s.goalPoseMatrixError<1e-6);
        assert(strcmp(d.plannerOptions.acceptanceMode,'mesh'));
        assert(all(all(r.theta>=d.physicalJointLimits(:,1)-1e-12 & r.theta<=d.physicalJointLimits(:,2)+1e-12)));
        s.proxyMarginSatisfied=r.proxyMarginSatisfied;
    else
        assert(r.proxyMarginSatisfied && r.voxelValidation.minClearance>=d.plannerOptions.margin-1e-4);
    end
    summary.(name)=s;
end
b=load(fullfile(runRoot,'Task2','planning_result.mat'));
p=load(fullfile(runRoot,'Task3','planning_result.mat'));
summary.task23MaxTrajectoryDifference=max(abs(b.result.theta(:)-p.result.theta(:)));
assert(summary.task23MaxTrajectoryDifference<1e-10);
summary.fkValidation=p.result.fkValidation;
save(fullfile(runRoot,'verification_summary.mat'),'summary','-v7');
fid=fopen(fullfile(runRoot,'verification_summary.json'),'w'); assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(summary,'PrettyPrint',true)); fclose(fid);
disp(summary); fprintf('Task 1/2/3 verification passed.\n');
end
