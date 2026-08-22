param(
    [int]$Jobs = 4,
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$ToolchainBin = "D:\riscv-toolchains\xpack-riscv-none-embed-gcc-10.2.0-1.2\bin",
    [string]$OutDir = "build\zu15eg_riscv_bram_uart",
    [ValidateRange(1, 8)]
    [int]$CpuClockDiv = 4
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $root $OutDir }
$gcc = Join-Path $ToolchainBin 'riscv-none-embed-gcc.exe'
$objcopy = Join-Path $ToolchainBin 'riscv-none-embed-objcopy.exe'
$python = 'C:\.platformio\penv\Scripts\python.exe'
$vivado = Join-Path $VivadoBin 'vivado.bat'
foreach ($file in @($gcc, $objcopy, $python, $vivado)) { if (-not (Test-Path $file)) { throw "Tool not found: $file" } }
New-Item -ItemType Directory -Force -Path $out | Out-Null
$common = Join-Path $root 'tests\example'
$source = Join-Path $root 'tests\board\zu15eg_riscv_bram_uart_smoke\main.c'
$elf = Join-Path $out 'zu15eg_riscv_bram_uart_smoke.elf'
$bin = Join-Path $out 'zu15eg_riscv_bram_uart_smoke.bin'
$inst = Join-Path $out 'inst.data'
$cflags = @('-march=rv32im','-mabi=ilp32','-mcmodel=medlow','-ffunction-sections','-fdata-sections',"-I$common")
$link = @('-T',(Join-Path $common 'link.lds'),'-nostartfiles','-Wl,--gc-sections','-Wl,--check-sections')
& $gcc @cflags (Join-Path $common 'start.S') (Join-Path $common 'trap_entry.S') (Join-Path $common 'init.c') (Join-Path $common 'trap_handler.c') $source '-o' $elf @link
if ($LASTEXITCODE -ne 0) { throw 'RISC-V UART smoke compilation failed.' }
& $objcopy '-O' binary $elf $bin
if ($LASTEXITCODE -ne 0) { throw 'RISC-V UART smoke objcopy failed.' }
& $python (Join-Path $root 'tools\BinToMem_CLI.py') $bin $inst
if ($LASTEXITCODE -ne 0) { throw 'ROM init generation failed.' }
& $vivado -mode batch -nolog -nojournal -source (Join-Path $PSScriptRoot 'build_zu15eg_riscv_bram_uart.tcl') -tclargs $root $out $inst $Jobs $CpuClockDiv
if ($LASTEXITCODE -ne 0) { throw 'ZU15EG RISC-V BRAM/UART implementation failed.' }
$hash = (Get-FileHash (Join-Path $out 'zu15eg_riscv_bram_uart_top.bit') -Algorithm SHA256).Hash
Write-Output 'ZU15EG_RISCV_BRAM_UART_BUILD=PASS'
Write-Output "ZU15EG_RISCV_BRAM_UART_CPU_CLOCK_DIV=$CpuClockDiv"
Write-Output "ZU15EG_RISCV_BRAM_UART_SHA256=$hash"
