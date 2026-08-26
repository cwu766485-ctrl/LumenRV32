param(
    [int]$Jobs = 4,
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$OutDir = "build\zu15eg_cpu_jtag_user2",
    [ValidateRange(1, 8)] [int]$CpuClockDiv = 2
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $root $OutDir }
$vivado = Join-Path $VivadoBin 'vivado.bat'
if (-not (Test-Path $vivado)) { throw "Tool not found: $vivado" }
New-Item -ItemType Directory -Force -Path $out | Out-Null
& $vivado -mode batch -nolog -nojournal -source (Join-Path $PSScriptRoot 'build_zu15eg_cpu_jtag_user2.tcl') -tclargs $root $out $Jobs $CpuClockDiv
if ($LASTEXITCODE -ne 0) { throw 'ZU15EG USER2 JTAG profile implementation failed.' }
$hash = (Get-FileHash (Join-Path $out 'zu15eg_cpu_jtag_user2_top.bit') -Algorithm SHA256).Hash
Write-Output 'ZU15EG_CPU_JTAG_USER2_BUILD=PASS'
Write-Output "ZU15EG_CPU_JTAG_USER2_CLOCK_DIV=$CpuClockDiv"
Write-Output "ZU15EG_CPU_JTAG_USER2_SHA256=$hash"
