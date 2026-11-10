function after=updateSamplingState(before,totals,diagnostic,stall,c)
% Deterministic cost feedback; no model queries, validation or random draws.
after=before; after.reason='within deadband'; after.updates=before.updates+1;
selected=diagnostic.selectedMask; finite=isfinite(totals);
t=sort(totals(selected & finite)); a=sort(totals(~selected & finite));
if isempty(t) && isempty(a), after.reason='no valid samples'; return; end
if isempty(t), signal=-1;
elseif isempty(a), signal=1;
else
    t=mean(t(1:max(1,ceil(numel(t)/4)))); a=mean(a(1:max(1,ceil(numel(a)/4))));
    signal=(a-t)/max([1 abs(a) abs(t)]);
end
after.advantage=c.adaptiveMemory*before.advantage+(1-c.adaptiveMemory)*signal;
if stall>=c.adaptiveStallThreshold
    after.fraction=c.adaptiveMinFraction; after.reason='stagnation exploration';
elseif after.advantage>c.adaptiveAdvantageThreshold
    after.fraction=min(c.adaptiveMaxFraction,before.fraction+c.adaptiveFractionStep); after.reason='tangent lower quartile better';
elseif after.advantage < -c.adaptiveAdvantageThreshold
    after.fraction=max(c.adaptiveMinFraction,before.fraction-c.adaptiveFractionStep); after.reason='ambient lower quartile better';
end
end
