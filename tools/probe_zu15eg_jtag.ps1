param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$script = Join-Path $PSScriptRoot "probe_zu15eg_jtag.tcl"

& (Join-Path $VivadoBin "vivado.bat") -mode batch -nolog -nojournal -source $script
if ($LASTEXITCODE -ne 0) {
    throw "ZU15EG JTAG probe failed; check board power, JTAG mode and cable orientation."
}
