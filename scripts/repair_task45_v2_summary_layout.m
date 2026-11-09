root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
release=fullfile(root,'artifacts','runs','task45_v2'); source=fullfile(release,'demos','exports');
backup=fullfile(release,'delivery','review','pre_layout_repair','summaries'); if ~exist(backup,'dir'), mkdir(backup); end
files=dir(fullfile(source,'*','task*_summary.fig'));
assert(numel(files)==4);
for k=1:numel(files)
    path=fullfile(files(k).folder,files(k).name); [~,scene]=fileparts(files(k).folder);
    if ~exist(fullfile(backup,scene),'dir'), mkdir(fullfile(backup,scene)); end
    if ~exist(fullfile(backup,scene,files(k).name),'file'), copyfile(path,fullfile(backup,scene,files(k).name)); end
    png=strrep(path,'.fig','.png');
    if ~exist(fullfile(backup,scene,strrep(files(k).name,'.fig','.png')),'file'), copyfile(png,fullfile(backup,scene,strrep(files(k).name,'.fig','.png'))); end
    f=openfig(fullfile(backup,scene,files(k).name),'invisible'); f.Position=[40 40 1300 780];
    % The robot's orientation inset is a hidden axes. Keep its original
    % small inset position; change only the three visible plot axes.
    axesList=findobj(f,'Type','axes');
    for j=1:numel(axesList)
        ax=axesList(j); label=ax.YLabel.String;
        ax.FontSize=10;
        if strcmp(label,'Tool y tilt (deg)')
            ax.Position=[.63 .60 .32 .28];
            if contains(files(k).name,'task5'), ylim(ax,[0 5.5]); end
        elseif strcmp(label,'Clearance (mm)')
            ax.Position=[.63 .21 .32 .26];
        else
            ax.Position=[.12 .18 .32 .62]; ax.Title.FontSize=12;
        end
    end
    delete(findall(f,'Type','legend'));
    % Explicit annotation stays clear of axes during print's layout pass.
    annotation(f,'textbox',[.62 .035 .34 .09],'String', ...
        sprintf('Blue: conservative voxel / spheres\nOrange: robot collision geometry'), ...
        'FontSize',10,'Interpreter','none','EdgeColor','none','HorizontalAlignment','left');
    drawnow; savefig(f,path); f.PaperPositionMode='auto'; print(f,png,'-dpng','-r160'); close(f);
    reopened=openfig(path,'invisible'); close(reopened);
end
fprintf('SUMMARY LAYOUT REPAIRED: %d editable FIGs reopened\n',numel(files));
