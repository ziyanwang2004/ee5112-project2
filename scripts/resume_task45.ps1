param([string]$MatlabExecutable='D:\Program Files\MATLAB\bin\matlab.exe',[switch]$DeliveryOnly)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$finalRoot=Join-Path $projectRoot 'artifacts\runs\task45_final'
if (-not (Test-Path -LiteralPath (Join-Path $finalRoot 'frozen_config.mat'))) { throw 'No frozen study.' }
$recoveryId='20261108_'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$environment=[ordered]@{
    clientDate='2026-11-08';recoveryId=$recoveryId;matlabExecutable=$MatlabExecutable
    processor=Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors
    operatingSystem=Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber
}
$environment | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $finalRoot ('recovery_environment_'+$recoveryId+'.json')) -Encoding UTF8
$batch=@"
addpath('matlab'); addpath('scripts');
root=fullfile(pwd,'artifacts','runs','task45_final');
env=struct('matlabRoot',matlabroot,'matlabVersion',version,'toolboxes',ver,'maxComputationalThreads',maxNumCompThreads);
if ~exist(fullfile(root,'matlab_recovery_environment.json'),'file'), memberC.writeJSON(fullfile(root,'matlab_recovery_environment.json'),env); end
test_task45_statistics(root);
summary=run_task45_benchmark();
audit=verify_task45(root);
memberC.writeJSON(fullfile(root,'independent_audit.json'),audit);
recoveryAudit=audit_task45_interruption(root);
memberC.writeJSON(fullfile(root,'recovery_audit.json'),recoveryAudit);
"@
if ($DeliveryOnly) {
    $batch=@"
addpath('matlab'); addpath('scripts');
root=fullfile(pwd,'artifacts','runs','task45_final');
prior=jsondecode(fileread(fullfile(root,'independent_audit.json')));
assert(prior.passed && prior.runs==54);
recoveryAudit=audit_task45_interruption(root);
memberC.writeJSON(fullfile(root,'recovery_audit.json'),recoveryAudit);
"@
}
& $MatlabExecutable -batch $batch -logfile (Join-Path (Split-Path $projectRoot -Parent) ('task45_recovery_'+$recoveryId+'.log'))
if ($LASTEXITCODE -ne 0) { throw 'Recovery stopped; preserve the new log and every run folder.' }
& py -3.12 scripts/build_task45_delivery.py
if ($LASTEXITCODE -ne 0) { throw 'Delivery generation failed.' }
& py -3.12 scripts/audit_task45_delivery.py
if ($LASTEXITCODE -ne 0) { throw 'Delivery audit failed.' }
Write-Output 'TASK45_RECOVERY_PIPELINE_COMPLETE'
