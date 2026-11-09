function plot_task45_v2_evidence(release,rows)
root=fileparts(fileparts(mfilename('fullpath'))); out=fullfile(release,'diagnosis'); if ~exist(out,'dir'), mkdir(out); end
robot=loadrobot('universalUR5','DataFormat','column'); old=load(fullfile(release,'diagnosis','raw_probe_evidence','collision_probe.mat'));
data=load(fullfile(release,'frozen_config.mat')); seed=data.frozen.demoSeed;
new=load(fullfile(release,'demos','main','Task5',sprintf('seed_%d',seed),'planning_result.mat'));
q={old.q,new.result.theta(:,ceil(size(new.result.theta,2)/2))};
f=figure('Visible','off','Color','w','Position',[50 50 1200 620]);
for i=1:2
    ax=axes('Parent',f,'Position',[.07+(i-1)*.49 .16 .39 .63]);
    show(robot,q{i},'Parent',ax,'Visuals','off','Collisions','on','Frames','off');
    view(ax,135,23); axis(ax,'equal'); axis(ax,[-.4 1 -.85 .6 -.35 1]); grid(ax,'on');
    ax.FontSize=9; ax.Position=[.07+(i-1)*.49 .16 .39 .63];
    xlabel(ax,'x (m)'); ylabel(ax,'y (m)'); zlabel(ax,'z (m)');
    [hit,sep]=checkCollision(robot,q{i},'IgnoreSelfCollision','off','SkippedSelfCollisions','parent','Exhaustive','on');
    [ii,jj]=find(triu(isnan(sep),1)); bodies=unique([ii;jj]);
    for b=bodies.'
        p=findobj(ax,'Type','Patch','DisplayName',[robot.Bodies{b}.Name '_coll_mesh']);
        for j=1:numel(p), p(j).FaceColor=[.85 .12 .12]; end
    end
    if i==1, label='V1 seed 5120: forearm / wrist-3 collision'; else, label=sprintf('V2 seed %d: path midpoint',seed); end
    annotation(f,'textbox',[.045+(i-1)*.49 .87 .45 .09],'String', ...
        sprintf('%s\nActual self collision = %d',label,hit),'EdgeColor','none', ...
        'HorizontalAlignment','center','FontSize',12,'FontWeight','bold');
    assert(hit==(i==1));
end
exportgraphics(f,fullfile(out,'self_collision_comparison.png'),'Resolution',180); savefig(f,fullfile(out,'self_collision_comparison.fig')); close(f);
f=figure('Visible','off','Color','w','Position',[50 50 1050 450]);
ax=subplot(1,2,1); scores=zeros(2,2);
for i=1:2
    scenes={'main','variant'};
    for j=1:2
        group=rows(strcmp({rows.scenario},scenes{i}) & [rows.task]==j+3 & ~strcmp({rows.mode},'penalty'));
        assert(numel(group)==10); scores(i,j)=sum([group.success]);
    end
end
bar(ax,scores); ylim(ax,[0 11]); yticks(ax,0:2:10); xticklabels(ax,{'main','variant'}); ylabel(ax,'Successful formal runs / 10'); legend(ax,'Task 4','Task 5','Location','southoutside'); grid(ax,'on');
ax=subplot(1,2,2); hold(ax,'on');
for j=1:2
    group=rows([rows.task]==j+3 & [rows.success] & ~strcmp({rows.mode},'penalty'));
    x=j+linspace(-.15,.15,numel(group)); scatter(ax,x,[group.maxOrientationDeg],35,'filled');
end
yline(ax,5,'r--','Task 5 gate'); xlim(ax,[.5 2.5]); xticks(ax,[1 2]); xticklabels(ax,{'Task 4','Task 5'}); ylabel(ax,'Maximum tilt (deg), successful runs'); grid(ax,'on');
exportgraphics(f,fullfile(out,'formal_results.png'),'Resolution',180); savefig(f,fullfile(out,'formal_results.fig')); close(f);
end
