function plot_task45_v4()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v4','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v4');
summary=jsondecode(fileread(fullfile(release,'study_summary.json')));
audit=jsondecode(fileread(fullfile(release,'formal_audit.json'))); assert(audit.passed);
out=fullfile(release,'exports'); if ~exist(out,'dir'), mkdir(out); end
variants={'baseline','anytime','tangent','combined'}; colors=lines(4);
f=figure('Visible','off','Color','w','Position',[40 40 1260 850]); tiledlayout(f,2,2,'Padding','loose','TileSpacing','loose');
ax=nexttile; values=arrayfun(@(x)x.successes,summary.groups); bar(ax,values); ylim(ax,[0 11]);
xticks(ax,1:4); xticklabels(ax,variants); ylabel(ax,'Successes / 10'); title(ax,'All held-out runs included'); grid(ax,'on');
ax=nexttile; hold(ax,'on');
for j=1:4
    first=summary.groups(j).firstFeasibleSecondsSuccessful.median; total=summary.groups(j).plannerSecondsAll.median;
    if isempty(first), first=NaN; end
    plot(ax,[j-.12 j+.12],[first total],'o-','Color',colors(j,:),'LineWidth',1.6);
end
xticks(ax,1:4); xticklabels(ax,variants); ylabel(ax,'Median planner time (s)'); grid(ax,'on');
title(ax,'Left: first feasible (successes); right: total (all)');
ax=nexttile; hold(ax,'on');
for j=1:4
    selected=audit.fineDetails(strcmp({audit.fineDetails.variant},variants{j}) & [audit.fineDetails.nominalSuccess]);
    x=[]; y=[];
    for k=1:numel(selected)
        item=selected(k);
        row=jsondecode(fileread(fullfile(release,'formal',variants{j},'workcell','Task5',sprintf('seed_%d',item.seed),'summary.json')));
        x(end+1)=item.seed; y(end+1)=row.finalQuality; %#ok<AGROW>
    end
    plot(ax,x,y,'o-','Color',colors(j,:),'DisplayName',variants{j});
end
xlabel(ax,'Paired seed'); ylabel(ax,'Secondary quality score'); title(ax,'Successful paths only; lower is better'); grid(ax,'on'); legend(ax,'Location','best');
ax=nexttile; hold(ax,'on');
for j=1:4
    selected=audit.fineDetails(strcmp({audit.fineDetails.variant},variants{j}));
    values=arrayfun(@(x)x.searchSampling.meanProjectionCorrectionsPerWaypoint,selected);
    plot(ax,j+linspace(-.12,.12,numel(values)),values,'o','Color',colors(j,:));
    plot(ax,[j-.2 j+.2],[median(values) median(values)],'-','Color',colors(j,:),'LineWidth',2);
end
xticks(ax,1:4); xticklabels(ax,variants); ylabel(ax,'Mean correction steps / sampled waypoint');
title(ax,'Primary-search projection work; all runs'); grid(ax,'on');
savePlot(f,fullfile(out,'benchmark')); close(f);
frozen=load(fullfile(release,'frozen_config.mat')); seed=frozen.frozen.demoSeed;
for variant={'anytime','combined'}
    d=load(fullfile(release,'demos',variant{1},'workcell','Task5',sprintf('seed_%d',seed),'planning_result.mat'));
    c=d.plannerOptions; robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0');
    context=struct('options',c,'geometry',memberB.loadUR5Spheres(model),'kinematics',struct('mode','poe','robot',robot,'model',model));
    w=makeVoxelWorld(d.scene.boxes,c); Q={d.result.searchTheta,d.result.theta}; v=cell(1,2);
    for j=1:2, [ok,v{j}]=memberC.validatePath(Q{j},context,d.scene,w,.00625,true); assert(ok); end
    f=figure('Visible','off','Color','w','Position',[40 40 1250 820]); layout=tiledlayout(f,2,2,'Padding','loose','TileSpacing','loose');
    ax=nexttile(layout,1); drawRobot(ax,robot,Q{2}(:,31),d.scene);
    hold(ax,'on'); plot3(ax,v{1}.toolPosition(1,:),v{1}.toolPosition(2,:),v{1}.toolPosition(3,:),'b-','LineWidth',1.5);
    plot3(ax,v{2}.toolPosition(1,:),v{2}.toolPosition(2,:),v{2}.toolPosition(3,:),'Color',[.05 .6 .3],'LineWidth',1.8);
    title(ax,sprintf('%s / seed %d / first vs refined',variant{1},seed));
    ax=nexttile(layout,2); plot(ax,v{1}.s,v{1}.orientationDeg,'b-'); hold(ax,'on');
    plot(ax,v{2}.s,v{2}.orientationDeg,'Color',[.05 .6 .3]);
    yline(ax,5,'r--','5 deg'); grid(ax,'on'); xlabel(ax,'Normalized path progress'); ylabel(ax,'Tool y tilt (deg)'); legend(ax,'First feasible','Refined');
    ax=nexttile(layout,3); plot(ax,v{1}.s,1000*v{1}.voxelClearance,'b-'); hold(ax,'on');
    plot(ax,v{2}.s,1000*v{2}.voxelClearance,'Color',[.05 .6 .3]); yline(ax,35,'r--','35 mm');
    grid(ax,'on'); xlabel(ax,'Normalized path progress'); ylabel(ax,'Conservative clearance (mm)'); legend(ax,'First feasible','Refined');
    ax=nexttile(layout,4); h=d.result.refinement.history;
    plot(ax,0:size(h,1),[d.result.firstFeasibleQuality;h(:,2)],'o-','LineWidth',1.5);
    grid(ax,'on'); xlabel(ax,'Refinement iteration'); ylabel(ax,'Secondary quality score'); title(ax,'Every accepted step is feasible and improves score');
    savePlot(f,fullfile(out,['refinement_' variant{1}])); close(f);
end
memberC.writeJSON(fullfile(release,'plot_qa.json'),struct('passed',true,'openedEditableFigures',3, ...
    'figures',{{'benchmark','refinement_anytime','refinement_combined'}}, ...
    'scope','Exports completed and each FIG reopened successfully. Visual inspection recorded separately.'));
fprintf('V4 BENCHMARK AND FEASIBLE-REFINEMENT FIGURES EXPORTED\n');
end
function drawRobot(ax,robot,q,scene)
show(robot,q,'Parent',ax,'PreservePlot',false,'Frames','off','Visuals','on'); hold(ax,'on');
faces=[1 2 3 4;5 6 7 8;1 2 6 5;2 3 7 6;3 4 8 7;4 1 5 8];
corners=[-1 -1 -1;1 -1 -1;1 1 -1;-1 1 -1;-1 -1 1;1 -1 1;1 1 1;-1 1 1];
for k=1:size(scene.boxes,1)
    box=scene.boxes(k,:); color=[.9 .5 .15]; if k==1, color=[.55 .58 .62]; end
    patch(ax,'Vertices',corners.*box(4:6)+box(1:3),'Faces',faces,'FaceColor',color,'FaceAlpha',.2,'EdgeColor',color*.7);
end
axis(ax,'equal'); axis(ax,[-1 1 -1 1 -.03 1.6]); view(ax,135,26); grid(ax,'on');
xlabel(ax,'x (m)'); ylabel(ax,'y (m)'); zlabel(ax,'z (m)');
ax.Toolbar.Visible='off'; disableDefaultInteractivity(ax);
end
function savePlot(f,base)
drawnow; exportgraphics(f,[base '.png'],'Resolution',180); savefig(f,[base '.fig']);
h=openfig([base '.fig'],'invisible'); close(h);
end
