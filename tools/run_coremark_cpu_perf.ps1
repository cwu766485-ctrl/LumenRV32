[CmdletBinding()]
param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$PythonExe = "python",
    [string]$RiscvGccPrefix = "D:\riscv-toolchains\xpack-riscv-none-embed-gcc-10.2.0-1.2\bin\riscv-none-embed-",
    [string]$Snapshot = "coremark_cpu_perf",
    [int]$PredictorEntries = 32,
    [UInt64]$SimTimeoutNs = 2000000000
)

$ErrorActionPreference = "Stop"

if ($PredictorEntries -lt 1 -or (($PredictorEntries -band ($PredictorEntries - 1)) -ne 0)) {
    throw "PredictorEntries must be a positive power of two."
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$make = "C:\MinGW\bin\mingw32-make.exe"
$coremarkDir = Join-Path $root "tests\example\coremark"
$runner = Join-Path $root "tools\run_xsim_program.ps1"
$runDir = Join-Path $root ("build\coremark_cpu_perf_{0}" -f $PredictorEntries)
$binary = Join-Path $runDir "coremark_iter1_fast.bin"
$simDir = Join-Path $runDir "sim"

if (-not (Test-Path -LiteralPath $make)) {
    throw "MinGW make was not found: $make"
}

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

# This is a deterministic RTL performance window. It runs the actual CoreMark
# workloads once, then requests PMU completion before the official >=10-second
# reporting guard. It is for same-source A/B only, not formal CoreMark/MHz.
& $make -B -C $coremarkDir `
    ("RISCV_GCC_PREFIX={0}" -f $RiscvGccPrefix) `
    "COREMARK_ITERATIONS=1" `
    "COREMARK_EXTRA_CFLAGS=-DSIMULATION_FAST_EXIT"
if ($LASTEXITCODE -ne 0) {
    throw "CoreMark build failed."
}

Copy-Item -LiteralPath (Join-Path $coremarkDir "coremark.bin") -Destination $binary -Force
$sha256 = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash
Write-Host "CoreMark short-window SHA-256 = $sha256"

$output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner `
    -VivadoBin $VivadoBin `
    -PythonExe $PythonExe `
    -Snapshot $Snapshot `
    -BinaryPath $binary `
    -SimTimeoutNs $SimTimeoutNs `
    -CoreMarkDone `
    -SimDir $simDir `
    -ExtraDefines ("TinyriscvBranchPredictorEntries={0}" -f $PredictorEntries) 2>&1

$output | ForEach-Object { Write-Host $_ }
$text = $output | Out-String
if ($LASTEXITCODE -ne 0 -or $text -notmatch "TEST_PASS") {
    throw "CoreMark short-window simulation did not pass."
}
if ($text -notmatch "CoreMark ticks = (?<ticks>\d+)") {
    throw "CoreMark result did not contain ticks."
}
$ticks = $matches['ticks']
if ($text -notmatch "PMU cycle\s+= (?<cycles>\d+)") {
    throw "CoreMark result did not contain PMU cycle."
}
$cycles = $matches['cycles']

Write-Host ("COREMARK_CPU_PERF_PASS predictor_entries={0} ticks={1} pmu_cycle={2}" -f `
    $PredictorEntries, $ticks, $cycles)
