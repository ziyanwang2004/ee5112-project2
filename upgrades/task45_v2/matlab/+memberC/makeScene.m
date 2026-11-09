function scene=makeScene(model,c,id)
assert(any(strcmp(id,{'main','variant'})),'Unknown scenario.');
[T,~]=memberB.poeFK(model,(c.qStart+c.qGoal)/2);
b=find(strcmp(model.bodyNames,'wrist_1_link')); assert(isscalar(b));
p=T(1:3,4,b).';
boxes=[p .08 .08 .08; p+[-.18 -.22 .02] .06 .06 .18; p+[-.18 .22 .08] .06 .06 .18];
if strcmp(id,'variant')
    boxes(2,2)=boxes(2,2)+.04; boxes(3,2)=boxes(3,2)-.04; boxes(3,6)=.20;
end
scene=struct('id',id,'anchor',p,'boxes',boxes,'qStart',c.qStart,'qGoal',c.qGoal, ...
    'description','UR5 transfer around three staggered axis-aligned obstacles');
end
