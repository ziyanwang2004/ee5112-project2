function c=defaults()
% Task 4/5 settings. Legacy sharedDefaults remains unchanged.
c=sharedDefaults();
c.qStart=[-1.10;-1.05;1.35;-.30;-pi/2;0];
c.qGoal=[1.05;-.75;1.10;-.35;-pi/2;0];
c.nWaypoints=61; c.nRollouts=64; c.maxIterations=200;
c.maxRestarts=3; c.maxWallSeconds=300;
c.maxStallIterations=10;
c.finalDenseJointStep=.0125; c.orientationToleranceDeg=5;
c.orientationWeight=200; c.constraintMode='none';
c.projectionToleranceDeg=1; c.projectionDamping=1e-3;
c.projectionMaxIterations=20; c.projectionMaxStep=.15;
c.validationFcn=@memberC.validatePath; c.projectionFcn=[];
c.showFigures=false; c.writeVideo=false;
c.selfWeight=60000; c.selfMargin=.005;
c.restartSeedStride=100000;
c.selfCheckJointStep=.05; c.maxFallbackSelfChecks=8;
c.version='task45_v3_mounted_workcell';
c.worldCorner=[-1 -1 -.4]; c.worldExtent=[2 2 2];
end
