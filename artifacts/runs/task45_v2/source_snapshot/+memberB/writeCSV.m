function writeCSV(path,header,A)
fid=fopen(path,'w'); assert(fid>=0,'Cannot create %s',path);
guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',header);
fmt=[repmat('%.16g,',1,size(A,2)-1),'%.16g\n'];
fprintf(fid,fmt,A.');
end
