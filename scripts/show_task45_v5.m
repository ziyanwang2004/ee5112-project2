function show_task45_v5(view)
if nargin<1, view='benchmark'; end
assert(any(strcmp(view,{'benchmark','energy','demo'})));
root=fileparts(fileparts(mfilename('fullpath')));
openfig(fullfile(root,'artifacts','runs','task45_v5','exports',[view '.fig']),'new','visible');
end
