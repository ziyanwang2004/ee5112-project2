function c=defaults()
% Task 4/5 settings. Legacy sharedDefaults remains unchanged.
c=sharedDefaults();
c.qStart=[-1.4;-.85;1.25;-.4;-pi/2;0];
c.qGoal=[1.4;-.85;1.25;-.4;-pi/2;0];
c.nWaypoints=61; c.nRollouts=64; c.maxIterations=200;
c.maxRestarts=3; c.maxWallSeconds=300;
c.maxStallIterations=10;
c.finalDenseJointStep=.0125; c.orientationToleranceDeg=5;
c.orientationWeight=200; c.constraintMode='none';
c.projectionToleranceDeg=1; c.projectionDamping=1e-3;
c.projectionMaxIterations=20; c.projectionMaxStep=.15;
c.validationFcn=@memberC.validatePath; c.projectionFcn=[];
c.showFigures=false; c.writeVideo=false;
end
