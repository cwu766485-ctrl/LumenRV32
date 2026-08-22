param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "axi4_crossbar_stage_a_tb"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildDir = Join-Path $root "build\axi4_crossbar_stage_a_tb"
$sources = @(
    (Join-Path $root "rtl\core\defines.v"),
    (Join-Path $root "rtl\interconnect\axi4_crossbar.v"),
    (Join-Path $root "tb\axi4_crossbar_stage_a_tb.sv")
)

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
Push-Location $buildDir
try {
    Remove-Item -Recurse -Force xsim.dir -ErrorAction SilentlyContinue
    foreach ($source in $sources) {
        & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" (Join-Path $root "rtl\core") $source
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & (Join-Path $VivadoBin "xelab.bat") "axi4_crossbar_stage_a_tb" "-s" $Snapshot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $output = & (Join-Path $VivadoBin "xsim.bat") $Snapshot "--runall" 2>&1
    $output | Set-Content -Encoding ASCII (Join-Path $buildDir "run.log")
    if ($LASTEXITCODE -ne 0) { $output; exit $LASTEXITCODE }
    if (($output | Out-String) -notmatch "AXI4_XBAR_STAGE_BC_PASS") { $output; exit 1 }
    $output | Select-String "AXI4_XBAR_STAGE_BC_PASS"
}
finally {
    Pop-Location
}
