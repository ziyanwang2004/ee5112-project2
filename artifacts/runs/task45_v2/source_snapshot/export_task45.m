function manifest=export_task45(runRoot,writeVideo)
% Export saved evidence only; never replans or modifies saved trajectories.
if nargin<2, writeVideo=true; end
root=fileparts(mfilename('fullpath')); addpath(root);
files=dir(fullfile(runRoot,'**','planning_result.mat'));
assert(~isempty(files),'No saved runs to export.');
out=fullfile(runRoot,'exports'); if ~exist(out,'dir'), mkdir(out); end
manifest=struct('sourceRoot',runRoot,'videos',{{}},'figures',{{}}, ...
    'framesPerVideo',150,'framesPerSecond',15,'interpolation','piecewise linear in joint space');
robot=loadrobot('universalUR5','DataFormat','column');
for id={'main','variant'}
    selected=cell(1,2);
    for k=1:numel(files)
        d=load(fullfile(files(k).folder,files(k).name));
        if strcmp(d.result.scenarioId,id{1})
            j=d.result.task-3;
            if ~isempty(selected{j}), error('Export a single paired demonstration per scene.'); end
            selected{j}=d;
        end
    end
    if all(cellfun(@isempty,selected)), continue; end
    folder=fullfile(out,id{1}); if ~exist(folder,'dir'), mkdir(folder); end
    for j=1:2
        if isempty(selected{j}), continue; end
        d=selected{j}; v=d.result.acceptance;
        f=figure('Color','w','Position',[80 80 1100 650]);
        ax=subplot(2,2,[1 3]); drawScene(ax,robot,d.result.theta(:,round(end/2)),d);
        hold(ax,'on'); drawPath(ax,d.result.initial,d.poeModel,[.8 .2 .2],'--');
        drawPath(ax,d.result.theta,d.poeModel,[.05 .4 .75],'-');
        title(ax,sprintf('%s / Task %d / success %d',id{1},j+3,d.result.success));
        ax=subplot(2,2,2); plot(ax,v.s,v.orientationDeg,'LineWidth',1.8); hold(ax,'on');
        yline(ax,5,'r--','5 deg'); grid(ax,'on'); xlabel(ax,'Normalized path parameter'); ylabel(ax,'Tool y tilt (deg)');
        ax=subplot(2,2,4); plot(ax,v.s,1000*v.voxelClearance,'LineWidth',1.8); hold(ax,'on');
        plot(ax,v.s,1000*v.mesh.worldSeparation,'LineWidth',1.3); yline(ax,35,'r--','35 mm proxy gate');
        xlabel(ax,'Normalized path parameter'); ylabel(ax,'Clearance (mm)'); grid(ax,'on');
        legend(ax,'Conservative voxel / spheres','Robot collision geometry','Location','best');
        saveFigure(f,fullfile(folder,sprintf('task%d_summary',j+3))); close(f);
        manifest.figures{end+1}=fullfile(folder,sprintf('task%d_summary.fig',j+3));
    end
    if any(cellfun(@isempty,selected)), continue; end
    a=selected{1}; b=selected{2}; colors=[.05 .4 .75;.05 .6 .35];
    f=figure('Color','w','Position',[80 80 1350 450]);
    for j=1:3
        ax=subplot(1,3,j);
        if j==1, d=a; Q=a.result.initial; label='Colliding linear initialization';
        else, d=selected{j-1}; Q=d.result.theta; label=sprintf('Task %d: %s',j+2,d.result.constraintMode); end
        drawScene(ax,robot,Q(:,round(size(Q,2)/2)),d); hold(ax,'on');
        drawPath(ax,Q,d.poeModel,[.1 .4 .7],'-'); title(ax,label);
    end
    saveFigure(f,fullfile(folder,'initial_and_planned')); close(f);
    f=figure('Color','w','Position',[80 80 1150 850]);
    ax=subplot(2,2,1); hold(ax,'on'); drawBoxes(ax,a.scene.boxes);
    drawPath(ax,a.result.initial,a.poeModel,[.8 .2 .2],'--');
    drawPath(ax,a.result.theta,a.poeModel,colors(1,:),'-'); drawPath(ax,b.result.theta,b.poeModel,colors(2,:),'-');
    for j=1:2
        d=selected{j}; Q=atProgress(d.result.theta,linspace(0,1,9));
        for k=1:size(Q,2)
            [~,T]=memberB.poeFK(d.poeModel,Q(:,k)); p=T(1:3,4); y=.09*T(1:3,2);
            quiver3(ax,p(1),p(2),p(3),y(1),y(2),y(3),0,'Color',colors(j,:),'HandleVisibility','off');
        end
    end
    axis(ax,'equal'); grid(ax,'on'); view(ax,140,25); xlabel(ax,'x (m)'); ylabel(ax,'y (m)'); zlabel(ax,'z (m)');
    title(ax,'Tool paths and local y axes');
    ax=subplot(2,2,2); hold(ax,'on');
    for j=1:2, v=selected{j}.result.acceptance; plot(ax,v.s,v.orientationDeg,'Color',colors(j,:),'LineWidth',1.8); end
    yline(ax,5,'r--'); grid(ax,'on'); xlabel(ax,'Normalized path parameter'); ylabel(ax,'Tool y tilt (deg)'); legend(ax,'Task 4','Task 5','5 deg');
    ax=subplot(2,2,3); hold(ax,'on');
    for j=1:2, v=selected{j}.result.acceptance; plot(ax,v.s,1000*v.voxelClearance,'Color',colors(j,:),'LineWidth',1.8); end
    yline(ax,35,'r--'); grid(ax,'on'); xlabel(ax,'Normalized path parameter'); ylabel(ax,'Conservative clearance (mm)');
    ax=subplot(2,2,4); hold(ax,'on');
    for j=1:2, r=selected{j}.result; plot(ax,0:size(r.history,1),[r.initialCost;r.history(:,3)]/r.initialCost,'Color',colors(j,:),'LineWidth',1.8); end
    grid(ax,'on'); xlabel(ax,'Iteration, including restarts'); ylabel(ax,'Cost / own initial cost'); title(ax,'Different objectives; normalized within each run');
    saveFigure(f,fullfile(folder,'paired_comparison')); close(f);
    manifest.figures{end+1}=fullfile(folder,'paired_comparison.fig');
    if writeVideo
        paths=renderVideos(robot,selected,folder,id{1}); manifest.videos=[manifest.videos paths];
    end
