$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$exe = 'D:\Program Files\MATLAB\bin\matlab.exe'
$release = Join-Path $repo 'artifacts\runs\task45_v4'
while (Get-CimInstance Win32_Process -Filter "Name = 'MATLAB.exe'" | Where-Object { $_.CommandLine -like '*run_task45_v4_group*development*' }) { Start-Sleep -Seconds 10 }
& $exe -batch "run('scripts/freeze_task45_v4.m')" -logfile (Join-Path $release 'freeze_log.txt')
if ($LASTEXITCODE -ne 0) { throw 'V4 development/audit/freeze gate failed. No formal runs started.' }
$workers = @()
foreach ($worker in 0,1) {
    $code = "addpath('scripts'); run_task45_v4_group('formal',$worker)"
    $workers += Start-Process -FilePath $exe -ArgumentList @('-batch',('"'+$code+'"'),'-logfile',('"'+(Join-Path $release "formal_worker_${worker}_log.txt")+'"')) -WorkingDirectory $repo -WindowStyle Hidden -PassThru
}
foreach ($process in $workers) { $process.WaitForExit(); $process.Refresh(); if ($process.ExitCode -ne 0) { throw 'V4 formal worker failed.' } }
& $exe -batch "addpath('scripts'); audit_task45_v4(fullfile(pwd,'artifacts','runs','task45_v4','formal'),fullfile(pwd,'artifacts','runs','task45_v4','formal_audit.json'));" -logfile (Join-Path $release 'formal_audit_log.txt')
if ($LASTEXITCODE -ne 0) { throw 'V4 independent formal audit failed.' }
