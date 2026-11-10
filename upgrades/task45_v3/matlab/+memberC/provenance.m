function p=provenance()
root=fileparts(fileparts(mfilename('fullpath'))); project=fileparts(root);
[~,commit]=system(sprintf('git -C "%s" rev-parse HEAD',project));
p=struct('commit',strtrim(commit),'matlabVersion',version,'platform',computer, ...
    'timestampUtc',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss')));
files=dir(fullfile(root,'**','*.m')); records=repmat(struct('path','','sha256',''),numel(files),1);
for k=1:numel(files)
    path=fullfile(files(k).folder,files(k).name); fid=fopen(path,'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    records(k).path=strrep(path(numel(root)+2:end),'\','/'); records(k).sha256=memberC.sha256(bytes);
end
[~,order]=sort({records.path}); records=records(order); p.sources=records;
p.sourceFingerprint=memberC.sha256(unicode2native(jsonencode(records),'UTF-8'));
end
