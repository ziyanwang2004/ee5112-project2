function audit=audit_task45_interruption(root)
% Read-only replay of incomplete attempts; never manufactures a final result.
events=dir(fullfile(root,'technical_interruptions','**','interruption_receipt.json'));
audit=struct('passed',true,'interruptedAttempts',numel(events),'replayedCheckpoints',0,'details',{{}});
state=rng; guard=onCleanup(@()rng(state)); %#ok<NASGU>
robot=loadrobot('universalUR5','DataFormat','column');
for eventIndex=1:numel(events)
    folder=events(eventIndex).folder;
    fid=fopen(fullfile(folder,events(eventIndex).name),'rb'); assert(fid>=0);
    bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    if numel(bytes)>=3 && isequal(bytes(1:3).',uint8([239 187 191])), bytes=bytes(4:end); end
    receipt=jsondecode(native2unicode(bytes.','UTF-8'));
    d=load(fullfile(folder,'input_checkpoint.mat')); c=d.plannerOptions;
    assert(~exist(fullfile(folder,'planning_result.mat'),'file'));
    assert(strcmp(receipt.sourceFingerprint,d.metadata.sourceFingerprint));
    context=struct('options',c,'geometry',d.geometry, ...
        'kinematics',struct('mode','poe','robot',robot,'model',d.poeModel));
    files=dir(fullfile(folder,'iterations','*.mat')); assert(numel(files)==receipt.checkpointCount);
    detail=struct('seed',receipt.seed,'mode',receipt.mode,'checkpoints',numel(files), ...
        'maxAcceptedReplayError',0,'retryCommonCheckpoints',0,'retryMaxThetaDifference',0, ...
        'retryRandomStatesIdentical',true,'completePlanningResult',false);
    previous=[];
    for k=1:numel(files)
        a=load(fullfile(files(k).folder,files(k).name)); rng(a.rngBefore);
        [samples,noise]=stompSamples(c.nRollouts,a.sigma,a.thetaBefore,d.poeModel.limits);
        [samples,noise,valid]=memberC.projectSamples(samples,noise,a.thetaBefore,context);
        assert(isequal(valid,a.validSamples) && isequal(rng,a.rngAfter));
        P=memberC.sampleProbabilities(a.Stheta,valid,c.sensitivity);
        assert(max(abs(P(:)-a.trajProb(:)))<1e-13);
        delta=stompDTheta(P,noise); [~,smooth]=stompUpdateTheta(a.thetaBefore,delta,a.M);
        if max(abs(smooth(:)))>c.maxUpdate, delta=delta*c.maxUpdate/max(abs(smooth(:))); end
        assert(max(abs(delta(:)-a.dtheta(:)))<1e-12);
        if a.metrics(6)==0
            q=a.thetaBefore;
        elseif a.metrics(6)==2
            q=samples{a.acceptedSample};
        else
            q=stompUpdateTheta(a.thetaBefore,a.metrics(7)*delta,a.M);
            q=max(d.poeModel.limits(:,1),min(d.poeModel.limits(:,2),q));
            q(:,1)=d.scene.qStart; q(:,end)=d.scene.qGoal;
            if ~isempty(c.projectionFcn), [q,ok]=c.projectionFcn(q,context); assert(ok); end
        end
        err=max(abs(q(:)-a.thetaAfter(:))); assert(err<1e-12);
        detail.maxAcceptedReplayError=max(detail.maxAcceptedReplayError,err);
        if ~isempty(previous) && a.metrics(1)==previous.restart
            assert(max(abs(a.thetaBefore(:)-previous.q(:)))<1e-12);
        end
        previous=struct('restart',a.metrics(1),'q',a.thetaAfter);
        retry=fullfile(root,receipt.originalPath,'iterations',files(k).name);
        if exist(retry,'file')
            b=load(retry); detail.retryCommonCheckpoints=detail.retryCommonCheckpoints+1;
            detail.retryMaxThetaDifference=max(detail.retryMaxThetaDifference,max(abs(a.thetaAfter(:)-b.thetaAfter(:))));
            detail.retryRandomStatesIdentical=detail.retryRandomStatesIdentical && ...
                isequal(a.rngBefore,b.rngBefore) && isequal(a.rngAfter,b.rngAfter);
        end
    end
    audit.replayedCheckpoints=audit.replayedCheckpoints+numel(files);
    audit.details{end+1}=detail;
    fprintf('INTERRUPTION AUDIT seed %d: %d checkpoints replayed, retry overlap %d, max theta difference %.3g\n', ...
        receipt.seed,numel(files),detail.retryCommonCheckpoints,detail.retryMaxThetaDifference);
end
end
