$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$exe='D:\Program Files\MATLAB\bin\matlab.exe'
$release=Join-Path $repo 'artifacts\runs\task45_v5'
& $exe -batch "run('scripts/test_task45_v5.m'); run('scripts/regress_task45_v5.m'); run('scripts/sample_task45_v5_ablation.m')" -logfile (Join-Path $release 'sampling_preflight_log.txt')
if($LASTEXITCODE -ne 0) { throw 'V5 unit/regression/sampling preflight failed.' }
foreach($stage in 'development','formal') {
    if($stage -eq 'formal') {
        & $exe -batch "run('scripts/freeze_task45_v5.m')" -logfile (Join-Path $release 'freeze_log.txt')
        if($LASTEXITCODE -ne 0) { throw 'V5 development/freeze gate failed; no formal runs started.' }
    }
    $workers=@()
    foreach($worker in 0,1) {
        $code="addpath('scripts'); run_task45_v5_group('$stage',$worker)"
        $log=Join-Path $release "${stage}_worker_${worker}_log.txt"
        $workers+=Start-Process -FilePath $exe -ArgumentList @('-batch',('"'+$code+'"'),'-logfile',('"'+$log+'"')) -WorkingDirectory $repo -WindowStyle Hidden -PassThru
    }
    foreach($process in $workers) { $process.WaitForExit(); $process.Refresh(); if($process.ExitCode -ne 0) { throw "V5 $stage worker failed." } }
}
& $exe -batch "addpath('scripts'); audit_task45_v5(fullfile(pwd,'artifacts','runs','task45_v5','formal'),fullfile(pwd,'artifacts','runs','task45_v5','formal_audit.json'));" -logfile (Join-Path $release 'formal_audit_log.txt')
if($LASTEXITCODE -ne 0) { throw 'V5 independent formal audit failed.' }
