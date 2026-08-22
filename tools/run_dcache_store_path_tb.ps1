param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "dcache_store_path_tb",
    [switch]$UseBlockRam
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$simDir = Join-Path $root "sim"
$sources = @(
    (Join-Path $root "rtl\core\defines.v"),
    (Join-Path $root "rtl\core\cache_ram_1r1w.v"),
    (Join-Path $root "rtl\core\dcache.v"),
    (Join-Path $root "tb\dcache_store_path_tb.sv")
)

Push-Location $simDir
try {
    foreach ($src in $sources) {
        $xvlogArgs = @("--sv", "-i", (Join-Path $root "rtl\core"))
        if ($UseBlockRam) {
            $xvlogArgs += @("-d", "CacheUseBlockRam")
        }
        $xvlogArgs += $src
        & (Join-Path $VivadoBin "xvlog.bat") @xvlogArgs
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & (Join-Path $VivadoBin "xelab.bat") "dcache_store_path_tb" "-s" $Snapshot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $output = & (Join-Path $VivadoBin "xsim.bat") $Snapshot "--runall" 2>&1
    $output
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (($output | Out-String) -notmatch "DCACHE_STORE_PATH_TB_PASS") {
        Write-Error "Missing DCACHE_STORE_PATH_TB_PASS marker"
    }
    exit 0
}
finally {
    Pop-Location
}
