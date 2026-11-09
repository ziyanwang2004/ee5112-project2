function out = validatePoe(robot,m,folder)
% MATLAB oracle checks: all bodies, not just the tool, at 200 configurations.
state=rng; guard=onCleanup(@()rng(state)); %#ok<NASGU>
rng(2023,'twister'); n=200;
lo=max(m.limits(:,1),-pi); hi=min(m.limits(:,2),pi);
Q=lo+(hi-lo).*rand(m.nJoints,n);
Q(:,1)=0; Q(:,2)=homeConfiguration(robot);
pos=zeros(n,1); rot=pos;
for k=1:n
    [P,~]=memberB.poeFK(m,Q(:,k));
    [B,~]=memberB.builtinFK(robot,m,Q(:,k));
    for b=1:m.nBodies
        pos(k)=max(pos(k),norm(P(1:3,4,b)-B(1:3,4,b)));
        rot(k)=max(rot(k),norm(P(1:3,1:3,b)-B(1:3,1:3,b),'fro'));
    end
end
out.maxPositionError=max(pos); out.maxRotationFrobenius=max(rot);
assert(out.maxPositionError<1e-9 && out.maxRotationFrobenius<1e-9, ...
    'PoE does not match MATLAB: p %.3g, R %.3g',out.maxPositionError,out.maxRotationFrobenius);
memberB.writeCSV(fullfile(folder,'fk_accuracy.csv'), ...
    'configuration,max_position_error_m,max_rotation_Frobenius',[(1:n).',pos,rot]);
% Warm up both implementations. Measure equal all-body output workloads.
for k=1:10
    memberB.poeFK(m,Q(:,k)); memberB.builtinFK(robot,m,Q(:,k));
end
tp=zeros(5,1); tb=tp;
for trial=1:5
    tic;
    for k=1:n, memberB.poeFK(m,Q(:,k)); end
    tp(trial)=toc;
    tic;
    for k=1:n, memberB.builtinFK(robot,m,Q(:,k)); end
    tb(trial)=toc;
end
out.poeMedianSeconds=median(tp); out.builtinMedianSeconds=median(tb);
out.allBodySpeedRatio=median(tb)/median(tp);
memberB.writeCSV(fullfile(folder,'fk_benchmark.csv'), ...
    'trial,poe_all_bodies_seconds,builtin_all_bodies_seconds',[ (1:5).',tp,tb]);
save(fullfile(folder,'fk_validation.mat'),'out','Q','pos','rot','tp','tb','-v7');
fprintf('PoE max errors: position %.3g m, rotation Frobenius %.3g\n',max(pos),max(rot));
fprintf('All-body benchmark, builtin / PoE: %.3fx\n',out.allBodySpeedRatio);
end
