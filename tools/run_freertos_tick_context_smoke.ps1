[CmdletBinding()]
param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$PythonExe = "python",
    [string]$RiscvGccPrefix = "D:\riscv-toolchains\xpack-riscv-none-embed-gcc-10.2.0-1.2\bin\riscv-none-embed-",
    [string]$Snapshot = "freertos_tick_context_smoke",
    [UInt64]$SimTimeoutNs = 1000000
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$make = "C:\MinGW\bin\mingw32-make.exe"
$freertosDir = Join-Path $root "tests\example\FreeRTOS\Demo\tinyriscv_GCC"
$runner = Join-Path $root "tools\run_xsim_program.ps1"
$simDir = Join-Path $root "build\freertos_tick_context_smoke\sim"

if (-not (Test-Path -LiteralPath $make)) {
    throw "MinGW make was not found: $make"
}

# Do not pass CFLAGS on the command line: that would override common.mk's
# -march=rv32im and could silently emit unsupported RVC instructions.
& $make -B -C $freertosDir ("RISCV_GCC_PREFIX={0}" -f $RiscvGccPrefix) "SIMULATION=1"
if ($LASTEXITCODE -ne 0) {
    throw "FreeRTOS RV32IM build failed."
}

$output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner `
    -VivadoBin $VivadoBin `
    -PythonExe $PythonExe `
    -Snapshot $Snapshot `
    -BinaryPath (Join-Path $freertosDir "freertos.bin") `
    -SimTimeoutNs $SimTimeoutNs `
    -SimDir $simDir 2>&1

$output | ForEach-Object { Write-Host $_ }
$text = $output | Out-String
if ($LASTEXITCODE -ne 0 -or $text -notmatch "TEST_PASS") {
    throw "FreeRTOS timer/context-switch smoke did not pass."
}
if ($text -notmatch "PMU interrupt\s+= [1-9]\d*") {
    throw "FreeRTOS smoke passed without a recorded interrupt."
}

Write-Host "FREERTOS_TICK_CONTEXT_SMOKE_PASS"
