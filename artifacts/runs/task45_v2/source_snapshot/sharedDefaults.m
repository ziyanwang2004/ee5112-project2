function c=sharedDefaults()
% Shared project settings. Target release is deliberately fixed to R2023b.
c.robotName='universalUR5'; c.endEffector='tool0';
c.qStart=[-.90;-.85;1.25;-1.95;-pi/2;0];
c.qGoal=[.90;-.85;1.25;-1.95;-pi/2;0];
c.nWaypoints=41; c.nRollouts=32; c.maxIterations=100; c.maxRestarts=3;
c.seed=5112; c.noiseStd=.55; c.maxUpdate=.30; c.minIterations=10;
c.sensitivity=10; c.convergenceThreshold=1e-7;
c.margin=.035; c.obstacleWeight=3000; c.stationaryWeight=20;
c.smoothWeight=1; c.denseJointStep=.025; c.cubeSide=.16;
c.worldCorner=[-1 -1 -1]; c.worldExtent=[2 2 2];
c.voxelSize=[.02 .02 .02];
c.constraintFcn=[]; c.showFigures=true; c.writeVideo=true;
c.retainRollouts=true; c.verbose=true;
end
