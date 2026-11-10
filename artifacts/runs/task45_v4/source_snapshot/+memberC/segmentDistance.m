function d=segmentDistance(a,b,c,e)
% Row-wise closed segment distance. End projections also cover parallel and
% degenerate segments; the unconstrained interior solution covers crossings.
u=b-a; v=e-c; w=a-c;
aa=sum(u.*u,2); bb=sum(u.*v,2); cc=sum(v.*v,2);
dd=sum(u.*w,2); ee=sum(v.*w,2); den=aa.*cc-bb.^2;
clamp=@(x)max(0,min(1,x));
t=clamp(ee./max(cc,eps)); d2=sum((w-t.*v).^2,2);
t=clamp(sum((b-c).*v,2)./max(cc,eps)); d2=min(d2,sum((b-c-t.*v).^2,2));
s=clamp(-dd./max(aa,eps)); d2=min(d2,sum((w+s.*u).^2,2));
s=clamp(sum((e-a).*u,2)./max(aa,eps)); d2=min(d2,sum((a+s.*u-e).^2,2));
s=(bb.*ee-cc.*dd)./max(den,eps); t=(aa.*ee-bb.*dd)./max(den,eps);
valid=den>1e-14 & s>=0 & s<=1 & t>=0 & t<=1;
z=sum((w+s.*u-t.*v).^2,2); d2(valid)=min(d2(valid),z(valid));
d=sqrt(max(0,d2));
end
