param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "axi4_extmem_bridge_tb"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$simDir = Join-Path $root "sim"
$sources = @(
    (Join-Path $root "tb\axi4_extmem_bridge_tb.sv"),
    (Join-Path $root "rtl\core\defines.v"),
    (Join-Path $root "rtl\perips\axi4_extmem_bridge.v")
)

Push-Location $simDir
try {
    foreach ($src in $sources) {
        & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" (Join-Path $root "rtl\core") $src
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    & (Join-Path $VivadoBin "xelab.bat") "axi4_extmem_bridge_tb" "-s" $Snapshot
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    & (Join-Path $VivadoBin "xsim.bat") $Snapshot "--runall"
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
