param(
    [string]$ToolchainBin = "D:\Xilinx\Vitis\2024.1\gnu\aarch64\nt\aarch64-none\bin",
    [string]$OutDir = "build\zu15eg_ddr4_cpu_smoke"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourceDir = Join-Path $root "tests\board\zu15eg_ddr4_cpu_smoke"
if (-not [System.IO.Path]::IsPathRooted($OutDir)) { $OutDir = Join-Path $root $OutDir }
$gcc = Join-Path $ToolchainBin "aarch64-none-elf-gcc.exe"
$objdump = Join-Path $ToolchainBin "aarch64-none-elf-objdump.exe"
foreach ($item in @($gcc, $objdump, (Join-Path $sourceDir "start.S"),
        (Join-Path $sourceDir "main.c"), (Join-Path $sourceDir "linker.ld"))) {
    if (-not (Test-Path -LiteralPath $item)) { throw "Required input not found: $item" }
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$elf = Join-Path $OutDir "zu15eg_ddr4_cpu_smoke.elf"
$map = Join-Path $OutDir "zu15eg_ddr4_cpu_smoke.map"
$disasm = Join-Path $OutDir "zu15eg_ddr4_cpu_smoke.dis"

& $gcc -mcpu=cortex-a53 -mgeneral-regs-only -ffreestanding -fno-builtin `
    -fno-stack-protector -nostdlib -nostartfiles -O2 `
    (Join-Path $sourceDir "start.S") (Join-Path $sourceDir "main.c") `
    "-Wl,-T,$(Join-Path $sourceDir 'linker.ld')" "-Wl,-Map,$map" `
    "-Wl,--build-id=none" -o $elf
if ($LASTEXITCODE -ne 0) { throw "AArch64 smoke ELF build failed." }

& $objdump -h -t -d $elf | Set-Content -LiteralPath $disasm -Encoding ascii
if ($LASTEXITCODE -ne 0) { throw "AArch64 smoke ELF inspection failed." }

$hash = (Get-FileHash -LiteralPath $elf -Algorithm SHA256).Hash
Write-Output "ZU15EG_DDR4_CPU_SMOKE_BUILD=PASS"
Write-Output "ZU15EG_DDR4_CPU_SMOKE_ELF=$elf"
Write-Output "ZU15EG_DDR4_CPU_SMOKE_SHA256=$hash"
