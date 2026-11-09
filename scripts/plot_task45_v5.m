function plot_task45_v5()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v5'); summary=jsondecode(fileread(fullfile(release,'study_summary.json')));
audit=jsondecode(fileread(fullfile(release,'formal_audit.json'))); assert(audit.passed && audit.runs==75);
out=fullfile(release,'exports'); if ~exist(out,'dir'), mkdir(out); end
cases={'workcell','endpoints','layout'}; arms={'ambient','energy_control','fixed50','fixed75','adaptive'}; colors=lines(5);
files=dir(fullfile(release,'formal','**','summary.json')); index=containers.Map();
for k=1:numel(files)
    row=jsondecode(fileread(fullfile(files(k).folder,files(k).name))); index(key(row.scenario,row.variant,row.seed))=row;
end
f=figure('Visible','off','Color','w','Position',[40 40 1400 900]); tiledlayout(f,2,2,'Padding','loose','TileSpacing','loose');
ax=nexttile; values=zeros(3,5);
for ci=1:3
    for ai=1:5
        g=summary.groups(strcmp({summary.groups.scenario},cases{ci}) & strcmp({summary.groups.variant},arms{ai})); values(ci,ai)=g.successes;
    end
end
bar(ax,values); xticks(ax,1:3); xticklabels(ax,cases); ylim(ax,[0 6]); ylabel(ax,'Fine-validated successes / 5');
title(ax,'All 75 held-out runs included'); legend(ax,arms,'Interpreter','none','Location','southoutside','NumColumns',3); grid(ax,'on');
ax=nexttile; hold(ax,'on');
for ai=1:5
    values=[];
    for ci=1:3
        for seed=5800:5804, row=index(key(cases{ci},arms{ai},seed)); values(end+1)=row.plannerSeconds; end %#ok<AGROW>
    end
    plot(ax,ai+linspace(-.14,.14,numel(values)),values,'o','Color',colors(ai,:));
    plot(ax,[ai-.22 ai+.22],[median(values) median(values)],'-','Color',colors(ai,:),'LineWidth',2);
end
xticks(ax,1:5); xticklabels(ax,arms); ax.TickLabelInterpreter='none'; ylabel(ax,'Total planner time (s)'); grid(ax,'on');
title(ax,'Three cases pooled descriptively; failures included');
for phase=1:2
    ax=nexttile; hold(ax,'on'); names={'firstFeasibleQuality','finalQuality'}; field=names{phase}; refs={'fixed50','fixed75'}; handles=gobjects(1,2);
    for ri=1:2
        for ci=1:3
            p=summary.paired(strcmp({summary.paired.scenario},cases{ci}) & strcmp({summary.paired.a},refs{ri}) & strcmp({summary.paired.b},'adaptive'));
            values=[];
            for j=1:numel(p.commonSuccessfulPairs)
                item=p.commonSuccessfulPairs(j); a=index(key(item.scenario,refs{ri},item.seed)); b=index(key(item.scenario,'adaptive',item.seed));
                values(end+1)=100*(a.(field)-b.(field))/a.(field); %#ok<AGROW>
            end
            x=ci+(ri-1.5)*.20; handles(ri)=plot(ax,x+linspace(-.05,.05,numel(values)),values,'o','Color',colors(ri,:));
            if ~isempty(values), plot(ax,[x-.08 x+.08],[median(values) median(values)],'-','Color',colors(ri,:),'LineWidth',2); end
        end
    end
    yline(ax,0,'k--'); xticks(ax,1:3); xticklabels(ax,cases); grid(ax,'on'); ylabel(ax,'Paired score reduction (%)');
    if phase==1, title(ax,'Adaptive first solution; common successes only'); else, title(ax,'Adaptive final path; common successes only'); end
    legend(ax,handles,{'vs fixed50','vs fixed75'},'Location','best');
end
savePlot(f,fullfile(out,'benchmark')); close(f);

probe=jsondecode(fileread(fullfile(release,'sampling_ablation.json'))); rows=probe.details; modes={'ambient','energy_control','fixed75'};
f=figure('Visible','off','Color','w','Position',[40 40 1300 850]); tiledlayout(f,2,2,'Padding','loose','TileSpacing','loose');
for phase=1:2
    ax=nexttile; hold(ax,'on'); fields={'preProjectionRms','postProjectionRms'}; field=fields{phase}; a=[]; b=[];
    controls=rows(strcmp({rows.variant},'energy_control'));
    for k=1:numel(controls)
        row=controls(k); other=rows(strcmp({rows.scenario},row.scenario) & strcmp({rows.path},row.path) & [rows.seed]==row.seed & strcmp({rows.variant},'fixed75'));
        a(end+1)=row.(field); b(end+1)=other.(field); %#ok<AGROW>
    end
    plot(ax,a,b,'o'); limits=[min([a b])*.95 max([a b])*1.05]; plot(ax,limits,limits,'k--'); xlim(ax,limits); ylim(ax,limits);
    xlabel(ax,'Energy-control RMS (rad)'); ylabel(ax,'Fixed75 RMS (rad)'); grid(ax,'on');
    if phase==1, title(ax,'Before nonlinear projection: input energy matched'); else, title(ax,'After projection: RMS can differ'); end
