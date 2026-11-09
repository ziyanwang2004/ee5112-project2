root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v5'); out=fullfile(release,'sampling_probe');
assert(~exist(out,'dir'),'Sampling ablation already exists. Preserve its evidence.'); mkdir(out);
base=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat'));
robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0'); rows={}; maximum=0;
for id={'workcell','endpoints','layout'}
    c=memberC.caseOptions(memberC.variantOptions(base.frozen.options,'fixed75'),id{1});
    N=c.nWaypoints; A=-2*eye(N)+diag(ones(N-1,1),1)+diag(ones(N-1,1),-1); A=A(:,2:end-1);
    R=A.'*A; Ri=R\eye(N-2); Ri=(Ri+Ri.')/2; sigma=Ri/max(diag(Ri))*c.noiseStd^2;
    linear=c.qStart+(c.qGoal-c.qStart)*linspace(0,1,N);
    lift=[c.qStart(1);-1.5;.8;.7;-pi/2;0]; turn=lift; turn(1)=c.qGoal(1);
    knots=[c.qStart,lift,turn,c.qGoal]; witness=interp1(linspace(0,1,4),knots.',linspace(0,1,N)).';
    for kind={'linear','witness'}
        theta=linear; if strcmp(kind{1},'witness'), theta=witness; end
        for seed=5760:5764
            records=struct(); variants={'ambient','energy_control','fixed75'};
            order=circshift(1:3,[0 mod(seed,3)]); rng(seed,'twister'); before=rng;
            for index=order
                variant=variants{index}; cc=memberC.variantOptions(c,variant); cc.projectionFcn=@memberC.projectTrajectory;
                context=struct('options',cc,'kinematics',struct('mode','poe','robot',robot,'model',model)); rng(before);
                [samples,noise,valid,projection,diagnostic]=memberC.sampleRollouts(c.nRollouts,sigma,theta,context); %#ok<ASGLU>
                records.(variant)=struct('diagnostic',diagnostic,'noise',{noise},'valid',valid,'rngAfter',rng);
                denominator=c.nRollouts*6*(N-2);
                rows{end+1}=struct('scenario',id{1},'path',kind{1},'seed',seed,'variant',variant, ...
                    'projectionCorrectionsPerWaypoint',diagnostic.projectionCorrections/(c.nRollouts*(N-2)), ...
                    'preProjectionRms',sqrt(sum(diagnostic.preProjectionEnergy)/denominator), ...
                    'postProjectionRms',sqrt(sum(diagnostic.postProjectionEnergy)/denominator), ...
                    'validSamples',nnz(valid),'projectionSeconds',diagnostic.projectionSeconds,'tangentSeconds',diagnostic.tangentSeconds); %#ok<SAGROW>
            end
            error=max(abs(records.energy_control.diagnostic.preProjectionEnergy-records.fixed75.diagnostic.preProjectionEnergy));
            maximum=max(maximum,error); assert(error<1e-10);
            assert(isequal(records.ambient.rngAfter,records.fixed75.rngAfter) && isequal(records.ambient.rngAfter,records.energy_control.rngAfter));
            file=fullfile(out,sprintf('%s_%s_seed_%d.mat',id{1},kind{1},seed));
            save(file,'theta','sigma','before','records','id','kind','seed','order','-v7');
        end
    end
end
identity=memberC.provenance();
memberC.writeJSON(fullfile(release,'sampling_ablation.json'),struct('passed',true,'pairedBatches',30,'samplerCalls',90, ...
    'maxPreProjectionEnergyAbsoluteDifference',maximum,'sourceFingerprint',identity.sourceFingerprint, ...
    'scope','Fixed-state sampling diagnostic only; no planner success claim. Energy is matched before nonlinear projection, not after.', ...
    'details',{rows}));
fprintf('V5 FIXED-STATE ENERGY ABLATION PASSED: 30 BATCHES / 90 SAMPLER CALLS\n');
