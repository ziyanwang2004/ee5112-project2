root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
addpath(fullfile(root,'upgrades','task45_v4','matlab'),'-begin');
release=fullfile(root,'artifacts','runs','task45_v4'); rows={};
comparisons={{'baseline','anytime'},{'tangent','combined'}};
for index=1:2
    names=comparisons{index};
    for seed=5600:5609
        a=load(fullfile(release,'formal',names{1},'workcell','Task5',sprintf('seed_%d',seed),'planning_result.mat'));
        b=load(fullfile(release,'formal',names{2},'workcell','Task5',sprintf('seed_%d',seed),'planning_result.mat'));
        count=min(size(a.result.history,1),size(b.result.history,1));
        difference=max(abs(a.result.history(1:count,:)-b.result.history(1:count,:)),[],'all');
        assert(difference<1e-9,'Anytime toggle changed the primary-search trace.');
        sameFirst=NaN; firstError=NaN; bitwise=NaN;
        if a.result.success && b.result.success
            firstError=max(abs(a.result.searchTheta(:)-b.result.searchTheta(:)));
            sameFirst=firstError<1e-12; bitwise=isequal(a.result.searchTheta,b.result.searchTheta); assert(sameFirst);
        end
        rows{end+1}=struct('a',names{1},'b',names{2},'seed',seed,'commonSearchIterations',count, ...
            'maxHistoryDifference',difference,'bothSuccessful',a.result.success&&b.result.success,'sameFirstSolution',sameFirst, ...
            'firstSolutionMaxError',firstError,'bitwiseFirstSolution',bitwise); %#ok<SAGROW>
    end
end
memberC.writeJSON(fullfile(release,'paired_prefix_audit.json'),struct('passed',true,'pairs',20,'details',{rows}));
fprintf('V4 PAIRED PRIMARY-SEARCH PREFIXES PASSED\n');
