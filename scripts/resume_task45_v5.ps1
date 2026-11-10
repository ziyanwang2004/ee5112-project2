$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$exe='D:\Program Files\MATLAB\bin\matlab.exe'
$release=Join-Path $repo 'artifacts\runs\task45_v5'
while(Get-CimInstance Win32_Process -Filter "Name = 'MATLAB.exe'" | Where-Object { $_.CommandLine -like '*audit_task45_v5*development/*' }) { Start-Sleep -Seconds 10 }
if(-not(Test-Path -LiteralPath (Join-Path $release 'frozen_config.mat'))) {
    & $exe -batch "resumeCompletedAudit=true; run('scripts/freeze_task45_v5.m')" -logfile (Join-Path $release 'freeze_resume_log.txt')
    if($LASTEXITCODE -ne 0) { throw 'Resumed V5 freeze gate failed; no formal runs started.' }
}
if(Get-CimInstance Win32_Process -Filter "Name = 'MATLAB.exe'" | Where-Object { $_.CommandLine -like '*run_task45_v5_group*formal*' }) { throw 'Formal workers already running.' }
$workers=@()
foreach($worker in 0,1) {
    $code="addpath('scripts'); run_task45_v5_group('formal',$worker)"
    $log=Join-Path $release "formal_worker_${worker}_log.txt"
    $workers+=Start-Process -FilePath $exe -ArgumentList @('-batch',('"'+$code+'"'),'-logfile',('"'+$log+'"')) -WorkingDirectory $repo -WindowStyle Hidden -PassThru
}
foreach($process in $workers) { $process.WaitForExit(); $process.Refresh(); if($process.ExitCode -ne 0) { throw 'V5 formal worker failed.' } }
& $exe -batch "addpath('scripts'); audit_task45_v5(fullfile(pwd,'artifacts','runs','task45_v5','formal'),fullfile(pwd,'artifacts','runs','task45_v5','formal_audit.json'));" -logfile (Join-Path $release 'formal_audit_log.txt')
if($LASTEXITCODE -ne 0) { throw 'V5 independent formal audit failed.' }
Set-Content -LiteralPath (Join-Path $release 'pipeline_complete.txt') -Value 'Planning and independent formal audit completed.' -Encoding UTF8
