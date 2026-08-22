param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "coremark_tb",
    [string]$BinaryPath = "",
    [string]$PythonExe = "python",
    [UInt64]$SimTimeoutNs = 10000000,
    [int]$RomDepth = 8192,
    [int]$RomWaitCycles = -1,
    [int]$RamWaitCycles = -1,
    [int]$ICacheLineWords = -1,
    [int]$ICacheLineCount = -1,
    [int]$DCacheLineWords = -1,
    [int]$DCacheLineCount = -1,
    [switch]$DisableICache,
    [string[]]$ExtraDefines = @()
)

$runner = Join-Path $PSScriptRoot "run_xsim_program.ps1"

& $runner `
    -VivadoBin $VivadoBin `
    -Snapshot $Snapshot `
    -BinaryPath $BinaryPath `
    -PythonExe $PythonExe `
    -SimTimeoutNs $SimTimeoutNs `
    -RomDepth $RomDepth `
    -RomWaitCycles $RomWaitCycles `
    -RamWaitCycles $RamWaitCycles `
    -ICacheLineWords $ICacheLineWords `
    -ICacheLineCount $ICacheLineCount `
    -DCacheLineWords $DCacheLineWords `
    -DCacheLineCount $DCacheLineCount `
    -DisableICache:$DisableICache `
    -CoreMarkDone `
    -ExtraDefines $ExtraDefines

exit $LASTEXITCODE
