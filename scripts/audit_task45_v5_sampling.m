function receipt=audit_task45_v5_sampling()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v5'); summary=jsondecode(fileread(fullfile(release,'sampling_ablation.json')));
identity=memberC.provenance(); assert(summary.passed && strcmp(summary.sourceFingerprint,identity.sourceFingerprint));
files=dir(fullfile(release,'sampling_probe','*.mat')); assert(numel(files)==30);
base=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat')); robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0'); maximum=0;
for k=1:numel(files)
    a=load(fullfile(files(k).folder,files(k).name)); assert(ismember(a.seed,5760:5764));
    rng(a.seed,'twister'); assert(isequal(rng,a.before),'Probe RNG does not match its declared seed.');
    c=memberC.caseOptions(memberC.variantOptions(base.frozen.options,'fixed75'),a.id{1}); N=c.nWaypoints;
    if strcmp(a.kind{1},'linear'), expected=c.qStart+(c.qGoal-c.qStart)*linspace(0,1,N);
    else
        lift=[c.qStart(1);-1.5;.8;.7;-pi/2;0]; turn=lift; turn(1)=c.qGoal(1);
        expected=interp1(linspace(0,1,4),[c.qStart,lift,turn,c.qGoal].',linspace(0,1,N)).';
    end
    assert(isequal(expected,a.theta));
    A=-2*eye(N)+diag(ones(N-1,1),1)+diag(ones(N-1,1),-1); A=A(:,2:end-1); R=A.'*A; Ri=R\eye(N-2); Ri=(Ri+Ri.')/2;
    assert(isequal(a.sigma,Ri/max(diag(Ri))*c.noiseStd^2));
    for variant={'ambient','energy_control','fixed75'}
        cc=memberC.variantOptions(c,variant{1}); cc.projectionFcn=@memberC.projectTrajectory;
        context=struct('options',cc,'kinematics',struct('mode','poe','robot',robot,'model',model)); rng(a.before);
        [~,noise,valid,~,diagnostic]=memberC.sampleRollouts(c.nRollouts,a.sigma,a.theta,context); saved=a.records.(variant{1});
        assert(isequal(rng,saved.rngAfter) && isequal(valid,saved.valid));
        memberC.checkSamplingDiagnostics(diagnostic,saved.diagnostic);
        for j=1:6, maximum=max(maximum,max(abs(noise{j}(:)-saved.noise{j}(:)))); end
    end
    fprintf('V5 SAMPLER PROBE REPLAY %s passed\n',files(k).name);
end
assert(maximum<1e-12);
receipt=struct('passed',true,'pairedBatches',30,'samplerCalls',90,'maximumNoiseError',maximum,'sourceFingerprint',identity.sourceFingerprint);
memberC.writeJSON(fullfile(release,'sampling_ablation_audit.json'),receipt);
end
