function dtheta=stompDTheta(trajProb,em)
% Received signature retained: expectation of perturbations under weights.
dtheta=zeros(numel(em),size(trajProb,2));
assert(all(isfinite(trajProb(:))));
for j=1:numel(em)
    assert(isequal(size(em{j}),size(trajProb)));
    dtheta(j,:)=sum(trajProb.*em{j},1);
end
dtheta(:,[1 end])=0;
end
