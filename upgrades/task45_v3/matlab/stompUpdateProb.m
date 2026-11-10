function trajProb=stompUpdateProb(Stheta,h)
% Eq. (11), retaining the received signature and optional sensitivity.
if nargin<2, h=10; end
assert(all(isfinite(Stheta(:))),'Rollout costs must be finite.');
lo=min(Stheta,[],1); span=max(Stheta,[],1)-lo;
span(span<1e-12)=1;
E=exp(-h*(Stheta-lo)./span);
trajProb=E./sum(E,1); % tied columns yield uniform probabilities, not zeros
end
