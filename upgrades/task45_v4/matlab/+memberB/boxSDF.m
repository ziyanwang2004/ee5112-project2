function d = boxSDF(P,boxes)
% Exact signed Euclidean distance to a union of axis-aligned boxes outside
% overlaps; inside the union min individual SDF is a penetration surrogate.
% boxes rows: [cx cy cz hx hy hz]. Task 2 has one box, so SDF is exact.
d=inf(size(P,1),1);
for k=1:size(boxes,1)
    v=abs(P-boxes(k,1:3))-boxes(k,4:6);
    dk=sqrt(sum(max(v,0).^2,2))+min(max(v,[],2),0);
    d=min(d,dk);
end
end
