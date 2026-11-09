function [r,R,M]=plan(robot,scene,context,w,folder)
% V3-compatible search, followed by optional feasible-only refinement.
timer=tic; c=context.options;
[r,R,M]=memberC.planSearch(robot,scene,context,w,folder);
r.searchTheta=r.theta; r.searchCost=r.cost; r.searchSeconds=r.elapsedSeconds;
r.firstFeasibleSeconds=NaN; r.firstFeasibleQuality=NaN;
r.refinement=struct('iterations',0,'accepted',0,'elapsedSeconds',0,'qualityBefore',NaN, ...
    'qualityAfter',NaN,'history',zeros(0,8),'reason','not requested or no feasible search path');
[~,r.finalQuality,r.finalQualityComponents]=memberC.qualityCost(r.theta,context,w);
if r.success
    r.firstFeasibleSeconds=r.searchSeconds; r.firstFeasibleQuality=r.finalQuality;
    if c.anytimeEnabled
        remaining=max(0,c.maxWallSeconds-toc(timer));
        [r.theta,r.refinement]=memberC.refinePath(r.theta,R,M,context,scene,w,folder,remaining);
        [~,r.cost,r.info]=stompTrajCost(robot,r.theta,R,w,context);
        [~,r.finalQuality,r.finalQualityComponents]=memberC.qualityCost(r.theta,context,w);
        r.termination=['first feasible; refinement: ' r.refinement.reason];
    end
end
r.elapsedSeconds=toc(timer); r.variant=c.variant;
r.totalIterations=size(r.history,1)+r.refinement.iterations;
assert(~r.success || r.finalQuality<=r.firstFeasibleQuality+1e-9,'Feasible incumbent quality regressed.');
end
