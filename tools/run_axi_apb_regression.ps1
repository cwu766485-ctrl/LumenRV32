param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "axi_apb_subsys_tb",
    [int[]]$Seeds = @(1, 7, 23, 101),
    [int]$Ops = 80
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildDir = Join-Path $root "build\axi_apb_regression"
$rtlCoreDir = Join-Path $root "rtl\core"
$cfgFile = Join-Path $buildDir "tb_cfg.vh"
$sources = @(
    (Join-Path $root "tb\axi_apb_subsys_tb.sv"),
    (Join-Path $root "rtl\core\defines.v"),
    (Join-Path $root "rtl\perips\axi_lite_apb_bridge.v"),
    (Join-Path $root "rtl\perips\apb_perips.v"),
    (Join-Path $root "rtl\perips\timer.v"),
    (Join-Path $root "rtl\perips\uart.v"),
    (Join-Path $root "rtl\perips\gpio.v"),
    (Join-Path $root "rtl\perips\i2c_master.v"),
    (Join-Path $root "rtl\perips\spi.v"),
    (Join-Path $root "rtl\perips\qspi.v"),
    (Join-Path $root "rtl\perips\pmu.v"),
    (Join-Path $root "rtl\perips\dma.v")
)

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
Push-Location $buildDir
try {
    $passCount = 0
    foreach ($seed in $Seeds) {
        Remove-Item -Recurse -Force xsim.dir -ErrorAction SilentlyContinue
        @(
            ('`define TB_SEED {0}' -f $seed),
            ('`define TB_OPS {0}' -f $Ops)
        ) | Set-Content -Encoding ASCII $cfgFile
        foreach ($source in $sources) {
            & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" $rtlCoreDir "-i" $buildDir $source
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }

        & (Join-Path $VivadoBin "xelab.bat") "axi_apb_subsys_tb" "-s" $Snapshot
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        $logPath = Join-Path $buildDir ("seed_{0}.log" -f $seed)
        $output = & (Join-Path $VivadoBin "xsim.bat") $Snapshot "--runall" 2>&1
        $output | Set-Content -Encoding ASCII $logPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Seed $seed failed"
            $output
            exit $LASTEXITCODE
        }
        if (($output | Out-String) -notmatch "SUBSYS_TEST_PASS") {
            Write-Host "Seed $seed missing pass marker"
            $output
            exit 1
        }
        $passCount += 1
        Write-Host ("Seed {0}: PASS" -f $seed)
    }

    Write-Host ("AXI/APB regression PASS: {0}/{1} seeds" -f $passCount, $Seeds.Count)
    exit 0
}
finally {
    Pop-Location
}
