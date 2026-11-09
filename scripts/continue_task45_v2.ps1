$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$exe = 'D:\Program Files\MATLAB\bin\matlab.exe'
Set-Location -LiteralPath $repo
$receiptRoot = Join-Path $repo 'artifacts\runs\task45_v2'
while (Get-CimInstance Win32_Process -Filter "Name = 'MATLAB.exe'" | Where-Object { $_.CommandLine -like '*task45_v2_self_filter.log*' }) { Start-Sleep -Seconds 10 }
& $exe -batch "run('scripts/freeze_task45_v2.m')" -logfile (Join-Path $receiptRoot 'freeze_log.txt')
if ($LASTEXITCODE -ne 0) { throw 'V2 development or freeze gate failed' }
$workers = @()
foreach ($worker in 0,1) {
    $log = Join-Path $receiptRoot "worker_${worker}_log.txt"
    $code = "addpath('scripts'); run_task45_v2_worker($worker)"
    $workers += Start-Process -FilePath $exe -ArgumentList @('-batch',('"' + $code + '"'),'-logfile',('"' + $log + '"')) -WorkingDirectory $repo -WindowStyle Hidden -PassThru
}
foreach ($process in $workers) { $process.WaitForExit(); $process.Refresh(); if ($process.ExitCode -ne 0) { throw "V2 worker failed: $($process.Id)" } }
& $exe -batch "run('scripts/finalize_task45_v2.m')" -logfile (Join-Path $receiptRoot 'finalize_log.txt')
if ($LASTEXITCODE -ne 0) { throw 'V2 verification or export failed' }
