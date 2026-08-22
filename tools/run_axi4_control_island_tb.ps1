param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "axi4_control_island_tb"
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildDir = Join-Path $root "build\axi4_control_island_tb"
$rtlCoreDir = Join-Path $root "rtl\core"
$sources = @(
    (Join-Path $root "tb\axi4_control_island_tb.sv"),
    (Join-Path $root "rtl\core\defines.v"),
    (Join-Path $root "rtl\perips\axi_lite_apb_bridge.v"),
    (Join-Path $root "rtl\interconnect\axi4_to_apb_bridge.v"),
    (Join-Path $root "rtl\interconnect\axi4_control_island.v")
)

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
Push-Location $buildDir
try {
    Remove-Item -Recurse -Force xsim.dir -ErrorAction SilentlyContinue

    foreach ($source in $sources) {
        & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" $rtlCoreDir $source
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    & (Join-Path $VivadoBin "xelab.bat") $Snapshot "-s" $Snapshot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $output = & (Join-Path $VivadoBin "xsim.bat") $Snapshot "--runall" 2>&1
    $output | Set-Content -Encoding ASCII (Join-Path $buildDir "xsim.log")
    if ($LASTEXITCODE -ne 0) {
        $output
        exit $LASTEXITCODE
    }
    if (($output | Out-String) -notmatch "AXI4_CONTROL_ISLAND_TB_PASS") {
        $output
        Write-Error "Missing AXI4_CONTROL_ISLAND_TB_PASS marker"
    }

    $output
    exit 0
}
finally {
    Pop-Location
}
