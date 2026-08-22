param(
    [Parameter(Mandatory = $true)]
    [string]$Bitstream,
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin"
)

$ErrorActionPreference = "Stop"
$bit = (Resolve-Path -LiteralPath $Bitstream).Path
$script = Join-Path $PSScriptRoot "program_zu15eg_bitstream.tcl"

& (Join-Path $VivadoBin "vivado.bat") -mode batch -nolog -nojournal -source $script -tclargs $bit
if ($LASTEXITCODE -ne 0) {
    throw "ZU15EG programming failed."
}
