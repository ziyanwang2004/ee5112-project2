% Read-only demonstration assets and editable-figure opening check.
root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'scripts'));
release=fullfile(root,'artifacts','runs','task45_v3');
info=show_project_demo('check','v3'); assert(numel(info)==5);
figs=dir(fullfile(release,'demos','exports','workcell','*.fig')); assert(numel(figs)==4);
lastwarn('');
for k=1:numel(figs)
    f=openfig(fullfile(figs(k).folder,figs(k).name),'invisible');
    assert(~isempty(findall(f,'Type','axes'))); close(f);
end
videos=dir(fullfile(release,'demos','exports','workcell','*.avi')); frames=zeros(1,numel(videos));
for k=1:numel(videos)
    reader=VideoReader(fullfile(videos(k).folder,videos(k).name)); assert(abs(reader.FrameRate-15)<1e-12);
    while hasFrame(reader), readFrame(reader); frames(k)=frames(k)+1; end
    assert(frames(k)==150);
end
[message,identifier]=lastwarn; assert(isempty(message),'Asset warning: %s %s',identifier,message);
receipt=struct('passed',true,'wholeProjectAssets',numel(info),'openedEditableFigures',numel(figs), ...
    'videos',numel(videos),'decodedFrames',sum(frames),'warnings',message);
fid=fopen(fullfile(release,'assets_matlab_qa.json'),'w'); fwrite(fid,jsonencode(receipt,'PrettyPrint',true)); fclose(fid);
fprintf('V3 ALL DEMO ASSETS AND FOUR FIGS PASSED\n');
