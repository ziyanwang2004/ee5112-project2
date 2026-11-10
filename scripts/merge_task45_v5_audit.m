function audit=merge_task45_v5_audit(runRoot,partsRoot,receiptPath)
% Recover a completed parallel audit whose waiting MATLAB parent was interrupted.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'upgrades','task45_v5','matlab'),'-begin');
identity=memberC.provenance(); cases={'workcell','endpoints','layout'}; variants={'ambient','energy_control','fixed50','fixed75','adaptive'};
audit=struct('passed',true,'runs',0,'successfulRuns',0,'fineSuccessfulRuns',0,'replayedCheckpoints',0, ...
    'recomputedSearchCosts',0,'verifiedRefineSampleCosts',0,'details',[],'fineDetails',[],'fineJointStep',.00625,'sourceFingerprint',identity.sourceFingerprint);
for id=cases
    for variant=variants
        p=jsondecode(fileread(fullfile(partsRoot,[id{1} '_' variant{1} '.json'])));
        assert(p.passed && strcmp(p.sourceFingerprint,identity.sourceFingerprint));
        files=dir(fullfile(runRoot,id{1},variant{1},'**','planning_result.mat')); assert(p.runs==numel(files));
        folders=sort(string({files.folder})); audited=sort(string({p.details.folder}));
        assert(isequal(lower(replace(folders,'\','/')),lower(replace(audited,'\','/'))));
        assert(all(strcmp({p.fineDetails.scenario},id{1})) && all(strcmp({p.fineDetails.variant},variant{1})));
        for name={'runs','successfulRuns','fineSuccessfulRuns','replayedCheckpoints','recomputedSearchCosts','verifiedRefineSampleCosts'}
            audit.(name{1})=audit.(name{1})+p.(name{1});
        end
        if isempty(audit.details), audit.details=p.details(:); else, audit.details=[audit.details;p.details(:)]; end
        if isempty(audit.fineDetails), audit.fineDetails=p.fineDetails(:); else, audit.fineDetails=[audit.fineDetails;p.fineDetails(:)]; end
    end
end
files=dir(fullfile(runRoot,'**','planning_result.mat')); assert(audit.runs==numel(files));
memberC.writeJSON(receiptPath,audit);
end
