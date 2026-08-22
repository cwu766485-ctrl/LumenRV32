param([string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin", [string]$Snapshot = "branch_predictor_tb")
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$simDir = Join-Path $root "sim"
Push-Location $simDir
try {
    & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" (Join-Path $root "rtl\core") (Join-Path $root "rtl\core\defines.v")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" (Join-Path $root "rtl\core") (Join-Path $root "rtl\core\branch_predictor.v")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" (Join-Path $root "rtl\core") (Join-Path $root "tb\branch_predictor_tb.sv")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $VivadoBin "xelab.bat") "branch_predictor_tb" "-s" $Snapshot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $VivadoBin "xsim.bat") $Snapshot "--runall"
    exit $LASTEXITCODE
} finally { Pop-Location }
