function c=variantOptions(base,variant)
% All arms retain feasible-only refinement; isolate sampling strategies.
c=base; extra=memberC.defaults();
for key={'variant','anytimeEnabled','samplingMode','tangentFraction','tangentRankTolerance', ...
        'adaptiveInitialFraction','adaptiveMinFraction','adaptiveMaxFraction','adaptiveFractionStep', ...
        'adaptiveMemory','adaptiveAdvantageThreshold','adaptiveStallThreshold', ...
        'refineMaxIterations','refineMaxSeconds','refineRollouts','refineNoiseStd','refineMaxUpdate', ...
        'qualityLengthWeight','qualitySmoothWeight','qualityClearanceWeight','qualityClearanceTarget','version'}
    c.(key{1})=extra.(key{1});
end
assert(any(strcmp(variant,{'ambient','energy_control','fixed50','fixed75','adaptive'})));
c.variant=variant; c.anytimeEnabled=true;
switch variant
    case 'ambient', c.samplingMode='euclidean';
    case 'energy_control', c.samplingMode='energy'; c.tangentFraction=.75;
    case 'fixed50', c.samplingMode='tangent'; c.tangentFraction=.50;
    case 'fixed75', c.samplingMode='tangent'; c.tangentFraction=.75;
    case 'adaptive', c.samplingMode='adaptive';
end
end
