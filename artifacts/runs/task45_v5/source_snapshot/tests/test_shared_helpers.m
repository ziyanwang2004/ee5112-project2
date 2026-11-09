function test_shared_helpers()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
P=stompUpdateProb([2 7 3;2 7 3;2 7 3]);
assert(max(abs(P(:)-1/3))<1e-14);
P=stompUpdateProb([0 10;1 0;2 3]);
assert(all(abs(sum(P,1)-1)<1e-14) && P(1,1)>P(2,1) && P(2,2)>P(3,2));
q=[linspace(-.2,.2,9);zeros(1,9)];
limits=[-.25 .25;-.1 .1]; rng(1);
[samples,noise]=stompSamples(20,.2*eye(7),q,limits);
for k=1:20
    assert(isequal(samples{k}(:,[1 end]),q(:,[1 end])));
    assert(all(all(samples{k}>=limits(:,1) & samples{k}<=limits(:,2))));
    assert(max(abs(samples{k}(1,:)-q(1,:)-noise{1}(k,:)))<1e-14);
end
c=sharedDefaults(); c.worldCorner=[-.6 -.8 -1]; c.worldExtent=[1.2 1.6 2];
w=makeVoxelWorld([.2 -.1 .3 .12 .10 .14],c);
assert(isequal(size(w.sEDT),[60 80 100])); % catches x/y transposition
assert(queryVoxelSDF([.2 -.1 .3],w)<0);
assert(queryVoxelSDF([-.3 .4 .6],w)>0);
assert(queryVoxelSDF([2 0 0],w)<0); % out-of-map is not silently free
[v,z]=stompObstacleCost([.2 -.1 .3],.05,w,0);
assert(v>0 && z.stationary>0); % stationary penetration remains penalized
fprintf('Shared-helper tests passed under %s\n',version);
end
