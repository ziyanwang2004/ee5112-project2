function plotResults(robot,m,s,scene,r,c,folder)
% Plot path overlays using PoE-generated sphere centers, mesh-rendered poses.
f=figure('Color','w','Position',[80 80 1280 650]);
ax=subplot(1,2,1); hold(ax,'on');
drawBoxes(ax,scene.boxes);
drawPath(ax,r.initial,m,[.85 .25 .20],'--');
drawPath(ax,r.theta,m,[.05 .45 .75],'-');
for k=unique(round(linspace(1,size(r.theta,2),6)))
    [T,~]=memberB.poeFK(m,r.theta(:,k));
    C=memberB.sphereCenters(s,T);
    scatter3(ax,C(:,1),C(:,2),C(:,3),9,[.2 .5 .7],'filled', ...
        'MarkerFaceAlpha',.20,'HandleVisibility','off');
end
axis(ax,'equal'); grid(ax,'on'); view(ax,140,25);
xlabel(ax,'x (m)'); ylabel(ax,'y (m)'); zlabel(ax,'z (m)');
title(ax,[c.robotName ': red initial tool path / blue planned tool path'],'Interpreter','none');
ax2=subplot(2,2,2);
semilogy(ax2,0:size(r.history,1),max([r.initialCost;r.history(:,3)],eps),'LineWidth',1.6); grid(ax2,'on');
xlabel(ax2,'Iteration (including restarts)'); ylabel(ax2,'Trajectory cost');
ax3=subplot(2,2,4);
plot(ax3,linspace(0,1,r.meshValidation.nStates),r.meshValidation.worldSeparation,'LineWidth',1.6);
hold(ax3,'on'); yline(ax3,0,'r--'); grid(ax3,'on');
xlabel(ax3,'Normalized path parameter'); ylabel(ax3,'MATLAB mesh separation (m)');
title(ax3,'Independent dense mesh validation');
exportgraphics(f,fullfile(folder,'planning_summary.png'),'Resolution',180);
savefig(f,fullfile(folder,'planning_summary.fig'));
if isfield(c,'renderMotion') && ~c.renderMotion, return; end
f2=figure('Color','w','Position',[100 100 950 650], ...
    'MenuBar','none','ToolBar','none','Resize','off', ...
    'PaperUnits','inches','PaperPosition',[0 0 9.5 6.5], ...
    'PaperPositionMode','manual');
ax=axes(f2);
if c.writeVideo
    if strcmp(c.robotName,'kinovaGen3'), videoName='KINOVA_planned_motion.avi';
    else, videoName='UR5_planned_motion.avi'; end
    video=VideoWriter(fullfile(folder,videoName),'Motion JPEG AVI');
    video.FrameRate=12; open(video);
    guard=onCleanup(@()close(video)); %#ok<NASGU>
end
movieQ=r.theta; % render planned waypoints; dense states are for validation
frameSize=[];
for k=1:size(movieQ,2)
    cla(ax);
    show(robot,movieQ(:,k),'Parent',ax,'PreservePlot',false, ...
        'Frames','off','Visuals','on');
    hold(ax,'on'); drawBoxes(ax,scene.boxes);
    axis(ax,'equal'); axis(ax,[-1 1 -1 1 -.25 1.3]); view(ax,140,25);
    title(ax,sprintf('%s: waypoint %d / %d',c.robotName,k,size(movieQ,2)),'Interpreter','none');
    ax.Toolbar.Visible='off'; disableDefaultInteractivity(ax);
    drawnow;
    if c.writeVideo
        % Normalize captured frame sizes if the window manager/HiDPI changes
        % the figure pixel size. Index resampling needs no image toolbox.
        frame=getframe(f2); rgb=frame.cdata;
        if isempty(frameSize), frameSize=[size(rgb,1),size(rgb,2)]; end
        if size(rgb,1)~=frameSize(1) || size(rgb,2)~=frameSize(2)
            ri=round(linspace(1,size(rgb,1),frameSize(1)));
            ci=round(linspace(1,size(rgb,2),frameSize(2)));
            rgb=rgb(ri,ci,:);
        end
        writeVideo(video,rgb);
    end
    hold(ax,'off');
end
exportgraphics(f2,fullfile(folder,'robot_final_pose.png'),'Resolution',180);
end

function drawPath(ax,Q,m,color,style)
P=zeros(3,size(Q,2));
for k=1:size(Q,2)
    [~,T]=memberB.poeFK(m,Q(:,k)); P(:,k)=T(1:3,4);
end
plot3(ax,P(1,:),P(2,:),P(3,:),style,'Color',color,'LineWidth',2);
end

function drawBoxes(ax,boxes)
faces=[1 2 3 4;5 6 7 8;1 2 6 5;2 3 7 6;3 4 8 7;4 1 5 8];
V=[-1 -1 -1;1 -1 -1;1 1 -1;-1 1 -1;-1 -1 1;1 -1 1;1 1 1;-1 1 1];
for k=1:size(boxes,1)
    patch(ax,'Vertices',V.*boxes(k,4:6)+boxes(k,1:3),'Faces',faces, ...
        'FaceColor',[.9 .5 .15],'FaceAlpha',.5,'EdgeColor',[.6 .3 .1]);
end
end
