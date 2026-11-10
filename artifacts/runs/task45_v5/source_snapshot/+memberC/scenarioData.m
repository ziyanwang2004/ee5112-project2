function data=scenarioData(id)
assert(any(strcmp(id,{'workcell','endpoints','layout'})));
data.qStart=[-1.10;-1.05;1.35;-.30;-pi/2;0];
data.qGoal=[1.05;-.75;1.10;-.35;-pi/2;0];
data.boxes=[0 0 -.20 1 1 .20; ...
    .60 0 .325 .075 .10 .325; .30 -.23 .18 .09 .065 .18; ...
    .40 .24 .24 .08 .07 .24; .85 0 .35 .025 .45 .35];
data.description='Original mounted workcell, upright endpoints';
if strcmp(id,'endpoints')
    data.qStart=[-1.25;-1.10;1.40;-.30;-pi/2;0];
    data.qGoal=[1.20;-.70;1.05;-.35;-pi/2;0];
    data.description='Same workcell, independently changed upright endpoint pair';
elseif strcmp(id,'layout')
    data.boxes(2,1:2)=[.58 .025]; data.boxes(2,5)=.12;
    data.boxes(3,2)=-.20; data.boxes(4,2)=.21; data.boxes(5,1)=.82;
    data.description='Original endpoints, wider shifted rack and equipment moved inward';
end
end
