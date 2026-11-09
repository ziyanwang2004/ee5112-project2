function checkSamplingDiagnostics(actual,saved)
for name={'mode','fraction','selectedMask','tangentSamples','validSamples','projectionCorrections'}
    assert(isequal(actual.(name{1}),saved.(name{1})),'Sampling diagnostic replay mismatch: %s',name{1});
end
for name={'ambientEnergy','counterfactualTangentEnergy','preProjectionEnergy','postProjectionEnergy','energyScale'}
    a=actual.(name{1}); b=saved.(name{1}); assert(isequal(isnan(a),isnan(b)));
    finite=isfinite(a); assert(max([0;abs(a(finite)-b(finite))])<1e-10,'Sampling energy replay mismatch.');
end
assert(actual.energyMatchMaxRelativeError<1e-10);
end
