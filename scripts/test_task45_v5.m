root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
base=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat'));
robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0');
c=memberC.variantOptions(base.frozen.options,'fixed75'); c.projectionFcn=@memberC.projectTrajectory;
context=struct('options',c,'kinematics',struct('mode','poe','robot',robot,'model',model));
theta=c.qStart+(c.qGoal-c.qStart)*linspace(0,1,9); sigma=.03*eye(7); rng(271); saved=rng;
[fixed,noise,v,~,dt]=memberC.sampleRollouts(16,sigma,theta,context); after=rng;
context.options=memberC.variantOptions(c,'energy_control'); rng(saved);
[control,cn,cv,~,de]=memberC.sampleRollouts(16,sigma,theta,context);
assert(isequal(rng,after) && de.energyMatchMaxRelativeError<1e-12);
assert(max(abs(de.preProjectionEnergy-dt.preProjectionEnergy))<1e-11);
assert(any(cellfun(@(a,b)max(abs(a(:)-b(:)))>1e-5,fixed,control)));
for k=1:16
    assert(isequal(control{k}(:,[1 end]),theta(:,[1 end])));
    assert(all(control{k}>=model.limits(:,1)-1e-12 & control{k}<=model.limits(:,2)+1e-12,'all'));
    for j=1:6, assert(isequal(cn{j}(k,:),control{k}(j,:)-theta(j,:))); end
end
variants={'ambient','energy_control','fixed50','fixed75','adaptive'};
for name=variants
    cc=memberC.variantOptions(c,name{1}); cc.projectionFcn=[]; context.options=cc;
    rng(saved); [samples,actual]=memberC.sampleRollouts(16,sigma,theta,context);
    rng(saved); [legacy,expected]=stompSamples(16,sigma,theta,model.limits);
    assert(isequal(samples,legacy) && isequal(actual,expected),'Unconstrained sampler changed.');
end
c=memberC.variantOptions(c,'adaptive');
before=struct('fraction',.5,'advantage',0,'updates',0,'reason','restart');
diagnostic=struct('selectedMask',[true(4,1);false(4,1)]);
state=rng; up=memberC.updateSamplingState(before,[ones(4,1);10*ones(4,1)],diagnostic,0,c);
down=memberC.updateSamplingState(before,[10*ones(4,1);ones(4,1)],diagnostic,0,c);
stalled=memberC.updateSamplingState(up,[ones(4,1);10*ones(4,1)],diagnostic,3,c);
invalid=memberC.updateSamplingState(before,inf(8,1),diagnostic,0,c);
assert(up.fraction==.75 && down.fraction==.25 && stalled.fraction==.25 && invalid.fraction==.5 && isequal(state,rng));
for k=1:20, up=memberC.updateSamplingState(up,[ones(4,1);10*ones(4,1)],diagnostic,0,c); end
assert(up.fraction==.75);
identity=memberC.provenance();
memberC.writeJSON(fullfile(root,'artifacts','runs','task45_v5','unit_tests.json'), ...
    struct('passed',true,'preProjectionEnergyMatchRelativeError',de.energyMatchMaxRelativeError, ...
    'rngDrawsUnchanged',true,'actualNoiseAndLimitsChecked',true,'task4SamplerUnchanged',true, ...
    'controllerDirectionBoundsStallAndInvalidChecked',true,'sourceFingerprint',identity.sourceFingerprint));
fprintf('V5 ENERGY, RNG, LIMITS, TASK4 AND CONTROLLER UNIT CHECKS PASSED\n');
