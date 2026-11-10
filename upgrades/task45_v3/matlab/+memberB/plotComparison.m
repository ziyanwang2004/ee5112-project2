function plotComparison(robot,scene,result,folder)
% Compare at a parameter where the actual initial path was in collision.
f=figure('Color','w','Position',[100 80 1280 600], ...
    'MenuBar','none','ToolBar','none','Resize','off');
titles={'Linear initialization: collision','STOMP planned path: obstacle avoided'};
bad=find(result.initialMeshValidation.worldInCollision);
assert(~isempty(bad),'Comparison requires a colliding initialization.');
index=bad(ceil(numel(bad)/2));
parameter=(index-1)/(result.initialMeshValidation.nStates-1);
Q={result.initialMeshValidation.theta(:,index), ...
    interp1(linspace(0,1,size(result.theta,2)),result.theta.',parameter).'};
for k=1:2
    ax=subplot(1,2,k);
    q=Q{k};
    show(robot,q,'Parent',ax,'Frames','off','Visuals','on');
    hold(ax,'on');
    for b=1:size(scene.boxes,1)
        v=scene.boxes(b,:);
        box=collisionBox(2*v(4),2*v(5),2*v(6));
        box.Pose=[eye(3),v(1:3).';0 0 0 1];
        show(box,'Parent',ax);
    end
    axis(ax,'equal');
    if numel(scene.qStart)==7
        set(ax,'XLim',[-.35 .85],'YLim',[-.45 .85],'ZLim',[-.15 1.05]);
    else
        set(ax,'XLim',[-.1 .9],'YLim',[-.35 .35],'ZLim',[-.15 .95]);
    end
    ax.Toolbar.Visible='off'; disableDefaultInteractivity(ax);
    view(ax,140,25);
    title(ax,sprintf('%s (s = %.3f)',titles{k},parameter));
    xlabel(ax,'x (m)'); ylabel(ax,'y (m)'); zlabel(ax,'z (m)');
end
exportgraphics(f,fullfile(folder,'robot_midpoint_comparison.png'),'Resolution',180);
savefig(f,fullfile(folder,'robot_midpoint_comparison.fig'));
end
