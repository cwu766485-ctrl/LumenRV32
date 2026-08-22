param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "i2c_master_tb"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$simDir = Join-Path $root "sim"
$sources = @(
    (Join-Path $root "rtl\core\defines.v"),
    (Join-Path $root "rtl\perips\i2c_master.v"),
    (Join-Path $root "tb\i2c_master_tb.sv")
)

Push-Location $simDir
try {
    foreach ($source in $sources) {
        & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" (Join-Path $root "rtl\core") $source
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & (Join-Path $VivadoBin "xelab.bat") "i2c_master_tb" "-s" $Snapshot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $VivadoBin "xsim.bat") $Snapshot "--runall"
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
