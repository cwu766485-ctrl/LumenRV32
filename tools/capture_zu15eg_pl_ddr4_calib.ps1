param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Bitstream = "docs\hardware\zu15eg\15eg_demo\1.mem_test\prj\mem_test\mem_test.runs\impl_1\design_1_wrapper.bit",
    [string]$Probes = "docs\hardware\zu15eg\15eg_demo\1.mem_test\prj\mem_test\mem_test.runs\impl_1\design_1_wrapper.ltx",
    [string]$OutCsv = "build\zu15eg_pl_ddr4_calib.csv",
    [switch]$SkipProgram,
    [switch]$Immediate
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$vivado = Join-Path $VivadoBin "vivado.bat"
if (-not (Test-Path -LiteralPath $vivado)) {
    throw "Vivado not found: $vivado"
}

foreach ($item in @($Bitstream, $Probes)) {
    if (-not [System.IO.Path]::IsPathRooted($item)) {
        $item = Join-Path $root $item
    }
    if (-not (Test-Path -LiteralPath $item)) {
        throw "Required input not found: $item"
    }
}

if (-not [System.IO.Path]::IsPathRooted($Bitstream)) { $Bitstream = Join-Path $root $Bitstream }
if (-not [System.IO.Path]::IsPathRooted($Probes)) { $Probes = Join-Path $root $Probes }
if (-not [System.IO.Path]::IsPathRooted($OutCsv)) { $OutCsv = Join-Path $root $OutCsv }

$outDir = Split-Path -Parent $OutCsv
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

$skipProgramArg = if ($SkipProgram) { "1" } else { "0" }
$immediateArg = if ($Immediate) { "1" } else { "0" }
$vivadoLog = "$OutCsv.vivado.log"
$vivadoJournal = "$OutCsv.vivado.jou"
& $vivado -mode batch -log $vivadoLog -journal $vivadoJournal -source (Join-Path $PSScriptRoot "capture_zu15eg_pl_ddr4_calib.tcl") -tclargs $Bitstream.Replace('\', '/') $Probes.Replace('\', '/') $OutCsv.Replace('\', '/') $skipProgramArg $immediateArg
if ($LASTEXITCODE -ne 0) {
    if (Test-Path -LiteralPath $vivadoLog) {
        Get-Content -LiteralPath $vivadoLog -Tail 80 | Write-Error
    }
    throw "ZU15EG PL DDR4 calibration capture failed."
}
