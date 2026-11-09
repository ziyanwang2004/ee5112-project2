$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$exe = 'D:\Program Files\MATLAB\bin\matlab.exe'
$release = Join-Path $repo 'artifacts\runs\task45_v3'
while (Get-CimInstance Win32_Process -Filter "Name = 'MATLAB.exe'" | Where-Object { $_.CommandLine -like '*task45_v3_development.log*' }) { Start-Sleep -Seconds 10 }
if (-not (Test-Path -LiteralPath (Join-Path $release 'frozen_config.mat'))) { throw 'Development gate did not freeze a configuration.' }
& $exe -batch "run('scripts/prepare_task45_v3_formal.m')" -logfile (Join-Path $release 'prepare_log.txt')
if ($LASTEXITCODE -ne 0) { throw 'Formal gate failed' }
$workers = @()
foreach ($worker in 0,1) {
    $code = "addpath('scripts'); run_task45_v3_worker($worker)"
    $log = Join-Path $release "worker_${worker}_log.txt"
    $workers += Start-Process -FilePath $exe -ArgumentList @('-batch',('"' + $code + '"'),'-logfile',('"' + $log + '"')) -WorkingDirectory $repo -WindowStyle Hidden -PassThru
}
foreach ($process in $workers) { $process.WaitForExit(); $process.Refresh(); if ($process.ExitCode -ne 0) { throw "Formal worker failed: $($process.Id)" } }
& $exe -batch "run('scripts/finalize_task45_v3.m')" -logfile (Join-Path $release 'finalize_log.txt')
if ($LASTEXITCODE -ne 0) { throw 'V3 audit or export failed' }
