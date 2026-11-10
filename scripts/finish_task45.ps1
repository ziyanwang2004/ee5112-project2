param([int]$DevelopmentProcessId=0)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$matlabExe='D:\Program Files\MATLAB\bin\matlab.exe'
$finalRoot=Join-Path $projectRoot 'artifacts\runs\task45_final'
while ($DevelopmentProcessId -gt 0) {
    $developmentWorker=Get-CimInstance Win32_Process -Filter "ProcessId=$DevelopmentProcessId"
    if (-not $developmentWorker -or $developmentWorker.CommandLine -notlike '*develop_task45*') { break }
    Start-Sleep -Seconds 5
}
if (-not (Test-Path -LiteralPath (Join-Path $finalRoot 'frozen_config.mat'))) { throw 'Development did not pass; formal study was not started.' }
$environment=[ordered]@{
    matlabExecutable=$matlabExe
    processor=Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed
    operatingSystem=Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,TotalVisibleMemorySize
    timestampUtc=[DateTime]::UtcNow.ToString('o')
}
$environment | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $finalRoot 'windows_environment.json') -Encoding UTF8
& py -3.12 scripts/archive_task45_receipts.py
if ($LASTEXITCODE -ne 0) { throw 'Receipt archive failed.' }
$batch=@"
addpath('matlab');
root=fullfile(pwd,'artifacts','runs','task45_final');
env=struct('matlabRoot',matlabroot,'matlabVersion',version,'toolboxes',ver,'maxComputationalThreads',maxNumCompThreads);
memberC.writeJSON(fullfile(root,'matlab_environment.json'),env);
f=load(fullfile(root,'frozen_config.mat'));
priority=verify_task45(fullfile(f.frozen.developmentRoot,'profile_1','main','Task4','seed_5114'));
memberC.writeJSON(fullfile(root,'feasible_priority_independent_audit.json'),priority);
demoAudit=verify_task45(fullfile(root,'demos'));
assert(demoAudit.passed && demoAudit.successfulRuns==4);
memberC.writeJSON(fullfile(root,'demonstration_audit.json'),demoAudit);
export_task45(fullfile(root,'demos'),true);
summary=run_task45_benchmark();
formalAudit=verify_task45(fullfile(root,'formal'));
audit=demoAudit;
audit.passed=demoAudit.passed && formalAudit.passed;
audit.runs=demoAudit.runs+formalAudit.runs;
audit.successfulRuns=demoAudit.successfulRuns+formalAudit.successfulRuns;
audit.replayedCheckpoints=demoAudit.replayedCheckpoints+formalAudit.replayedCheckpoints;
audit.details=[demoAudit.details;formalAudit.details];
memberC.writeJSON(fullfile(root,'independent_audit.json'),audit);
"@
& $matlabExe -batch $batch -logfile (Join-Path (Split-Path $projectRoot -Parent) 'task45_final_pipeline.log')
if ($LASTEXITCODE -ne 0) { throw 'MATLAB final pipeline stopped; preserve all output and diagnose before resuming.' }
& py -3.12 scripts/build_task45_delivery.py
if ($LASTEXITCODE -ne 0) { throw 'Report or presentation export failed.' }
& py -3.12 scripts/audit_task45_delivery.py
if ($LASTEXITCODE -ne 0) { throw 'Delivery audit failed.' }
Write-Output 'TASK45_PIPELINE_COMPLETE'
