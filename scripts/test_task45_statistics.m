function test_task45_statistics(root)
% Statistical fixtures only. Never changes a saved planning result.
files=dir(fullfile(root,'formal','**','summary.json')); rows=struct([]);
for k=1:numel(files)
    r=jsondecode(fileread(fullfile(files(k).folder,files(k).name)));
    if isempty(rows), rows=r; else, rows(end+1)=r; end
end
summary=memberC.aggregateStudy(rows,'projected');
assert(summary.totalRuns==50 && all([summary.paired.n]==0));
assert(all(arrayfun(@(p)isnan(p.pairedTimeDifference.median),summary.paired)));
% A column-shaped fixture with two common seeds exercises scalar iteration.
a=rows(strcmp({rows.scenario},'main') & strcmp({rows.mode},'none'));
b=rows(strcmp({rows.scenario},'main') & strcmp({rows.mode},'projected'));
a1=a(1); a2=a(2); b1=b(1); b2=b(2);
a1.seed=9001; a2.seed=9002; b1.seed=9001; b2.seed=9002;
b1.success=true; b2.success=true; b1.failures={}; b2.failures={};
b1.plannerSeconds=a1.plannerSeconds+2; b2.plannerSeconds=a2.plannerSeconds+5;
fixture=memberC.aggregateStudy([a1;a2;b1;b2],'projected');
assert(fixture.paired(1).n==2 && fixture.paired(1).pairedTimeDifference.median==3.5);
assert(fixture.paired(2).n==0);
fprintf('STATISTICS REGRESSION PASSED: zero pairs and two column-shaped pairs.\n');
end
