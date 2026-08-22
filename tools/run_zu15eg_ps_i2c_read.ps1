param(
    [string]$Elf = 'build\zu15eg_ps_i2c_read\zu15eg_ps_i2c_read.elf',
    [string]$OutDir = 'build\zu15eg_ps_i2c_read'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not [System.IO.Path]::IsPathRooted($Elf)) { $Elf = Join-Path $root $Elf }
if (-not [System.IO.Path]::IsPathRooted($OutDir)) { $OutDir = Join-Path $root $OutDir }
$demo = Join-Path $root 'docs\hardware\zu15eg\15eg_demo\6.qspi_test\prj\qspi_test\qspi_test.vitis\top\export\top'
$fsbl = Join-Path $demo 'sw\top\boot\fsbl.elf'
$pmufw = Join-Path $demo 'sw\top\boot\pmufw.elf'
$xsa = Join-Path $demo 'hw\design_1_wrapper.xsa'
$psuInit = Join-Path $demo 'hw\psu_init.tcl'
$initReport = Join-Path $OutDir 'ps_init.txt'
$report = Join-Path $OutDir 'i2c_eeprom_read_report.txt'
foreach ($item in @($Elf, $fsbl, $pmufw, $xsa, $psuInit)) { if (-not (Test-Path -LiteralPath $item)) { throw "Required input not found: $item" } }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
& 'D:\Xilinx\Vitis\2024.1\bin\xsct.bat' (Join-Path $PSScriptRoot 'run_zu15eg_ps_i2c_read.tcl') `
    $fsbl.Replace('\','/') $xsa.Replace('\','/') $psuInit.Replace('\','/') $pmufw.Replace('\','/') `
    $initReport.Replace('\','/') $Elf.Replace('\','/') $report.Replace('\','/')
if ($LASTEXITCODE -ne 0) { throw 'ZU15EG PS I2C EEPROM read failed.' }
Get-Content -LiteralPath $report
