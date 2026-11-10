function manifest=export_task45_v3(release,includeVideo)
% Export frozen mounted-workcell evidence, without changing any trajectory.
if nargin<2, includeVideo=true; end
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v3','matlab'),'-begin');
data=load(fullfile(release,'frozen_config.mat')); seed=data.frozen.demoSeed; pair=cell(1,2);
for task=4:5
    pair{task-3}=load(fullfile(release,'demos','workcell',sprintf('Task%d',task),sprintf('seed_%d',seed),'planning_result.mat'));
    assert(pair{task-3}.result.success);
end
out=fullfile(release,'demos','exports','workcell'); if ~exist(out,'dir'), mkdir(out); end
robot=memberC.loadRobot(); colors=[.05 .40 .75;.05 .60 .35];
manifest=struct('scene','workcell','demoSeed',seed,'framesPerVideo',150,'framesPerSecond',15,'videos',{{}},'figures',{{}});
for j=1:2
    d=pair{j}; v=d.result.acceptance;
    f=figure('Visible','off','Color','w','Position',[50 50 1280 760]);
    layout=tiledlayout(f,2,2,'Padding','loose','TileSpacing','loose');
    ax=nexttile(layout,1,[2 1]); drawScene(ax,robot,at(d.result.theta,.5),d); hold(ax,'on');
    path(ax,d.result.initial,d.poeModel,[.8 .2 .2],'--'); path(ax,d.result.theta,d.poeModel,colors(j,:),'-');
    title(ax,sprintf('Workcell / Task %d / success %d',j+3,d.result.success));
    ax=nexttile(layout,2); plot(ax,v.s,v.orientationDeg,'LineWidth',1.7); hold(ax,'on'); yline(ax,5,'r--','5 deg');
    if j==2, ylim(ax,[0 5.5]); end
    grid(ax,'on'); xlabel(ax,'Normalized path progress'); ylabel(ax,'Tool y tilt (deg)');
    ax=nexttile(layout,4); plot(ax,v.s,v.toolPosition(3,:),'LineWidth',1.7); hold(ax,'on'); yline(ax,0,'k--','Table');
    ylim(ax,[0 max(v.toolPosition(3,:))+.1]); grid(ax,'on'); xlabel(ax,'Normalized path progress'); ylabel(ax,'Tool world z (m)');
    savePlot(f,fullfile(out,sprintf('task%d_summary',j+3))); close(f);
    manifest.figures{end+1}=fullfile(out,sprintf('task%d_summary.fig',j+3));
end
first=pair{1}; collisions=find(first.result.initialMeshValidation.worldInCollision);
index=collisions(ceil(numel(collisions)/2)); progress=(index-1)/(first.result.initialMeshValidation.nStates-1);
f=figure('Visible','off','Color','w','Position',[40 40 1440 550]); layout=tiledlayout(f,1,3,'Padding','loose','TileSpacing','loose');
for j=1:3
    ax=nexttile(layout,j);
    if j==1, d=first; Q=d.result.initial; label='Colliding straight initialization'; color=[.8 .2 .2];
    else, d=pair{j-1}; Q=d.result.theta; label=sprintf('Task %d / %s',j+2,d.result.constraintMode); color=colors(j-1,:); end
    drawScene(ax,robot,at(Q,progress),d); hold(ax,'on'); path(ax,Q,d.poeModel,color,'-'); title(ax,label);
end
savePlot(f,fullfile(out,'initial_and_planned')); close(f); manifest.figures{end+1}=fullfile(out,'initial_and_planned.fig');
f=figure('Visible','off','Color','w','Position',[50 50 1150 820]); layout=tiledlayout(f,2,2,'Padding','loose','TileSpacing','loose');
labels={'Tool y tilt (deg)','Tool world z (m)','Conservative clearance (mm)','Cost / own initial objective'};
for panel=1:4
    ax=nexttile(layout,panel); hold(ax,'on');
    for j=1:2
        d=pair{j}; v=d.result.acceptance;
        if panel==1, x=v.s; y=v.orientationDeg;
        elseif panel==2, x=v.s; y=v.toolPosition(3,:);
        elseif panel==3, x=v.s; y=1000*v.voxelClearance;
        else, x=0:size(d.result.history,1); y=[d.result.initialCost;d.result.history(:,3)]/d.result.initialCost; end
        plot(ax,x,y,'Color',colors(j,:),'LineWidth',1.7);
    end
    if panel==1, yline(ax,5,'r--','5 deg');
    elseif panel==2, yline(ax,0,'k--','Table'); yl=ylim(ax); ylim(ax,[0 yl(2)]);
    elseif panel==3, yline(ax,35,'r--','35 mm'); end
    ylabel(ax,labels{panel}); grid(ax,'on');
    if panel<4, xlabel(ax,'Normalized path progress'); else, xlabel(ax,'Iteration, including restarts'); end
    legend(ax,'Task 4','Task 5','Location','best');
