root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v5');
base=load(fullfile(root,'artifacts','runs','task45_v3','frozen_config.mat'));
robot=memberC.loadRobot(); model=memberB.buildPoeModel(robot,'tool0'); geometry=memberB.loadUR5Spheres(model);
rows={};
for id={'workcell','endpoints','layout'}
    c=memberC.caseOptions(memberC.variantOptions(base.frozen.options,'fixed75'),id{1});
    scene=memberC.makeScene(model,c,id{1}); w=makeVoxelWorld(scene.boxes,c);
    context=struct('options',c,'geometry',geometry,'kinematics',struct('mode','poe','robot',robot,'model',model));
    endpoints=cell(1,2); Q=[scene.qStart,scene.qGoal];
    for k=1:2
        sc=scene; sc.qStart=Q(:,k); sc.qGoal=Q(:,k);
        [ok,v]=memberC.validatePath([Q(:,k),Q(:,k)],context,sc,w,.00625,true);
        endpoints{k}=struct('passed',ok,'gap',v.minVoxelClearance,'tilt',v.maxOrientationDeg,'failures',{v.failures});
    end
    initial=scene.qStart+(scene.qGoal-scene.qStart)*linspace(0,1,c.nWaypoints);
    cc=c; cc.denseJointStep=.0125; mesh=memberB.checkMatlabPath(robot,initial,scene,cc);
    lift=[scene.qStart(1);-1.5;.8;.7;-pi/2;0]; turn=lift; turn(1)=scene.qGoal(1);
    witness=[scene.qStart,lift,turn,scene.qGoal];
    [ok,v]=memberC.validatePath(witness,context,scene,w,.00625,true);
    passed=all(cellfun(@(x)x.passed,endpoints)) && ok && any(mesh.worldInCollision) && ~any(mesh.selfInCollision);
    rows{end+1}=struct('scenario',id{1},'passed',passed,'scene',scene,'endpoints',{endpoints}, ...
        'initialWorldCollisionStates',nnz(mesh.worldInCollision),'initialStates',mesh.nStates, ...
        'initialSelfCollisionStates',nnz(mesh.selfInCollision),'witnessPassed',ok,'witnessGap',v.minVoxelClearance, ...
        'witnessFailures',{v.failures}); %#ok<SAGROW>
    fprintf('SCENE %s passed=%d collision=%d/%d witnessGap=%.6f\n',id{1},passed,nnz(mesh.worldInCollision),mesh.nStates,v.minVoxelClearance);
end
receipt=struct('passed',all(cellfun(@(x)x.passed,rows)),'scenarios',{rows}, ...
    'witnessUse','Geometry-only feasibility proof. Never used as initialization, restart or optimizer output.');
memberC.writeJSON(fullfile(release,'geometry_preflight.json'),receipt); assert(receipt.passed,'Geometry preflight failed.');
