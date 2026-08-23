param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "id_jalr_forwarding_tb"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$simDir = Join-Path $root "sim"
Push-Location $simDir
try {
    & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" (Join-Path $root "rtl\core") (Join-Path $root "rtl\core\defines.v")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" (Join-Path $root "rtl\core") (Join-Path $root "rtl\core\id.v")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" (Join-Path $root "rtl\core") (Join-Path $root "tb\id_jalr_forwarding_tb.sv")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $VivadoBin "xelab.bat") "id_jalr_forwarding_tb" "-s" $Snapshot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $VivadoBin "xsim.bat") $Snapshot "--runall"
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
