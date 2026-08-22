param(
    [string]$ToolchainBin = "D:\Xilinx\Vitis\2024.1\gnu\aarch64\nt\aarch64-none\bin",
    [string]$OutDir = "build\zu15eg_qspi_read_id"
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceDir = Join-Path $root 'tests\board\zu15eg_qspi_read_id'
$bsp = Join-Path $root 'docs\hardware\zu15eg\15eg_demo\6.qspi_test\prj\qspi_test\qspi_test.vitis\top\export\top\sw\top\standalone_domain'
$gcc = Join-Path $ToolchainBin 'aarch64-none-elf-gcc.exe'
$objdump = Join-Path $ToolchainBin 'aarch64-none-elf-objdump.exe'
if (-not [System.IO.Path]::IsPathRooted($OutDir)) { $OutDir = Join-Path $root $OutDir }
foreach ($item in @($gcc, $objdump, (Join-Path $sourceDir 'start.S'), (Join-Path $sourceDir 'main.c'),
        (Join-Path $sourceDir 'linker.ld'), (Join-Path $bsp 'bspinclude\include\xqspipsu.h'),
        (Join-Path $bsp 'bsplib\lib\libxil.a'))) {
    if (-not (Test-Path -LiteralPath $item)) { throw "Required input not found: $item" }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$elf = Join-Path $OutDir 'zu15eg_qspi_read_id.elf'
$map = Join-Path $OutDir 'zu15eg_qspi_read_id.map'
$disasm = Join-Path $OutDir 'zu15eg_qspi_read_id.dis'
& $gcc -mcpu=cortex-a53 -mgeneral-regs-only -ffreestanding -fno-builtin -fno-stack-protector `
    -nostartfiles -O2 "-I$(Join-Path $bsp 'bspinclude\include')" `
    (Join-Path $sourceDir 'start.S') (Join-Path $sourceDir 'main.c') `
    "-Wl,-T,$(Join-Path $sourceDir 'linker.ld')" "-Wl,-Map,$map" "-L$(Join-Path $bsp 'bsplib\lib')" `
    '-Wl,--start-group' '-lxil' '-lgcc' '-lc' '-Wl,--end-group' '-Wl,--build-id=none' -o $elf
if ($LASTEXITCODE -ne 0) { throw 'ZU15EG QSPI read-ID ELF build failed.' }
& $objdump -h -t -d $elf | Set-Content -LiteralPath $disasm -Encoding ascii
if ($LASTEXITCODE -ne 0) { throw 'ZU15EG QSPI read-ID ELF inspection failed.' }
Write-Output 'ZU15EG_QSPI_READ_ID_BUILD=PASS'
Write-Output "ZU15EG_QSPI_READ_ID_ELF=$elf"
Write-Output "ZU15EG_QSPI_READ_ID_SHA256=$((Get-FileHash -LiteralPath $elf -Algorithm SHA256).Hash)"
