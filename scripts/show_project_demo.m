function info=show_project_demo(whichTask,versionId,scenarioId)
% Read-only GUI for the saved five-task project. Never replans or writes runs.
% show_project_demo; show_project_demo('task5','v2','variant');
% show_project_demo('check','v2') validates assets without opening windows.
if nargin<1, whichTask='all'; end
if nargin<2, versionId='latest'; end
root=fileparts(fileparts(mfilename('fullpath')));
if strcmp(versionId,'latest')
    if exist(fullfile(root,'artifacts','runs','task45_v3','delivery_checks.json'),'file'), versionId='v3'; else, versionId='v2'; end
end
assert(any(strcmp(versionId,{'v2','v3'})),'Choose latest, v2, or v3.');
if nargin<3
    if strcmp(versionId,'v3'), scenarioId='workcell'; else, scenarioId='main'; end
end
if strcmp(versionId,'v2'), assert(any(strcmp(scenarioId,{'main','variant'}))); else, assert(strcmp(scenarioId,'workcell')); end
assert(any(strcmp(whichTask,{'all','check','task1','task2','task3','task4','task5'})));
base=fullfile(root,'artifacts','runs','final_r2023b');
release=fullfile(root,'artifacts','runs',['task45_' versionId]);
config=jsondecode(fileread(fullfile(release,'frozen_config.json'))); seed=config.demoSeed;
titles={'Task 1: KINOVA STOMP','Task 2: UR5 built-in FK','Task 3: UR5 PoE FK', ...
    ['Task 4: multi-obstacle / ' versionId],['Task 5: upright constraint / ' versionId]};
info=repmat(struct('task',0,'title','','summaryImage','','comparisonImage','','video','','resultPath',''),1,5);
for task=1:5
    info(task).task=task; info(task).title=titles{task};
    if task<=3
        folder=fullfile(base,sprintf('Task%d',task));
        info(task).summaryImage=fullfile(folder,'planning_summary.png');
        info(task).comparisonImage=fullfile(folder,'robot_midpoint_comparison.png');
        if task==1, name='KINOVA_planned_motion.avi'; else, name='UR5_planned_motion.avi'; end
        info(task).video=fullfile(folder,name); info(task).resultPath=fullfile(folder,'planning_result.mat');
    else
        exports=fullfile(release,'demos','exports',scenarioId);
        info(task).summaryImage=fullfile(exports,sprintf('task%d_summary.png',task));
        info(task).comparisonImage=fullfile(exports,'initial_and_planned.png');
        info(task).video=fullfile(exports,sprintf('task%d_motion.avi',task));
        info(task).resultPath=fullfile(release,'demos',scenarioId,sprintf('Task%d',task),sprintf('seed_%d',seed),'planning_result.mat');
    end
    for name={'summaryImage','comparisonImage','video','resultPath'}
        assert(exist(info(task).(name{1}),'file')==2,'Demo artifact missing: %s. Use v2 until V3 finishes.',info(task).(name{1}));
    end
end
if strcmp(whichTask,'check')
    for task=1:5
        metadata=imfinfo(info(task).summaryImage); reader=VideoReader(info(task).video);
        assert(metadata.Width>100 && reader.FrameRate>0);
    end
    fprintf('All five saved demo tasks are available. Task 4/5: %s / %s / seed %d.\n',versionId,scenarioId,seed);
    return;
end
tasks=1:5; if ~strcmp(whichTask,'all'), tasks=str2double(whichTask(end)); end
f=figure('Name',['EE5112 Project 2 - saved results - ' versionId],'NumberTitle','off', ...
    'Color','w','Position',[80 70 1200 790],'MenuBar','figure','ToolBar','none');
