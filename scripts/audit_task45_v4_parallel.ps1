param([Parameter(Mandatory=$true)][string]$RunRoot,[Parameter(Mandatory=$true)][string]$ReceiptRoot)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$exe='D:\Program Files\MATLAB\bin\matlab.exe'
New-Item -ItemType Directory -Path $ReceiptRoot -Force | Out-Null
$groups=@(@('baseline','anytime'),@('tangent','combined'))
$children=@()
foreach ($index in 0,1) {
    $code="addpath('scripts'); "
    foreach ($variant in $groups[$index]) {
        $inputPath=(Join-Path $RunRoot $variant).Replace('\','/').Replace("'","''")
        $outputPath=(Join-Path $ReceiptRoot "$variant.json").Replace('\','/').Replace("'","''")
        $code+="audit_task45_v4('$inputPath','$outputPath'); "
    }
    $log=Join-Path $ReceiptRoot "worker_${index}_log.txt"
    $children+=Start-Process -FilePath $exe -ArgumentList @('-batch',('"'+$code+'"'),'-logfile',('"'+$log+'"')) -WorkingDirectory $repo -WindowStyle Hidden -PassThru
}
foreach ($child in $children) { $child.WaitForExit(); $child.Refresh(); if($child.ExitCode -ne 0) { throw "Independent audit worker failed: $($child.Id)" } }