end
savePlot(f,fullfile(out,'paired_metrics')); close(f); manifest.figures{end+1}=fullfile(out,'paired_metrics.fig');
if includeVideo
    names={'task4_motion.avi','task5_motion.avi','paired_motion.avi'}; writers=cell(1,3);
    for j=1:3, writers{j}=VideoWriter(fullfile(out,names{j}),'Motion JPEG AVI'); writers{j}.FrameRate=15; open(writers{j}); end
    guard=onCleanup(@()closeWriters(writers)); %#ok<NASGU>
    f=figure('Color','w','Position',[30 30 1280 650],'MenuBar','none','ToolBar','none','Resize','off');
    for frame=1:150
        s=(frame-1)/149;
        for j=1:2
            ax=subplot(1,2,j); cla(ax); d=pair{j}; q=at(d.result.theta,s); drawScene(ax,robot,q,d);
            [~,T]=memberB.poeFK(d.poeModel,q);
            title(ax,sprintf('Workcell / Task %d / progress %.1f%%\nTilt %.2f deg / tool z %.3f m',j+3,100*s,memberC.directionError(T(1:3,2)),T(3,4)));
        end
        drawnow; captured=getframe(f); rgb=captured.cdata; cut=floor(size(rgb,2)/2);
        writeVideo(writers{1},rgb(:,1:cut,:)); writeVideo(writers{2},rgb(:,cut+1:end,:)); writeVideo(writers{3},rgb);
    end
    close(f); closeWriters(writers); clear guard;
    for j=1:3
        video=VideoReader(fullfile(out,names{j})); count=0;
        while hasFrame(video), readFrame(video); count=count+1; end
        assert(count==150 && video.FrameRate==15); manifest.videos{end+1}=fullfile(out,names{j});
    end
end
memberC.writeJSON(fullfile(fileparts(out),'export_manifest.json'),manifest);
end
function q=at(theta,s)
q=interp1(linspace(0,1,size(theta,2)),theta.',s,'linear').';
end
function path(ax,Q,m,color,style)
positions=zeros(3,size(Q,2));
for k=1:size(Q,2), [~,T]=memberB.poeFK(m,Q(:,k)); positions(:,k)=T(1:3,4); end
plot3(ax,positions(1,:),positions(2,:),positions(3,:),style,'Color',color,'LineWidth',1.8);
end
function drawScene(ax,robot,q,d)
show(robot,q,'Parent',ax,'PreservePlot',false,'Frames','off','Visuals','on'); hold(ax,'on');
faces=[1 2 3 4;5 6 7 8;1 2 6 5;2 3 7 6;3 4 8 7;4 1 5 8];
corners=[-1 -1 -1;1 -1 -1;1 1 -1;-1 1 -1;-1 -1 1;1 -1 1;1 1 1;-1 1 1];
for k=1:size(d.scene.boxes,1)
    box=d.scene.boxes(k,:); color=[.9 .5 .15]; opacity=.35;
    if k==1, color=[.55 .58 .62]; opacity=.16; elseif k==5, color=[.3 .5 .7]; end
    patch(ax,'Vertices',corners.*box(4:6)+box(1:3),'Faces',faces,'FaceColor',color,'FaceAlpha',opacity,'EdgeColor',color*.7);
end
[~,T]=memberB.poeFK(d.poeModel,q); p=T(1:3,4); y=.14*T(1:3,2);
quiver3(ax,p(1),p(2),p(3),y(1),y(2),y(3),0,'Color',[.05 .65 .35],'LineWidth',2);
axis(ax,'equal'); axis(ax,[-1 1 -1 1 -.03 1.6]); view(ax,135,26); grid(ax,'on');
xlabel(ax,'x (m)'); ylabel(ax,'y (m)'); zlabel(ax,'z (m)');
camlight(ax,'headlight'); lighting(ax,'gouraud'); ax.Toolbar.Visible='off'; disableDefaultInteractivity(ax);
end
function savePlot(f,base)
drawnow; exportgraphics(f,[base '.png'],'Resolution',180); savefig(f,[base '.fig']);
h=openfig([base '.fig'],'invisible'); close(h);
end
function closeWriters(writers)
for j=1:numel(writers), try, close(writers{j}); catch, end, end
end
