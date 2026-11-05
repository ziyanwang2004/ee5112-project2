% Completed from the received helperSTOMP.m. Keep its named STOMP stages.
% Required caller workspace: robot_struct, scene, context, voxel_world,
% plannerOptions, runFolder, poeModel, geometry and fk.
nDiscretize=plannerOptions.nWaypoints;
nPaths=plannerOptions.nRollouts;
convergenceThreshold=plannerOptions.convergenceThreshold;
q0=scene.qStart; qT=scene.qGoal; numJoints=numel(q0);
theta_initial=q0+(qT-q0)*linspace(0,1,nDiscretize);

% Retain the received metric construction and column-normalized M.
A=-2*eye(nDiscretize)+diag(ones(nDiscretize-1,1),1)+diag(ones(nDiscretize-1,1),-1);
A=A(:,2:end-1); R=A.'*A;
Rinv=R\eye(nDiscretize-2); Rinv=(Rinv+Rinv.')/2;
M=Rinv./max(Rinv,[],1)/nDiscretize;
% Scale normalized covariance in rad^2, rather than the template's tiny
% sum-normalization, so exploration matches the larger UR5 geometry.
covarianceShape=Rinv/max(diag(Rinv));
[~,initialCost,initialInfo]=stompTrajCost(robot_struct,theta_initial,R,voxel_world,context);
theta_animation={theta_initial}; history=[]; bestCost=inf;
stompTimer=tic; termination='maximum iterations'; success=false;
meshAcceptance=isfield(plannerOptions,'acceptanceMode') && strcmp(plannerOptions.acceptanceMode,'mesh');
traceFolder=fullfile(runFolder,'iterations');
if ~exist(traceFolder,'dir'), mkdir(traceFolder); end
for restart=1:plannerOptions.maxRestarts
    rng(plannerOptions.seed+restart-1,'twister');
    theta=theta_initial; Qtheta=initialCost; currentInfo=initialInfo;
    stall=0;
    for iter=1:plannerOptions.maxIterations
        thetaBefore=theta; rngBefore=rng;
        sigmaStd=plannerOptions.noiseStd*(.55+.45*(1-iter/plannerOptions.maxIterations));
        sigma=covarianceShape*sigmaStd^2;
        [theta_samples,em]=stompSamples(nPaths,sigma,theta,poeModel.limits);
        Stheta=zeros(nPaths,nDiscretize); sampleTotals=zeros(nPaths,1);
        for sampleIndex=1:nPaths
            [Stheta(sampleIndex,:),sampleTotals(sampleIndex)]= ...
                stompTrajCost(robot_struct,theta_samples{sampleIndex},R,voxel_world,context);
        end
        trajProb=stompUpdateProb(Stheta,plannerOptions.sensitivity);
        dtheta=stompDTheta(trajProb,em);
        [~,dtheta_smoothed]=stompUpdateTheta(theta,dtheta,M);
        sizeDelta=max(abs(dtheta_smoothed(:)));
        if sizeDelta>plannerOptions.maxUpdate
            dtheta=dtheta*plannerOptions.maxUpdate/sizeDelta;
        end
        [~,dtheta_smoothed]=stompUpdateTheta(theta,dtheta,M);
        proposedTheta=theta; proposedCost=Qtheta; proposedInfo=currentInfo;
        acceptedCode=0; acceptedAlpha=0; acceptedSample=0;
        for stepAlpha=[1 .5 .25]
            [candidate,~]=stompUpdateTheta(theta,stepAlpha*dtheta,M);
            candidate=max(poeModel.limits(:,1),min(poeModel.limits(:,2),candidate));
            candidate(:,1)=q0; candidate(:,end)=qT;
            [~,costCandidate,infoCandidate]=stompTrajCost(robot_struct,candidate,R,voxel_world,context);
            if costCandidate<proposedCost
                proposedTheta=candidate; proposedCost=costCandidate; proposedInfo=infoCandidate;
                acceptedCode=1; acceptedAlpha=stepAlpha;
            end
        end
        % Explicit best-rollout fallback retains merit-based descent when a
        % weighted mixture loses a useful sampled detour around the cube.
        [bestSampleCost,bestSample]=min(sampleTotals);
        if bestSampleCost<proposedCost
            proposedTheta=theta_samples{bestSample}; proposedCost=bestSampleCost;
            [~,~,proposedInfo]=stompTrajCost(robot_struct,proposedTheta,R,voxel_world,context);
            acceptedCode=2; acceptedAlpha=0; acceptedSample=bestSample;
        end
        QthetaOld=Qtheta;
        theta=proposedTheta; Qtheta=proposedCost; currentInfo=proposedInfo;
        if QthetaOld-Qtheta<convergenceThreshold, stall=stall+1; else, stall=0; end
        thetaAfter=theta; rngAfter=rng;
        metrics=[restart,iter,Qtheta,currentInfo.minClearance,currentInfo.smoothness,acceptedCode,acceptedAlpha];
        history(end+1,:)=metrics; %#ok<AGROW>
        theta_animation{end+1}=theta; %#ok<AGROW>
        traceFile=fullfile(traceFolder,sprintf('restart_%02d_iteration_%03d.mat',restart,iter));
        if plannerOptions.retainRollouts
            save(traceFile,'thetaBefore','thetaAfter','theta_samples','em','Stheta', ...
                'sampleTotals','trajProb','dtheta','dtheta_smoothed','metrics', ...
                'acceptedSample','rngBefore','rngAfter','sigma','R','M','-v7');
        else
            save(traceFile,'thetaBefore','thetaAfter','metrics','rngBefore','rngAfter','-v7');
        end
        if plannerOptions.verbose && (iter==1 || mod(iter,10)==0)
            fprintf('restart %d, iteration %d, cost %.9g, conservative voxel gap %.6f m\n', ...
                restart,iter,Qtheta,currentInfo.minClearance);
        end
        if iter>=plannerOptions.minIterations && (meshAcceptance || currentInfo.minClearance>=plannerOptions.margin) ...
                && (stall>=3 || mod(iter,5)==0)
            if meshAcceptance
                meshCheck=memberB.checkMatlabPath(context.kinematics.robot,theta,scene,plannerOptions);
                passed=meshCheck.worldCollisionFree;
            else
                denseVoxel=checkVoxelPath(theta,fk,geometry,voxel_world,plannerOptions.denseJointStep);
                passed=denseVoxel.minClearance>=plannerOptions.margin-1e-4;
            end
            if passed
                success=true;
                if meshAcceptance, termination='dense MATLAB mesh collision check satisfied';
                else, termination='dense voxel clearance satisfied'; end
                break;
            end
        end
    end
    if Qtheta<bestCost
        bestTheta=theta; bestCost=Qtheta; bestInfo=currentInfo; bestRestart=restart;
    end
    if success
        bestTheta=theta; bestCost=Qtheta; bestInfo=currentInfo; bestRestart=restart; break;
    end
end
theta=bestTheta;
plannerResult=struct('theta',theta,'initial',theta_initial,'cost',bestCost, ...
    'initialCost',initialCost,'initialMinClearance',initialInfo.minClearance, ...
    'history',history,'info',bestInfo,'restart',bestRestart,'termination',termination, ...
    'elapsedSeconds',toc(stompTimer),'theta_animation',{theta_animation});
plannerResult.voxelValidation=checkVoxelPath(theta,fk,geometry,voxel_world,plannerOptions.denseJointStep);
plannerResult.validation=memberB.checkSpherePath(theta,fk,geometry,scene,plannerOptions.denseJointStep);
plannerResult.success=plannerResult.voxelValidation.minClearance>=plannerOptions.margin-1e-4 ...
    && ~plannerResult.validation.inCollision;
plannerResult.proxyMarginSatisfied=plannerResult.success;
if meshAcceptance
    finalMeshCheck=memberB.checkMatlabPath(context.kinematics.robot,theta,scene,plannerOptions);
    plannerResult.success=finalMeshCheck.worldCollisionFree;
    if plannerResult.success, plannerResult.termination='dense MATLAB mesh collision check satisfied'; end
end
assert(isequal(theta(:,1),q0) && isequal(theta(:,end),qT),'Fixed endpoints changed.');
fprintf('Shared helperSTOMP finished: %s\n',plannerResult.termination);
