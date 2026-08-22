[CmdletBinding()]
param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$PythonExe = "python",
    [UInt64]$SimTimeoutNs = 5000000,
    [string]$Pattern = "rv32ui-p-*.bin",
    [string[]]$ExtraDefines = @()
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$runner = Join-Path $root "tools\run_xsim_program.ps1"
$binDir = Join-Path $root "tests\isa\generated"
$logDir = Join-Path $root "build\isa_regression"
$binToMem = Join-Path $root "tools\BinToMem_CLI.py"
$simDir = Join-Path $root "sim"
$tests = @(Get-ChildItem -Path $binDir -Filter $Pattern | Sort-Object Name)

if ($tests.Count -eq 0) {
    throw "No ISA binaries matched $Pattern under $binDir"
}

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$passed = 0
$snapshot = "isa_regression_tb"

for ($index = 0; $index -lt $tests.Count; $index += 1) {
    $test = $tests[$index]
    $logPath = Join-Path $logDir ($test.BaseName + ".log")

    Write-Host ("=== {0} ===" -f $test.BaseName)
    if ($index -eq 0) {
        # Build the snapshot once. The testbench reads sim/inst.data at runtime,
        # so every later test can reuse this elaborated design.
        $runnerArgs = @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $runner,
            "-VivadoBin", $VivadoBin,
            "-PythonExe", $PythonExe,
            "-Snapshot", $snapshot,
            "-BinaryPath", $test.FullName,
            "-SimTimeoutNs", $SimTimeoutNs
        )
        if ($ExtraDefines.Count -ne 0) {
            $runnerArgs += @("-ExtraDefines")
            $runnerArgs += $ExtraDefines
        }
        $output = & powershell.exe @runnerArgs 2>&1
    } else {
        & $PythonExe $binToMem $test.FullName (Join-Path $simDir "inst.data")
        if ($LASTEXITCODE -ne 0) {
            throw ("Failed to generate inst.data for {0}" -f $test.BaseName)
        }

        Push-Location $simDir
        try {
            $output = & (Join-Path $VivadoBin "xsim.bat") $snapshot "--runall" 2>&1
        } finally {
            Pop-Location
        }
    }
    $output | Set-Content -Encoding UTF8 $logPath

    if ($LASTEXITCODE -ne 0 -or (($output | Out-String) -notmatch "TEST_PASS")) {
        $output | Select-Object -Last 80
        throw ("ISA regression failed: {0}" -f $test.BaseName)
    }

    $passed += 1
    Write-Host ("{0}: PASS ({1}/{2})" -f $test.BaseName, $passed, $tests.Count)
}

Write-Host ("ISA regression PASS: {0}/{1}" -f $passed, $tests.Count)
