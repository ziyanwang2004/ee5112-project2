function summary=aggregateStudy(rows,activeMode)
summary=struct('totalRuns',numel(rows),'successfulRuns',nnz([rows.success]),'groups',[],'paired',[]);
keys=arrayfun(@(r)[r.scenario '_' r.mode],rows,'UniformOutput',false); groups=unique(keys,'stable');
for k=1:numel(groups)
    selected=rows(strcmp(keys,groups{k})); ok=selected([selected.success]);
    item=struct('name',groups{k},'n',numel(selected),'successes',numel(ok),'successRate',numel(ok)/numel(selected), ...
        'plannerSecondsAll',stats([selected.plannerSeconds]),'maxTiltSuccessful',stats([ok.maxOrientationDeg]), ...
        'meanTiltSuccessful',stats([ok.meanOrientationDeg]),'minVoxelSuccessful',stats([ok.minVoxelClearance]), ...
        'jointLengthSuccessful',stats([ok.jointPathLength]),'toolLengthSuccessful',stats([ok.toolPathLength]), ...
        'smoothnessSuccessful',stats([ok.smoothness]));
    item.failureCounts=struct();
    for reason={'endpoints','joint_limits','proxy_margin','orientation','world_collision','self_collision'}
        item.failureCounts.(reason{1})=sum(arrayfun(@(r)any(strcmp(r.failures,reason{1})),selected));
    end
    if isempty(summary.groups), summary.groups=item; else, summary.groups(end+1)=item; end
end
for id={'main','variant'}
    a=rows(strcmp({rows.scenario},id{1}) & strcmp({rows.mode},'none'));
    b=rows(strcmp({rows.scenario},id{1}) & strcmp({rows.mode},activeMode));
    seeds=intersect([a([a.success]).seed],[b([b.success]).seed]);
    da=[]; db=[]; dt=[]; differences=zeros(0,6);
    for seed=seeds(:).'
        aa=a([a.seed]==seed); bb=b([b.seed]==seed);
        da(end+1)=aa.maxOrientationDeg; db(end+1)=bb.maxOrientationDeg; %#ok<AGROW>
        dt(end+1)=bb.plannerSeconds-aa.plannerSeconds; %#ok<AGROW>
        differences(end+1,:)=[bb.meanOrientationDeg-aa.meanOrientationDeg, ...
            bb.minVoxelClearance-aa.minVoxelClearance,bb.minMeshClearance-aa.minMeshClearance, ...
            bb.jointPathLength-aa.jointPathLength,bb.toolPathLength-aa.toolPathLength,bb.smoothness-aa.smoothness]; %#ok<AGROW>
    end
    item=struct('scenario',id{1},'commonSuccessfulSeeds',seeds,'n',numel(seeds), ...
        'unconstrainedMaxTilt',stats(da),'constrainedMaxTilt',stats(db),'pairedTimeDifference',stats(dt));
    item.differenceBminusA=struct('meanTilt',stats(differences(:,1).'), ...
        'minVoxelClearance',stats(differences(:,2).'),'minMeshClearance',stats(differences(:,3).'), ...
        'jointLength',stats(differences(:,4).'),'toolLength',stats(differences(:,5).'),'smoothness',stats(differences(:,6).'));
    if isempty(summary.paired), summary.paired=item; else, summary.paired(end+1)=item; end
end
end
function s=stats(x)
x=sort(x); s=struct('n',numel(x),'median',NaN,'q25',NaN,'q75',NaN,'min',NaN,'max',NaN);
if isempty(x), return; end
s.median=median(x); s.min=min(x); s.max=max(x);
if numel(x)==1, s.q25=x; s.q75=x;
else, s.q25=interp1(1:numel(x),x,1+.25*(numel(x)-1)); s.q75=interp1(1:numel(x),x,1+.75*(numel(x)-1)); end
end
