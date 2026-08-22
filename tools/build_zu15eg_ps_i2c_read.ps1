param(
    [string]$ToolchainBin = "D:\Xilinx\Vitis\2024.1\gnu\aarch64\nt\aarch64-none\bin",
    [string]$OutDir = "build\zu15eg_ps_i2c_read"
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$src = Join-Path $root 'tests\board\zu15eg_ps_i2c_read'
$bsp = Join-Path $root 'docs\hardware\zu15eg\15eg_demo\6.qspi_test\prj\qspi_test\qspi_test.vitis\top\export\top\sw\top\standalone_domain'
$gcc = Join-Path $ToolchainBin 'aarch64-none-elf-gcc.exe'
$objdump = Join-Path $ToolchainBin 'aarch64-none-elf-objdump.exe'
if (-not [System.IO.Path]::IsPathRooted($OutDir)) { $OutDir = Join-Path $root $OutDir }
foreach ($item in @($gcc, $objdump, (Join-Path $src 'start.S'), (Join-Path $src 'main.c'), (Join-Path $src 'linker.ld'),
        (Join-Path $bsp 'bspinclude\include\xil_types.h'))) {
    if (-not (Test-Path -LiteralPath $item)) { throw "Required input not found: $item" }
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$elf = Join-Path $OutDir 'zu15eg_ps_i2c_read.elf'
$map = Join-Path $OutDir 'zu15eg_ps_i2c_read.map'
$disasm = Join-Path $OutDir 'zu15eg_ps_i2c_read.dis'
& $gcc -mcpu=cortex-a53 -mgeneral-regs-only -ffreestanding -fno-builtin -fno-stack-protector -nostdlib -nostartfiles -O2 `
    (Join-Path $src 'start.S') (Join-Path $src 'main.c') "-Wl,-T,$(Join-Path $src 'linker.ld')" `
    "-Wl,-Map,$map" '-Wl,--build-id=none' -o $elf
if ($LASTEXITCODE -ne 0) { throw 'ZU15EG PS I2C read ELF build failed.' }
& $objdump -h -t -d $elf | Set-Content -LiteralPath $disasm -Encoding ascii
if ($LASTEXITCODE -ne 0) { throw 'ZU15EG PS I2C read ELF inspection failed.' }
Write-Output 'ZU15EG_PS_I2C_READ_BUILD=PASS'
Write-Output "ZU15EG_PS_I2C_READ_ELF=$elf"
Write-Output "ZU15EG_PS_I2C_READ_SHA256=$((Get-FileHash -LiteralPath $elf -Algorithm SHA256).Hash)"
