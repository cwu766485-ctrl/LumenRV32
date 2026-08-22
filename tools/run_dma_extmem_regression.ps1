param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "dma_extmem_tb",
    [int[]]$Seeds = @(13, 31, 59),
    [int]$Cases = 4,
    [int]$RamWait = 2,
    [int]$ExtWait = 5
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildDir = Join-Path $root "build\dma_extmem_regression"
$rtlCoreDir = Join-Path $root "rtl\core"
$cfgFile = Join-Path $buildDir "tb_cfg.vh"
$sources = @(
    (Join-Path $root "tb\dma_extmem_tb.sv"),
    (Join-Path $root "rtl\core\defines.v"),
    (Join-Path $root "tb\dma_test_memory_arbiter.v"),
    (Join-Path $root "rtl\perips\rom.v"),
    (Join-Path $root "rtl\perips\ram.v"),
    (Join-Path $root "rtl\perips\timer.v"),
    (Join-Path $root "rtl\perips\uart.v"),
    (Join-Path $root "rtl\perips\gpio.v"),
    (Join-Path $root "rtl\perips\i2c_master.v"),
    (Join-Path $root "rtl\perips\spi.v"),
    (Join-Path $root "rtl\perips\qspi.v"),
    (Join-Path $root "rtl\perips\pmu.v"),
    (Join-Path $root "rtl\perips\dma.v"),
    (Join-Path $root "rtl\perips\apb_perips.v"),
    (Join-Path $root "rtl\perips\external_memory_wrapper.v")
)

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
Push-Location $buildDir
try {
    $passCount = 0
    foreach ($seed in $Seeds) {
        Remove-Item -Recurse -Force xsim.dir -ErrorAction SilentlyContinue
        @(
            ('`define TB_SEED {0}' -f $seed),
            ('`define TB_CASES {0}' -f $Cases),
            ('`define TB_RAM_WAIT {0}' -f $RamWait),
            ('`define TB_EXT_WAIT {0}' -f $ExtWait)
        ) | Set-Content -Encoding ASCII $cfgFile

        foreach ($source in $sources) {
            & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" $rtlCoreDir "-i" $buildDir $source
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }

        & (Join-Path $VivadoBin "xelab.bat") $Snapshot "-s" $Snapshot
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        $logPath = Join-Path $buildDir ("seed_{0}.log" -f $seed)
        $output = & (Join-Path $VivadoBin "xsim.bat") $Snapshot "--runall" 2>&1
        $output | Set-Content -Encoding ASCII $logPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Seed $seed failed"
            $output
            exit $LASTEXITCODE
        }
        if (($output | Out-String) -notmatch "DMA_EXTMEM_PASS") {
            Write-Host "Seed $seed missing pass marker"
            $output
            exit 1
        }
        $passCount += 1
        Write-Host ("Seed {0}: PASS" -f $seed)
    }

    Write-Host ("DMA extmem regression PASS: {0}/{1} seeds" -f $passCount, $Seeds.Count)
    exit 0
}
finally {
    Pop-Location
}
