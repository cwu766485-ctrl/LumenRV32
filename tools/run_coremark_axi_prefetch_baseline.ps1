[CmdletBinding()]
param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$PythonExe = "python",
    [string]$Snapshot = "coremark_axi_prefetch_baseline",
    [UInt64]$SimTimeoutNs = 2000000000
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$runner = Join-Path $root "tools\run_xsim_program.ps1"
$binary = Join-Path $root "tests\example\coremark\artifacts\axi_prefetch_baseline\coremark_axi_prefetch_iter1.bin"
$simDir = Join-Path $root "build\coremark_axi_prefetch_baseline_sim"
$expectedHash = "55852A312313CA5AA1EAEE291FF82783F6D775AA0B1DE3AE3450710C4DF56E7D"
$expectedTicks = 423525
$expectedPmuCycles = 454398

if ((Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash -ne $expectedHash) {
    throw "CoreMark baseline binary SHA-256 mismatch: $binary"
}

$output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner `
    -VivadoBin $VivadoBin `
    -PythonExe $PythonExe `
    -Snapshot $Snapshot `
    -BinaryPath $binary `
    -SimTimeoutNs $SimTimeoutNs `
    -CoreMarkDone `
    -SimDir $simDir 2>&1

$output | ForEach-Object { Write-Host $_ }
$text = $output | Out-String
if ($LASTEXITCODE -ne 0 -or $text -notmatch "TEST_PASS") {
    throw "CoreMark baseline simulation did not pass."
}
if ($text -notmatch ("CoreMark ticks = {0}" -f $expectedTicks)) {
    throw ("CoreMark baseline tick mismatch; expected {0}." -f $expectedTicks)
}
if ($text -notmatch ("PMU cycle     = {0}" -f $expectedPmuCycles)) {
    throw ("CoreMark PMU cycle mismatch; expected {0}." -f $expectedPmuCycles)
}

Write-Host "COREMARK_AXI_PREFETCH_BASELINE_PASS"
