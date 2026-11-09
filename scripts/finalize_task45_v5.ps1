$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$release=Join-Path $repo 'artifacts\runs\task45_v5'
$done=Join-Path $release 'pipeline_complete.txt'
while(-not(Test-Path -LiteralPath $done)) {
    $running=Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object { $_.CommandLine -like '*-File*resume_task45_v5.ps1*' }
    if(-not $running) { throw 'V5 controller stopped before independent audit completion. Inspect resume error log.' }
    Start-Sleep -Seconds 10
}
& py -3.12 -X utf8 scripts/crosscheck_task45_v5_numpy.py
if($LASTEXITCODE -ne 0) { throw 'V5 independent NumPy cross-check failed.' }
& py -3.12 -X utf8 scripts/summarize_task45_v5.py
if($LASTEXITCODE -ne 0) { throw 'V5 summary generation failed.' }
& 'D:\Program Files\MATLAB\bin\matlab.exe' -batch "addpath('scripts'); plot_task45_v5()" -logfile (Join-Path $release 'plot_log.txt')
if($LASTEXITCODE -ne 0) { throw 'V5 plot export/reopen failed.' }
Set-Content -LiteralPath (Join-Path $release 'postprocess_complete.txt') -Value 'Numerical checks, analysis and figure exports finished. Visual inspection is recorded separately in visual_qa.json; final inventory checks are in delivery_checks.json.' -Encoding UTF8
