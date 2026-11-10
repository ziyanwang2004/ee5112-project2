param([Parameter(Mandatory=$true)][string]$RunRoot,[Parameter(Mandatory=$true)][string]$ReceiptRoot)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$exe='D:\Program Files\MATLAB\bin\matlab.exe'
New-Item -ItemType Directory -Path $ReceiptRoot -Force | Out-Null
$jobs=@()
foreach($case in 'workcell','endpoints','layout') {
    foreach($arm in 'ambient','energy_control','fixed50','fixed75','adaptive') {
        $jobs+=@{Case=$case;Arm=$arm}
    }
}
$children=@()
foreach($worker in 0,1) {
    $code="addpath('scripts'); "
    for($index=$worker;$index -lt $jobs.Count;$index+=2) {
        $job=$jobs[$index]
        $inputPath=(Join-Path (Join-Path $RunRoot $job.Case) $job.Arm).Replace('\','/').Replace("'","''")
        $outputPath=(Join-Path $ReceiptRoot ($job.Case+'_'+$job.Arm+'.json')).Replace('\','/').Replace("'","''")
        $code+="audit_task45_v5('$inputPath','$outputPath'); "
    }
    $log=Join-Path $ReceiptRoot "worker_${worker}_log.txt"
    $children+=Start-Process -FilePath $exe -ArgumentList @('-batch',('"'+$code+'"'),'-logfile',('"'+$log+'"')) -WorkingDirectory $repo -WindowStyle Hidden -PassThru
}
foreach($child in $children) { $child.WaitForExit(); $child.Refresh(); if($child.ExitCode -ne 0) { throw 'V5 independent audit worker failed.' } }
