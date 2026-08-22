param(
    [Parameter(Mandatory = $true)]
    [string]$ExampleName,
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$ToolchainBin = "D:\riscv-toolchains\xpack-riscv-none-embed-gcc-10.2.0-1.2\bin",
    [string]$PythonExe = "C:\.platformio\penv\Scripts\python.exe",
    [UInt64]$SimTimeoutNs = 0,
    [int]$RomWaitCycles = 2,
    [int]$RamWaitCycles = 2,
    [string]$ExtMemInitFile = "",
    [int]$ExtMemDepthWords = -1,
    [string[]]$ExtraDefines = @(),
    [string]$Snapshot = ""
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$commonDir = Join-Path $root "tests\example"
$exampleDir = Join-Path $commonDir $ExampleName
$toolPrefix = Join-Path $ToolchainBin "riscv-none-embed-"
$gcc = "${toolPrefix}gcc.exe"
$objcopy = "${toolPrefix}objcopy.exe"
$objdump = "${toolPrefix}objdump.exe"
$runXsim = Join-Path $root "tools\run_xsim_program.ps1"
$buildDir = Join-Path $root ("build\" + $ExampleName)
$target = Join-Path $exampleDir $ExampleName
$bin = "$target.bin"
$dump = "$target.dump"

if (-not (Test-Path $exampleDir)) {
    throw "Example directory not found: $exampleDir"
}

if ([string]::IsNullOrWhiteSpace($Snapshot)) {
    $Snapshot = $ExampleName
}

if ($SimTimeoutNs -eq 0) {
    switch -Wildcard ($ExampleName) {
        "zu15eg_soc_ddr4_smoke" { $SimTimeoutNs = 8000000 }
        default                 { $SimTimeoutNs = 500000 }
    }
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$cflags = @(
    "-march=rv32im",
    "-mabi=ilp32",
    "-mcmodel=medlow",
    "-ffunction-sections",
    "-fdata-sections",
    "-DSIMULATION",
    "-I$commonDir"
)

$linkFlags = @(
    "-T", (Join-Path $commonDir "link.lds"),
    "-nostartfiles",
    "-Wl,--gc-sections",
    "-Wl,--check-sections"
)

$sources = @(
    (Join-Path $commonDir "start.S"),
    (Join-Path $commonDir "trap_entry.S"),
    (Join-Path $commonDir "init.c"),
    (Join-Path $commonDir "trap_handler.c"),
    (Join-Path $commonDir "lib\utils.c"),
    (Join-Path $commonDir "lib\xprintf.c"),
    (Join-Path $commonDir "lib\uart.c"),
    (Join-Path $commonDir "lib\spi.c"),
    (Join-Path $commonDir "lib\flash_n25q.c"),
    (Join-Path $exampleDir "main.c")
)

$objects = @()
foreach ($src in $sources) {
    $obj = Join-Path $buildDir ((Split-Path $src -Leaf) -replace '\.(S|c)$', '.o')
    & $gcc @cflags "-c" "-o" $obj $src
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $objects += $obj
}

& $gcc @cflags @objects "-o" $target @linkFlags
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
& $objcopy "-O" "binary" $target $bin
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
& $objdump "--disassemble-all" $target | Set-Content -Path $dump -Encoding ASCII

$runArgs = @{
    VivadoBin = $VivadoBin
    BinaryPath = $bin
    PythonExe = $PythonExe
    SimTimeoutNs = $SimTimeoutNs
    RomWaitCycles = $RomWaitCycles
    RamWaitCycles = $RamWaitCycles
    Snapshot = $Snapshot
}
if (-not [string]::IsNullOrWhiteSpace($ExtMemInitFile)) {
    $runArgs.ExtMemInitFile = $ExtMemInitFile
}
if ($ExtMemDepthWords -gt 0) {
    $runArgs.ExtMemDepthWords = $ExtMemDepthWords
}
if ($ExtraDefines.Count -gt 0) {
    $runArgs.ExtraDefines = $ExtraDefines
}

& $runXsim @runArgs
exit $LASTEXITCODE
