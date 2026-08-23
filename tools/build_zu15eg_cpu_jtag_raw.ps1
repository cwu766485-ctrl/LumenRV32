param(
    [Parameter(Mandatory = $true)] [string]$JtagXdc,
    [int]$Jobs = 4,
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$OutDir = "build\zu15eg_cpu_jtag_raw",
    [ValidateRange(1, 8)] [int]$CpuClockDiv = 2
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $root $OutDir }
$xdc = (Resolve-Path $JtagXdc).Path
if ($xdc -match 'zu15eg_cpu_jtag_raw_example\.xdc$') {
    throw 'Copy the example XDC, fill in actual PL connector pins, then pass that copied file.'
}
$vivado = Join-Path $VivadoBin 'vivado.bat'
if (-not (Test-Path $vivado)) { throw "Tool not found: $vivado" }
New-Item -ItemType Directory -Force -Path $out | Out-Null
& $vivado -mode batch -nolog -nojournal -source (Join-Path $PSScriptRoot 'build_zu15eg_cpu_jtag_raw.tcl') -tclargs $root $out $Jobs $CpuClockDiv $xdc
if ($LASTEXITCODE -ne 0) { throw 'ZU15EG external-JTAG CPU profile implementation failed.' }
$hash = (Get-FileHash (Join-Path $out 'zu15eg_cpu_jtag_raw_top.bit') -Algorithm SHA256).Hash
Write-Output 'ZU15EG_CPU_JTAG_RAW_BUILD=PASS'
Write-Output "ZU15EG_CPU_JTAG_RAW_CLOCK_DIV=$CpuClockDiv"
Write-Output "ZU15EG_CPU_JTAG_RAW_SHA256=$hash"