end
for panel=1:2
    ax=nexttile; hold(ax,'on');
    for ai=1:3
        selected=rows(strcmp({rows.variant},modes{ai}));
        if panel==1, values=[selected.projectionCorrectionsPerWaypoint]; else, values=[selected.postProjectionRms]; end
        plot(ax,ai+linspace(-.14,.14,numel(values)),values,'o','Color',colors(ai,:));
        plot(ax,[ai-.2 ai+.2],[median(values) median(values)],'-','Color',colors(ai,:),'LineWidth',2);
    end
    xticks(ax,1:3); xticklabels(ax,modes); ax.TickLabelInterpreter='none'; grid(ax,'on');
    if panel==1, ylabel(ax,'Correction steps / sampled waypoint'); title(ax,'30 paired fixed-state batches per sampler');
    else, ylabel(ax,'Actual disturbance RMS (rad)'); title(ax,'Sampling diagnostic, not planning success'); end
end
savePlot(f,fullfile(out,'energy')); close(f);

frozen=load(fullfile(release,'frozen_config.mat')); seed=frozen.frozen.demoSeed; names={'fixed50','adaptive'}; d=cell(1,2); v=cell(1,2);
robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0');
for j=1:2
    folder=fullfile(release,'demos','workcell',names{j},'Task5',sprintf('seed_%d',seed));
    d{j}=load(fullfile(folder,'planning_result.mat')); c=d{j}.plannerOptions;
    context=struct('options',c,'geometry',memberB.loadUR5Spheres(model),'kinematics',struct('mode','poe','robot',robot,'model',model));
    w=makeVoxelWorld(d{j}.scene.boxes,c); [ok,v{j}]=memberC.validatePath(d{j}.result.theta,context,d{j}.scene,w,.00625,true); assert(ok);
end
f=figure('Visible','off','Color','w','Position',[40 40 1300 850]); tiledlayout(f,2,2,'Padding','loose','TileSpacing','loose');
ax=nexttile; files=dir(fullfile(release,'demos','workcell','adaptive','Task5',sprintf('seed_%d',seed),'iterations','*.mat')); fractions=zeros(1,numel(files));
for k=1:numel(files), a=load(fullfile(files(k).folder,files(k).name),'samplingStateBefore'); fractions(k)=a.samplingStateBefore.fraction; end
stairs(ax,1:numel(files),fractions,'LineWidth',1.8); ylim(ax,[.2 .8]); yticks(ax,[.25 .5 .75]); grid(ax,'on');
xlabel(ax,'Primary-search iteration, including restarts'); ylabel(ax,'Tangent sample fraction'); title(ax,sprintf('Development demonstration / seed %d',seed));
ax=nexttile; hold(ax,'on');
for j=1:2
    h=d{j}.result.refinement.history; plot(ax,0:size(h,1),[d{j}.result.firstFeasibleQuality;h(:,2)],'o-','LineWidth',1.3);
end
xlabel(ax,'Refinement iteration'); ylabel(ax,'Secondary score'); legend(ax,names,'Location','best'); title(ax,'Refinement improves each own incumbent'); grid(ax,'on');
ax=nexttile; hold(ax,'on');
for j=1:2, plot(ax,v{j}.s,v{j}.orientationDeg,'LineWidth',1.4); end
yline(ax,5,'r--','5 deg'); xlabel(ax,'Normalized path progress'); ylabel(ax,'Tool y tilt (deg)'); legend(ax,names,'Location','best'); grid(ax,'on');
ax=nexttile; hold(ax,'on');
for j=1:2, plot(ax,v{j}.s,1000*v{j}.voxelClearance,'LineWidth',1.4); end
yline(ax,35,'r--','35 mm'); xlabel(ax,'Normalized path progress'); ylabel(ax,'Conservative clearance (mm)'); legend(ax,names,'Location','best'); grid(ax,'on');
savePlot(f,fullfile(out,'demo')); close(f);
memberC.writeJSON(fullfile(release,'plot_qa.json'),struct('passed',true,'reopenedEditableFigures',3,'figures',{{'benchmark','energy','demo'}}));
fprintf('V5 THREE FIGURES EXPORTED AND REOPENED\n');
end
function value=key(scenario,variant,seed)
value=sprintf('%s_%s_%d',scenario,variant,seed);
end
function savePlot(f,base)
drawnow; exportgraphics(f,[base '.png'],'Resolution',180); savefig(f,[base '.fig']); h=openfig([base '.fig'],'invisible'); close(h);
end
