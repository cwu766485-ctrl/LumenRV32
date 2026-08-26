param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "jtag_user2_transport_tb"
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$simDir = Join-Path $root 'sim'
Push-Location $simDir
try {
    $rtl = @(
        (Join-Path $root 'rtl\utils\jtag_cdc_reset_sync.v'),
        (Join-Path $root 'rtl\utils\full_handshake_tx.v'),
        (Join-Path $root 'rtl\utils\full_handshake_rx.v'),
        (Join-Path $root 'rtl\debug\jtag_dm.v'),
        (Join-Path $root 'rtl\debug\jtag_user2_dmi_transport.v'),
        (Join-Path $root 'tb\jtag_user2_transport_tb.sv')
    )
    foreach ($file in $rtl) {
        & (Join-Path $VivadoBin 'xvlog.bat') '--sv' $file
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & (Join-Path $VivadoBin 'xelab.bat') 'jtag_user2_transport_tb' '-s' $Snapshot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $VivadoBin 'xsim.bat') $Snapshot '--runall'
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
