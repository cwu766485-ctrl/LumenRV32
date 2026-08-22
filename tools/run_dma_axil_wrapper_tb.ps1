param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "dma_axil_wrapper_tb"
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildDir = Join-Path $root "build\dma_axil_wrapper_tb"
$rtlCoreDir = Join-Path $root "rtl\core"
$sources = @(
    (Join-Path $root "tb\dma_axil_wrapper_tb.sv"),
    (Join-Path $root "rtl\core\defines.v"),
    (Join-Path $root "rtl\perips\dma.v"),
    (Join-Path $root "rtl\perips\dma_axil_wrapper.v")
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
    if (($output | Out-String) -notmatch "DMA_AXIL_WRAPPER_TB_PASS") {
        $output
        Write-Error "Missing DMA_AXIL_WRAPPER_TB_PASS marker"
    }

    $output
    exit 0
}
finally {
    Pop-Location
}
