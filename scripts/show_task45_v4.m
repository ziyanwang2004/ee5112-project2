function show_task45_v4(view)
% Inspect V4 algorithm experiments without replanning or modifying evidence.
if nargin<1, view='combined'; end
assert(any(strcmp(view,{'combined','anytime','benchmark'})));
root=fileparts(fileparts(mfilename('fullpath')));
if strcmp(view,'benchmark'), name='benchmark'; else, name=['refinement_' view]; end
path=fullfile(root,'artifacts','runs','task45_v4','exports',[name '.fig']);
assert(exist(path,'file')==2,'Finish the V4 experiment audit and figure export first.');
openfig(path,'new','visible');
end
