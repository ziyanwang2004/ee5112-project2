function P=sampleProbabilities(S,valid,sensitivity)
P=zeros(size(S));
if any(valid)
    % Failed projections receive exactly zero probability, including tied costs.
    P(valid,:)=stompUpdateProb(S(valid,:),sensitivity);
end
end
