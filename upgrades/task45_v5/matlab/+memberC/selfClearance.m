function [gap,pairGaps]=selfClearance(g,T)
a=g.a; b=g.b;
for k=1:size(a,1)
    H=T(:,:,g.body(k)); a(k,:)=g.a(k,:)*H(1:3,1:3).'+H(1:3,4).';
    b(k,:)=g.b(k,:)*H(1:3,1:3).'+H(1:3,4).';
end
i=g.pairs(:,1); j=g.pairs(:,2);
pairGaps=memberC.segmentDistance(a(i,:),b(i,:),a(j,:),b(j,:))-g.radius(i)-g.radius(j);
gap=min(pairGaps);
end
