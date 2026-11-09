root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(fullfile(root,'matlab')); addpath(fullfile(root,'matlab','tests'));
out=fullfile(root,'artifacts','audits','project_completion_20261109'); state=rng; guard=onCleanup(@()rng(state)); %#ok<NASGU>
count=0; strictCount=0; sampleError=0; noiseError=0; rngIdentical=true;
for task=1:3
    folder=fullfile(root,'artifacts','runs','final_r2023b',sprintf('Task%d',task));
    input=load(fullfile(folder,'input_checkpoint.mat')); files=dir(fullfile(folder,'iterations','*.mat'));
    for i=1:numel(files)
        a=load(fullfile(files(i).folder,files(i).name)); rng(a.rngBefore);
        [samples,noise]=stompSamples(numel(a.theta_samples),a.sigma,a.thetaBefore,input.poeModel.limits);
        exact=isequal(noise,a.em) && isequal(rng,a.rngAfter); rngIdentical=rngIdentical && isequal(rng,a.rngAfter);
        for k=1:numel(samples)
            sampleError=max(sampleError,max(abs(samples{k}(:)-a.theta_samples{k}(:)))); exact=exact && isequal(samples{k},a.theta_samples{k});
        end
        for j=1:numel(noise), noiseError=max(noiseError,max(abs(noise{j}(:)-a.em{j}(:)))); end
        count=count+1; strictCount=strictCount+exact;
    end
end
assert(count==30 && sampleError<1e-12 && noiseError<1e-12 && rngIdentical);
% Exercise the unchanged official strict verifier on a copy, never on evidence.
source=fullfile(root,'artifacts','runs','final_r2023b','Task1'); copy=fullfile(out,'linux_archive_strict_replay_copy');
assert(~exist(copy,'dir')); mkdir(copy); copyfile(fullfile(source,'input_checkpoint.mat'),copy); copyfile(fullfile(source,'iterations'),fullfile(copy,'iterations'));
strictPassed=false; strictMessage='';
try
    replay_saved_process(copy); strictPassed=true;
catch problem
    strictMessage=problem.message;
    assert(contains(strictMessage,'Sample replay mismatch') || contains(strictMessage,'RNG replay mismatch'),'Unexpected replay failure.');
end
receipt=struct('checkpoints',count,'bitwiseIdenticalCheckpoints',strictCount,'sampleMaxAbsError',sampleError, ...
    'noiseMaxAbsError',noiseError,'rngIdentical',rngIdentical,'numericalToleranceForThisDiagnostic',1e-12, ...
    'numericalDiagnosticPassed',true,'unchangedStrictVerifierPassed',strictPassed,'strictVerifierMessage',strictMessage, ...
    'originalsUnmodified',true,'interpretation','Additional portability diagnostic; does not replace or relax the original strict verifier.');
memberC.writeJSON(fullfile(out,'portability_audit.json'),receipt);
fprintf('PORTABILITY AUDIT: max sample %.17g, strict archive pass %d, RNG identical %d\n',sampleError,strictPassed,rngIdentical);
