$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$release = Join-Path $repo 'artifacts\runs\task45_v2'
$finalLog = Join-Path $release 'finalize_log.txt'
while (-not ((Test-Path -LiteralPath $finalLog) -and (Select-String -LiteralPath $finalLog -SimpleMatch 'V2 STUDY AND EXPORT COMPLETE' -Quiet))) { Start-Sleep -Seconds 10 }
while (Get-CimInstance Win32_Process -Filter "Name = 'MATLAB.exe'" | Where-Object { $_.CommandLine -like '*finalize_task45_v2.m*' }) { Start-Sleep -Seconds 5 }
& py -3.12 scripts\check_task45_v1_preserved.py
if ($LASTEXITCODE -ne 0) { throw 'V1 preservation check failed' }
& py -3.12 scripts\build_task45_v2_delivery.py
if ($LASTEXITCODE -ne 0) { throw 'V2 materials build failed' }
& py -3.12 scripts\check_task45_v2_package.py
if ($LASTEXITCODE -ne 0) { throw 'V2 package validation failed' }
Write-Output 'V2 DELIVERY BUILT; rendered pages await visual review.'
