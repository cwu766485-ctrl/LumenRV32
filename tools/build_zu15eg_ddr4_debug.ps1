param(
    [ValidateSet(1250)]
    [int]$DdrClockPs = 1250,
    [ValidateRange(1, 16)]
    [int]$Jobs = 4,
    [string]$VivadoPath = 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceProject = Join-Path $repoRoot 'docs\hardware\zu15eg\15eg_demo\1.mem_test\prj\mem_test'
$workProject = Join-Path $repoRoot 'build\zu15eg_pl_ddr4_debug'
$outDir = Join-Path $repoRoot 'build\zu15eg_pl_ddr4_debug_out'

if (-not (Test-Path -LiteralPath $sourceProject)) { throw "Missing vendor project: $sourceProject" }
if (-not (Test-Path -LiteralPath $VivadoPath)) { throw "Missing Vivado: $VivadoPath" }

Remove-Item -LiteralPath $workProject -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $outDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $workProject, $outDir -Force | Out-Null

# Copy only editable source/project inputs. Vivado regenerates cache, run and generated files under build/.
& robocopy $sourceProject $workProject /E /XD '.Xil' 'mem_test.cache' 'mem_test.runs' 'mem_test.gen'
if ($LASTEXITCODE -gt 7) { throw "robocopy failed with exit code $LASTEXITCODE" }

& $VivadoPath -mode batch -nolog -nojournal -source (Join-Path $PSScriptRoot 'build_zu15eg_ddr4_debug.tcl') `
    -tclargs $workProject $outDir $DdrClockPs $Jobs
if ($LASTEXITCODE -ne 0) { throw "Vivado failed with exit code $LASTEXITCODE" }

Write-Output "ZU15EG_DDR4_DEBUG_BIT=[Join-Path $outDir 'design_1_wrapper.bit']"
Write-Output "ZU15EG_DDR4_DEBUG_LTX=[Join-Path $outDir 'design_1_wrapper.ltx']"
