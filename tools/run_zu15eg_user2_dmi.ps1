param(
    [ValidateSet('dmstatus', 'dmcontrol', 'recover', 'full')]
    [string]$Mode = 'dmstatus',
    [string]$XsdbBin = 'D:\Xilinx\Vitis\2024.1\bin'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$xsdb = Join-Path $XsdbBin 'xsdb.bat'
if (-not (Test-Path $xsdb)) { throw "Tool not found: $xsdb" }
& $xsdb (Join-Path $PSScriptRoot 'zu15eg_user2_dmi.tcl') $Mode
if ($LASTEXITCODE -ne 0) { throw "ZU15EG USER2 DMI $Mode failed." }
