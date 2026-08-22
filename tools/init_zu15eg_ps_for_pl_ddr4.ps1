param(
    [string]$XsctBin = "D:\Xilinx\Vitis\2024.1\bin",
    [string]$Fsbl = "docs\hardware\zu15eg\15eg_demo\1.mem_test\prj\mem_test\mem_test.vitis\design_1_wrapper\export\design_1_wrapper\sw\design_1_wrapper\boot\fsbl.elf",
    [string]$Xsa = "docs\hardware\zu15eg\15eg_demo\1.mem_test\prj\mem_test\mem_test.vitis\design_1_wrapper\export\design_1_wrapper\hw\design_1_wrapper.xsa",
    [string]$PsuInit = "docs\hardware\zu15eg\15eg_demo\1.mem_test\prj\mem_test\mem_test.vitis\design_1_wrapper\export\design_1_wrapper\hw\psu_init.tcl",
    [string]$PmuFw = "docs\hardware\zu15eg\15eg_demo\1.mem_test\prj\mem_test\mem_test.vitis\design_1_wrapper\export\design_1_wrapper\sw\design_1_wrapper\boot\pmufw.elf",
    [string]$Report = "build\zu15eg_ps_ddr4_init.txt",
    [switch]$SkipSystemReset,
    [switch]$ResetOnly
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$xsct = Join-Path $XsctBin "xsct.bat"
if (-not [System.IO.Path]::IsPathRooted($Fsbl)) { $Fsbl = Join-Path $root $Fsbl }
if (-not [System.IO.Path]::IsPathRooted($Xsa)) { $Xsa = Join-Path $root $Xsa }
if (-not [System.IO.Path]::IsPathRooted($PsuInit)) { $PsuInit = Join-Path $root $PsuInit }
if (-not [System.IO.Path]::IsPathRooted($PmuFw)) { $PmuFw = Join-Path $root $PmuFw }
if (-not [System.IO.Path]::IsPathRooted($Report)) { $Report = Join-Path $root $Report }
foreach ($item in @($xsct, $Fsbl, $Xsa, $PsuInit, $PmuFw)) { if (-not (Test-Path -LiteralPath $item)) { throw "Required input not found: $item" } }

$reportDir = Split-Path -Parent $Report
if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir | Out-Null }
$skipResetArg = if ($SkipSystemReset) { "1" } else { "0" }
$resetOnlyArg = if ($ResetOnly) { "1" } else { "0" }
& $xsct (Join-Path $PSScriptRoot "init_zu15eg_ps_for_pl_ddr4.tcl") `
    $Fsbl.Replace('\', '/') $Xsa.Replace('\', '/') $PsuInit.Replace('\', '/') `
    $PmuFw.Replace('\', '/') $Report.Replace('\', '/') `
    $skipResetArg $resetOnlyArg
if ($LASTEXITCODE -ne 0) { throw "ZU15EG PS/FSBL initialization failed." }
