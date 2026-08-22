param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Probes = "docs\hardware\zu15eg\15eg_demo\1.mem_test\prj\mem_test\mem_test.runs\impl_1\design_1_wrapper.ltx",
    [string]$Report = "build\zu15eg_hw_ila_inventory.txt"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$vivado = Join-Path $VivadoBin "vivado.bat"
if (-not [System.IO.Path]::IsPathRooted($Probes)) { $Probes = Join-Path $root $Probes }
if (-not [System.IO.Path]::IsPathRooted($Report)) { $Report = Join-Path $root $Report }
if (-not (Test-Path -LiteralPath $vivado)) { throw "Vivado not found: $vivado" }
if (-not (Test-Path -LiteralPath $Probes)) { throw "Probe file not found: $Probes" }

$reportDir = Split-Path -Parent $Report
if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir | Out-Null }
& $vivado -mode batch -nolog -nojournal -source (Join-Path $PSScriptRoot "read_zu15eg_hw_ila.tcl") -tclargs $Probes.Replace('\', '/') $Report.Replace('\', '/')
if ($LASTEXITCODE -ne 0) { throw "ZU15EG ILA inventory failed." }
