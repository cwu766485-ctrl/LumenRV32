[CmdletBinding()]
param(
    [int]$Jobs = 4,
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$ToolchainBin = "D:\riscv-toolchains\xpack-riscv-none-embed-gcc-10.2.0-1.2\bin",
    [string]$OutDir = "build\zu15eg_coremark",
    [ValidateRange(100, 100000)]
    [int]$Iterations = 2000,
    [ValidateRange(1, 8)]
    [int]$CpuClockDiv = 4,
    [ValidateRange(8192, 65536)]
    [int]$RomWords = 8192
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $root $OutDir }
$make = 'C:\MinGW\bin\mingw32-make.exe'
$coremarkDir = Join-Path $root 'tests\example\coremark'
$prefix = Join-Path $ToolchainBin 'riscv-none-embed-'
$buildBram = Join-Path $PSScriptRoot 'build_zu15eg_riscv_bram_uart.ps1'

foreach ($file in @($make, (Join-Path $ToolchainBin 'riscv-none-embed-gcc.exe'), (Join-Path $VivadoBin 'vivado.bat'))) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Tool not found: $file" }
}

New-Item -ItemType Directory -Force -Path $out | Out-Null

# Deliberately do not define SIMULATION_FAST_EXIT.  CoreMark itself checks the
# >=10-second interval and emits CRC/result lines over UART.
& $make -B -C $coremarkDir `
    ("RISCV_GCC_PREFIX={0}" -f $prefix) `
    ("COREMARK_ITERATIONS={0}" -f $Iterations) `
    'COREMARK_EXTRA_CFLAGS='
if ($LASTEXITCODE -ne 0) { throw 'CoreMark release build failed.' }

$programBin = Join-Path $coremarkDir 'coremark.bin'
$programCopy = Join-Path $out ("coremark_iter{0}.bin" -f $Iterations)
Copy-Item -LiteralPath $programBin -Destination $programCopy -Force
$sha256 = (Get-FileHash -LiteralPath $programCopy -Algorithm SHA256).Hash

& $buildBram -Jobs $Jobs -VivadoBin $VivadoBin -ToolchainBin $ToolchainBin `
    -OutDir $out -CpuClockDiv $CpuClockDiv -RomWords $RomWords -ProgramBin $programCopy
if ($LASTEXITCODE -ne 0) { throw 'ZU15EG CoreMark bitstream build failed.' }

Write-Output 'ZU15EG_COREMARK_RELEASE_BUILD=PASS'
Write-Output "ZU15EG_COREMARK_ITERATIONS=$Iterations"
Write-Output "ZU15EG_COREMARK_CPU_FREQ_MHZ=$(200 / $CpuClockDiv)"
Write-Output "ZU15EG_COREMARK_IMAGE_SHA256=$sha256"
Write-Output "ZU15EG_COREMARK_BIT=$(Join-Path $out 'zu15eg_riscv_bram_uart_top.bit')"
