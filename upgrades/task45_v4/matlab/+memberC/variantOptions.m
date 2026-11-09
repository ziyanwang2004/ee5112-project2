function c=variantOptions(base,variant)
% Four fixed arms isolate anytime refinement and constraint-aware sampling.
c=base; extra=memberC.defaults();
for key={'variant','anytimeEnabled','samplingMode','tangentFraction','tangentRankTolerance', ...
        'refineMaxIterations','refineMaxSeconds','refineRollouts','refineNoiseStd','refineMaxUpdate', ...
        'qualityLengthWeight','qualitySmoothWeight','qualityClearanceWeight','qualityClearanceTarget','version'}
    c.(key{1})=extra.(key{1});
end
assert(any(strcmp(variant,{'baseline','anytime','tangent','combined'})));
c.variant=variant; c.anytimeEnabled=any(strcmp(variant,{'anytime','combined'}));
if any(strcmp(variant,{'tangent','combined'})), c.samplingMode='tangent'; else, c.samplingMode='euclidean'; end
end