tabs=uitabgroup('Parent',f,'Units','normalized','Position',[0 0 1 1]);
for task=tasks
    item=info(task); tab=uitab(tabs,'Title',sprintf('Task %d',task));
    ax=axes('Parent',tab,'Units','normalized','Position',[.025 .16 .95 .77]);
    image(ax,imread(item.summaryImage)); axis(ax,'image'); axis(ax,'off');
    uicontrol(tab,'Style','text','Units','normalized','Position',[.025 .935 .95 .045], ...
        'String',item.title,'FontSize',15,'FontWeight','bold','BackgroundColor','w','HorizontalAlignment','left');
    uicontrol(tab,'Style','pushbutton','Units','normalized','Position',[.025 .075 .17 .055], ...
        'String','Play motion','FontSize',11,'Callback',@(src,event)implay(item.video));
    uicontrol(tab,'Style','pushbutton','Units','normalized','Position',[.215 .075 .20 .055], ...
        'String','Initial vs planned','FontSize',11,'Callback',@(src,event)openImage(item.comparisonImage,item.title));
    uicontrol(tab,'Style','pushbutton','Units','normalized','Position',[.435 .075 .20 .055], ...
        'String','Print saved metrics','FontSize',11,'Callback',@(src,event)printMetrics(item));
    if task==3
        uicontrol(tab,'Style','pushbutton','Units','normalized','Position',[.655 .075 .29 .055], ...
            'String','PoE screws / accuracy / timing','FontSize',11,'Callback',@(src,event)printPoe(base));
    elseif task>=4
        pairVideo=fullfile(fileparts(item.video),'paired_motion.avi');
        uicontrol(tab,'Style','pushbutton','Units','normalized','Position',[.655 .075 .29 .055], ...
            'String','Play Task 4 vs Task 5','FontSize',11,'Callback',@(src,event)implay(pairVideo));
    end
    uicontrol(tab,'Style','text','Units','normalized','Position',[.025 .015 .95 .04], ...
        'String','Saved trajectories. Animation shows normalized path progress, not physical execution time.', ...
        'FontSize',10,'BackgroundColor','w','HorizontalAlignment','left');
end
fprintf('Opened saved project demo (%s, %s). Select a task tab and click Play motion.\n',versionId,scenarioId);
end
function openImage(path,label)
f=figure('Name',label,'NumberTitle','off','Color','w','Position',[90 90 1200 650]);
ax=axes('Parent',f); image(ax,imread(path)); axis(ax,'image'); axis(ax,'off');
end
function printMetrics(item)
d=load(item.resultPath,'result'); r=d.result;
fprintf('\n%s\nSuccess: %d\n',item.title,r.success);
if isfield(r,'acceptance')
    a=r.acceptance;
    fprintf('Conservative gap %.2f mm; max tool-y tilt %.3f deg; dense states %d\n',1000*a.minVoxelClearance,a.maxOrientationDeg,a.nStates);
    if isfield(a,'minToolHeight'), fprintf('Minimum tool world z %.3f m\n',a.minToolHeight); end
else
    fprintf('Mesh gap %.2f mm; world free %d; self free %d\n',1000*r.meshValidation.minWorldSeparation,r.meshValidation.worldCollisionFree,r.meshValidation.selfCollisionFree);
    if r.task==1, fprintf('Task 1 preserves the original endpoint; it does not satisfy a 1 cm hard margin.\n'); end
end
end
function printPoe(base)
folder=fullfile(base,'Task3');
fprintf('\nSpace screws in world frame, ordered [omega; v]:\n'); disp(readtable(fullfile(folder,'space_screws.csv')));
fprintf('Zero-configuration tool transform M:\n'); disp(readmatrix(fullfile(folder,'M_end_effector.csv')));
a=readtable(fullfile(folder,'fk_accuracy.csv')); fprintf('200-configuration accuracy maxima:\n'); disp(max(a{:,2:3},[],1));
fprintf('Saved benchmark on the original machine, not a universal speed guarantee:\n'); disp(readtable(fullfile(folder,'fk_benchmark.csv')));
end
