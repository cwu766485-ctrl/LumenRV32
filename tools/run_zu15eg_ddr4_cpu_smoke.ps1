param(
    [string]$XsctBin = "D:\Xilinx\Vitis\2024.1\bin",
    [string]$Elf = "build\zu15eg_ddr4_cpu_smoke\zu15eg_ddr4_cpu_smoke.elf",
    [string]$Report = "build\zu15eg_ddr4_cpu_smoke\board_report.txt"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$xsct = Join-Path $XsctBin "xsct.bat"
if (-not [System.IO.Path]::IsPathRooted($Elf)) { $Elf = Join-Path $root $Elf }
if (-not [System.IO.Path]::IsPathRooted($Report)) { $Report = Join-Path $root $Report }
foreach ($item in @($xsct, $Elf)) {
    if (-not (Test-Path -LiteralPath $item)) { throw "Required input not found: $item" }
}

$reportDir = Split-Path -Parent $Report
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
& $xsct (Join-Path $PSScriptRoot "run_zu15eg_ddr4_cpu_smoke.tcl") `
    $Elf.Replace('\', '/') $Report.Replace('\', '/')
if ($LASTEXITCODE -ne 0) { throw "ZU15EG controlled DDR4 CPU smoke failed." }
