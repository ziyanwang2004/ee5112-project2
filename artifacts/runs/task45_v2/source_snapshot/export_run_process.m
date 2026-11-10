function export_run_process(runRoot)
% Render any saved Tasks 1/2/3 and audit the actual shared PoE cost call chain.
root=fileparts(mfilename('fullpath')); addpath(root); addpath(fullfile(root,'tests'));
for task={'Task1','Task2','Task3'}
    folder=fullfile(runRoot,task{1});
    if ~exist(fullfile(folder,'planning_result.mat'),'file'), continue; end
    d=load(fullfile(folder,'planning_result.mat'));
    robot=loadrobot(d.plannerOptions.robotName,'DataFormat','column');
    replay_saved_process(folder);
    memberB.plotComparison(robot,d.scene,d.result,folder);
    memberB.plotResults(robot,d.poeModel,d.geometry,d.scene,d.result,d.plannerOptions,folder);
    plotProcessExtras(d,folder);
    close all;
    if strcmp(task{1},'Task1'), videoName='KINOVA_planned_motion.avi';
    else, videoName='UR5_planned_motion.avi'; end
    vr=VideoReader(fullfile(folder,videoName));
    n=0; while hasFrame(vr), readFrame(vr); n=n+1; end
    assert(n==size(d.result.theta,2),'Video frame count differs from waypoints.');
    fprintf('%s: verified video, %d frames, %d x %d pixels.\n',task{1},n,vr.Width,vr.Height);
end
if ~exist(fullfile(runRoot,'Task3','planning_result.mat'),'file'), return; end
% Profile ONLY the PoE cost, after all MATLAB-based setup, plotting and
% independent collision validation, so getTransform usage cannot be hidden.
d=load(fullfile(runRoot,'Task3','planning_result.mat'));
robot=loadrobot(d.plannerOptions.robotName,'DataFormat','column');
w=d.voxelStored; w.interpolant=griddedInterpolant(w.axes,w.sEDT,'linear','nearest');
context.options=d.plannerOptions; context.geometry=d.geometry;
context.kinematics=struct('mode','poe','robot',robot,'model',d.poeModel);
profile clear; profile on;
[~,cost]=stompTrajCost(robot,d.result.theta,d.R,w,context);
profile off; profileData=profile('info');
names={profileData.FunctionTable.FunctionName};
assert(~any(contains(names,'getTransform')),'PoE trajectory cost called getTransform.');
assert(any(contains(names,'poeFK')) && any(contains(names,'stompObstacleCost')));
save(fullfile(runRoot,'Task3','poe_cost_profile.mat'),'profileData','cost','-v7');
fid=fopen(fullfile(runRoot,'Task3','poe_cost_call_chain.txt'),'w');
fprintf(fid,'PoE trajectory cost profile: getTransform absent; poeFK and stompObstacleCost present.\n');
for k=1:numel(names), fprintf(fid,'%s\n',names{k}); end
fclose(fid);
fprintf('PoE cost profile passed: no getTransform calls.\n');
end

function plotProcessExtras(d,folder)
first=load(fullfile(folder,'iterations','restart_01_iteration_001.mat'));
f=figure('Color','w','Position',[80 80 1180 730]);
for j=1:size(d.result.theta,1)
    ax=subplot(ceil(size(d.result.theta,1)/2),2,j); hold(ax,'on');
    for k=1:numel(first.theta_samples)
        plot(ax,linspace(0,1,size(d.result.theta,2)),first.theta_samples{k}(j,:),'Color',[.75 .8 .85]);
    end
    plot(ax,linspace(0,1,size(d.result.theta,2)),first.thetaBefore(j,:),'r--','LineWidth',1.4);
    plot(ax,linspace(0,1,size(d.result.theta,2)),first.thetaAfter(j,:),'b-','LineWidth',1.4);
    title(ax,sprintf('Iteration 1, joint q%d',j)); xlabel(ax,'Path parameter'); ylabel(ax,'rad'); grid(ax,'on');
end
exportgraphics(f,fullfile(folder,'iteration_001_rollouts.png'),'Resolution',160);
savefig(f,fullfile(folder,'iteration_001_rollouts.fig'));
f=figure('Color','w','Position',[100 100 1100 420]);
subplot(1,2,1); imagesc(first.Stheta); colorbar;
xlabel('Waypoint'); ylabel('Rollout'); title('Iteration 1: local rollout cost');
subplot(1,2,2); imagesc(first.trajProb); colorbar;
xlabel('Waypoint'); ylabel('Rollout'); title('Iteration 1: normalized rollout probability');
exportgraphics(f,fullfile(folder,'iteration_001_cost_probability.png'),'Resolution',160);
savefig(f,fullfile(folder,'iteration_001_cost_probability.fig'));
f=figure('Color','w','Position',[100 100 950 450]);
plot(linspace(0,1,d.result.validation.nStates),d.result.validation.clearance,'b-','LineWidth',1.5); hold on;
plot(linspace(0,1,d.result.voxelValidation.nStates),d.result.voxelValidation.clearance,'Color',[.85 .4 .1],'LineWidth',1.5);
yline(d.plannerOptions.margin,'k:'); yline(0,'r--'); grid on;
plot(linspace(0,1,d.result.meshValidation.nStates),d.result.meshValidation.worldSeparation,'g-','LineWidth',1.5);
xlabel('Path parameter'); ylabel('Surface clearance (m)');
legend('Sphere / analytic box proxy','Conservative voxel proxy','Proxy target margin','Zero clearance', ...
    'Actual MATLAB mesh separation','Location','best');
if isfield(d.plannerOptions,'acceptanceMode') && strcmp(d.plannerOptions.acceptanceMode,'mesh')
    title('Task 1: mesh gate; proxy overlap near fixed goal is conservative');
else
    title('Tasks 2/3: hard proxy margin plus independent mesh validation');
end
exportgraphics(f,fullfile(folder,'voxel_vs_exact_clearance.png'),'Resolution',160);
savefig(f,fullfile(folder,'voxel_vs_exact_clearance.fig'));
end