end
memberC.writeJSON(fullfile(out,'export_manifest.json'),manifest);
end

function paths=renderVideos(robot,pair,folder,id)
paths=cell(1,3); writers=cell(1,3);
names={'task4_motion.avi','task5_motion.avi','paired_motion.avi'};
for j=1:3
    paths{j}=fullfile(folder,names{j}); writers{j}=VideoWriter(paths{j},'Motion JPEG AVI');
    writers{j}.FrameRate=15; open(writers{j});
end
guard=onCleanup(@()closeWriters(writers)); %#ok<NASGU>
f=figure('Color','w','Position',[50 50 1280 600],'MenuBar','none','ToolBar','none','Resize','off');
Q={atProgress(pair{1}.result.theta,linspace(0,1,150)),atProgress(pair{2}.result.theta,linspace(0,1,150))};
frameSize=[];
for k=1:150
    for j=1:2
        ax=subplot(1,2,j); cla(ax); drawScene(ax,robot,Q{j}(:,k),pair{j});
        [~,T]=memberB.poeFK(pair{j}.poeModel,Q{j}(:,k)); angle=memberC.directionError(T(1:3,2));
        title(ax,sprintf('%s / Task %d / progress %.1f%%\nTool y tilt %.2f deg',id,j+3,100*(k-1)/149,angle));
    end
    drawnow; frame=getframe(f); rgb=frame.cdata;
    if isempty(frameSize), frameSize=[size(rgb,1),size(rgb,2)]; end
    if any([size(rgb,1),size(rgb,2)]~=frameSize)
        rgb=rgb(round(linspace(1,size(rgb,1),frameSize(1))),round(linspace(1,size(rgb,2),frameSize(2))),:);
    end
    cut=floor(size(rgb,2)/2); writeVideo(writers{1},rgb(:,1:cut,:));
    writeVideo(writers{2},rgb(:,cut+1:end,:)); writeVideo(writers{3},rgb);
end
close(f); closeWriters(writers); clear guard;
for j=1:3
    reader=VideoReader(paths{j}); count=0;
    while hasFrame(reader), readFrame(reader); count=count+1; end
    assert(count==150 && reader.FrameRate==15,'Video decode validation failed.');
end
end
function closeWriters(writers)
for j=1:numel(writers), try, close(writers{j}); catch, end, end
end
function Q=atProgress(theta,s)
Q=interp1(linspace(0,1,size(theta,2)),theta.',s,'linear').';
end
function saveFigure(f,path)
exportgraphics(f,[path '.png'],'Resolution',180); savefig(f,[path '.fig']);
% Confirm the editable artifact reopens.
h=openfig([path '.fig'],'invisible'); close(h);
end
function drawScene(ax,robot,q,d)
show(robot,q,'Parent',ax,'PreservePlot',false,'Frames','off','Visuals','on'); hold(ax,'on');
drawBoxes(ax,d.scene.boxes); [~,T]=memberB.poeFK(d.poeModel,q); p=T(1:3,4); y=.16*T(1:3,2);
quiver3(ax,p(1),p(2),p(3),y(1),y(2),y(3),0,'Color',[.05 .6 .35],'LineWidth',2);
axis(ax,'equal'); axis(ax,[-.4 1 -.85 .85 -.25 1]); view(ax,140,25); grid(ax,'on');
xlabel(ax,'x (m)'); ylabel(ax,'y (m)'); zlabel(ax,'z (m)');
ax.Toolbar.Visible='off'; disableDefaultInteractivity(ax);
end
function drawPath(ax,Q,m,color,style)
P=zeros(3,size(Q,2));
for k=1:size(Q,2), [~,T]=memberB.poeFK(m,Q(:,k)); P(:,k)=T(1:3,4); end
plot3(ax,P(1,:),P(2,:),P(3,:),style,'Color',color,'LineWidth',2);
end
function drawBoxes(ax,boxes)
faces=[1 2 3 4;5 6 7 8;1 2 6 5;2 3 7 6;3 4 8 7;4 1 5 8];
V=[-1 -1 -1;1 -1 -1;1 1 -1;-1 1 -1;-1 -1 1;1 -1 1;1 1 1;-1 1 1];
for k=1:size(boxes,1)
    patch(ax,'Vertices',V.*boxes(k,4:6)+boxes(k,1:3),'Faces',faces,'FaceColor',[.9 .5 .15], ...
        'FaceAlpha',.45,'EdgeColor',[.6 .3 .1],'HandleVisibility','off');
end
end
