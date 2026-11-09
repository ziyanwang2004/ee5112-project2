function out = run_numeric_tests()
% Toolbox-free numerical checks. Can also run under GNU Octave.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); addpath(fullfile(root,'tests'));
rng(2023,'twister'); d=load(fullfile(root,'data','ur5_reference.mat'));
m=memberB.poeFromRecords(d.records,d.baseName,d.endEffector);
out.referenceMaxMatrixError=0;
for k=1:200
    q=(2*rand(6,1)-1)*pi;
    [A,~]=memberB.poeFK(m,q); [B,~]=localTreeFK(m,q);
    out.referenceMaxMatrixError=max(out.referenceMaxMatrixError,max(abs(A(:)-B(:))));
end
assert(out.referenceMaxMatrixError<1e-12);
% Rotated fixed leading frame, nonidentity child offset, a prismatic joint,
% and a fixed side branch exercise common integration failure modes.
r=d.records;
r(1).J=memberB.twistExp([0;0;1;0;0;0],.43);
r(1).J(1:3,4)=[.2;-.1;.3];
r(3).C=memberB.twistExp([1;0;0;0;0;0],.27);
r(3).C(1:3,4)=[.03;.04;.02];
r(4).type='prismatic'; r(4).axis=[1;2;3]/sqrt(14);
mixed=memberB.poeFromRecords(r,d.baseName,d.endEffector);
out.mixedTreeMaxMatrixError=0;
for k=1:100
    q=randn(6,1); q(3)=q(3)/10;
    [A,~]=memberB.poeFK(mixed,q); [B,~]=localTreeFK(mixed,q);
    out.mixedTreeMaxMatrixError=max(out.mixedTreeMaxMatrixError,max(abs(A(:)-B(:))));
end
assert(out.mixedTreeMaxMatrixError<1e-12);
out.twistExpMaxError=0;
for k=1:100
    w=randn(3,1); w=w/norm(w); p=randn(3,1); S=[w;-cross(w,p)];
    if mod(k,2)==0, S=[zeros(3,1);w]; end
    W=[0 -S(3) S(2);S(3) 0 -S(1);-S(2) S(1) 0];
    U=[W,S(4:6);0 0 0 0];
    for q=[0 1e-12 -1e-7 .4 -pi 2*pi]
        out.twistExpMaxError=max(out.twistExpMaxError, ...
            norm(memberB.twistExp(S,q)-expm(U*q),'fro'));
    end
end
assert(out.twistExpMaxError<1e-12);
d=memberB.boxSDF([0 0 0;1 0 0;2 0 0;2 2 2],[0 0 0 1 1 1]);
assert(max(abs(d-[-1;0;1;sqrt(3)]))<1e-12);
Q=[zeros(6,1),[.5;-.7;.3;0;0;0],ones(6,1)];
Z=memberB.densify(Q,.025);
increments=diff(Z,1,2);
assert(max(abs(increments(:)))<=.025+1e-12);
assert(isequal(Z(:,1),Q(:,1)) && isequal(Z(:,end),Q(:,end)));
[X,Ts,~]=memberB.updateJointsWorldPosition(m,randn(6,1));
assert(isequal(size(X),[6 4]) && numel(Ts)==6 && all(X(:,4)==1));
disp(out); fprintf('All numerical tests passed. Runtime: %s\n',version);
end
