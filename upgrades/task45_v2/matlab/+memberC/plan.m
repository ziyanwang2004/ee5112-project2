function [r,R,M]=plan(robot_struct,scene,context,w,folder)
% Extended STOMP: original named stages, optional projection, unified gate.
c=context.options; model=context.kinematics.model; N=c.nWaypoints;
initial=scene.qStart+(scene.qGoal-scene.qStart)*linspace(0,1,N);
assert(memberC.selfPathSafe(initial,context),'Initial path must be mesh self-collision-free.');
A=-2*eye(N)+diag(ones(N-1,1),1)+diag(ones(N-1,1),-1);
A=A(:,2:end-1); R=A.'*A; Ri=R\eye(N-2); Ri=(Ri+Ri.')/2;
M=Ri./max(Ri,[],1)/N; shape=Ri/max(diag(Ri));
[~,initialCost,initialInfo]=stompTrajCost(robot_struct,initial,R,w,context);
bestTheta=initial; bestCost=initialCost; bestInfo=initialInfo; bestRestart=1;
feasibleTheta=[]; feasibleCost=inf; feasibleInfo=[]; feasibleRestart=0;
history=[]; animation={initial}; termination='maximum iterations';
traceFolder=fullfile(folder,'iterations'); mkdir(traceFolder);
timer=tic; timedOut=false;
for restart=1:c.maxRestarts
    rng(c.seed+c.restartSeedStride*(restart-1),'twister'); theta=initial; cost=initialCost; info=initialInfo; stall=0;
    for iter=1:c.maxIterations
        if toc(timer)>=c.maxWallSeconds, timedOut=true; termination='time budget'; break; end
        thetaBefore=theta; rngBefore=rng; costBefore=cost;
        std=c.noiseStd*(.55+.45*(1-iter/c.maxIterations)); sigma=shape*std^2;
        [theta_samples,em]=stompSamples(c.nRollouts,sigma,theta,model.limits);
        [theta_samples,em,validSamples,projectionDiagnostics]=memberC.projectSamples(theta_samples,em,theta,context);
        Stheta=zeros(c.nRollouts,N); sampleTotals=inf(c.nRollouts,1);
        for k=find(validSamples).'
            [Stheta(k,:),sampleTotals(k)]=stompTrajCost(robot_struct,theta_samples{k},R,w,context);
        end
        trajProb=memberC.sampleProbabilities(Stheta,validSamples,c.sensitivity);
        dtheta=stompDTheta(trajProb,em);
        [~,dtheta_smoothed]=stompUpdateTheta(theta,dtheta,M);
        magnitude=max(abs(dtheta_smoothed(:)));
        if magnitude>c.maxUpdate, dtheta=dtheta*c.maxUpdate/magnitude; end
        [~,dtheta_smoothed]=stompUpdateTheta(theta,dtheta,M);
        proposed=theta; proposedCost=cost; proposedInfo=info;
        acceptedCode=0; acceptedAlpha=0; acceptedSample=0; candidateProjectionDiagnostics=cell(1,3); ai=0;
        candidateSelfSafe=nan(1,3); sampleSelfSafe=nan(c.nRollouts,1);
        feasibleAccepted=false;
        gateDue=iter>=c.minIterations && (mod(iter,5)==0 || stall>=c.maxStallIterations);
        for alpha=[1 .5 .25]
            ai=ai+1;
            candidate=stompUpdateTheta(theta,alpha*dtheta,M);
            candidate=max(model.limits(:,1),min(model.limits(:,2),candidate));
            candidate(:,1)=scene.qStart; candidate(:,end)=scene.qGoal;
            valid=true;
            if ~isempty(c.projectionFcn), [candidate,valid,candidateProjectionDiagnostics{ai}]=c.projectionFcn(candidate,context); end
            if ~valid, continue; end
            [~,candidateCost,candidateInfo]=stompTrajCost(robot_struct,candidate,R,w,context);
            % Validate promising candidates before cost-only rejection. A
            % feasible candidate can be better even when its cost is higher.
            if gateDue && candidateInfo.minClearance>=c.margin-1e-9
                [feasibleAccepted,~]=c.validationFcn(candidate,context,scene,w,c.finalDenseJointStep,false);
                if feasibleAccepted
                    proposed=candidate; proposedCost=candidateCost; proposedInfo=candidateInfo;
                    acceptedCode=1; acceptedAlpha=alpha; candidateSelfSafe(ai)=true; break;
                end
            end
            if candidateCost<proposedCost
                candidateSelfSafe(ai)=memberC.selfPathSafe(candidate,context);
                if ~candidateSelfSafe(ai), continue; end
                proposed=candidate; proposedCost=candidateCost; proposedInfo=candidateInfo;
                acceptedCode=1; acceptedAlpha=alpha;
            end
        end
        [orderedCosts,order]=sort(sampleTotals);
        if ~feasibleAccepted
            for rank=1:min(c.maxFallbackSelfChecks,numel(order))
                bestSample=order(rank); sampleCost=orderedCosts(rank);
                if ~isfinite(sampleCost) || sampleCost>=proposedCost, break; end
                sampleSelfSafe(bestSample)=memberC.selfPathSafe(theta_samples{bestSample},context);
                if ~sampleSelfSafe(bestSample), continue; end
                proposed=theta_samples{bestSample}; proposedCost=sampleCost;
                [~,~,proposedInfo]=stompTrajCost(robot_struct,proposed,R,w,context);
                acceptedCode=2; acceptedAlpha=0; acceptedSample=bestSample; break;
            end
        end
        theta=proposed; cost=proposedCost; info=proposedInfo;
        if costBefore-cost<c.convergenceThreshold, stall=stall+1; else, stall=0; end
        thetaAfter=theta; rngAfter=rng;
        metrics=[restart,iter,cost,info.minClearance,info.smoothness,acceptedCode,acceptedAlpha];
        history(end+1,:)=metrics; animation{end+1}=theta; %#ok<AGROW>
        file=fullfile(traceFolder,sprintf('restart_%02d_iteration_%03d.mat',restart,iter));
        save(file,'thetaBefore','thetaAfter','Stheta','sampleTotals','trajProb','dtheta', ...
            'dtheta_smoothed','metrics','acceptedSample','rngBefore','rngAfter','sigma','R','M','validSamples', ...
            'projectionDiagnostics','candidateProjectionDiagnostics','stall','-v7');
        save(file,'candidateSelfSafe','sampleSelfSafe','feasibleAccepted','-append');
        if c.retainRollouts, save(file,'theta_samples','em','-append'); end
        if ~c.retainRollouts && ~isempty(c.projectionFcn), save(file,'em','-append'); end
        if cost<bestCost, bestTheta=theta; bestCost=cost; bestInfo=info; bestRestart=restart; end
        if iter==1 || mod(iter,10)==0
            fprintf('restart %d iteration %d cost %.7g waypoint gap %.5f elapsed %.1f s\n', ...
                restart,iter,cost,info.minClearance,toc(timer));
        end
        if feasibleAccepted || (gateDue && info.minClearance>=c.margin-1e-9)
            [passed,~]=c.validationFcn(theta,context,scene,w,c.finalDenseJointStep,false);
            if passed && cost<feasibleCost
                feasibleTheta=theta; feasibleCost=cost; feasibleInfo=info; feasibleRestart=restart;
                termination='unified dense validation satisfied'; break;
            end
        end
        if iter>=c.minIterations && stall>=c.maxStallIterations
            fprintf('restart %d stopped after %d rounds without cost improvement\n',restart,stall);
            termination='maximum restarts or stagnation'; break;
        end
    end
    if ~isempty(feasibleTheta) || timedOut, break; end
end
if ~isempty(feasibleTheta)
    bestTheta=feasibleTheta; bestCost=feasibleCost; bestInfo=feasibleInfo; bestRestart=feasibleRestart;
end
r=struct('theta',bestTheta,'initial',initial,'cost',bestCost,'initialCost',initialCost, ...
    'initialMinClearance',initialInfo.minClearance,'history',history,'info',bestInfo, ...
    'restart',bestRestart,'termination',termination,'elapsedSeconds',toc(timer), ...
    'theta_animation',{animation},'success',~isempty(feasibleTheta));
assert(isequal(r.theta(:,1),scene.qStart) && isequal(r.theta(:,end),scene.qGoal));
end
