param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin"
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tests = @(
    @{ Name = "DMA/APB regression"; Script = "run_dma_full_regression.ps1" },
    @{ Name = "DMA EXTMEM regression"; Script = "run_dma_extmem_regression.ps1" },
    @{ Name = "AXI4 EXTMEM bridge"; Script = "run_axi4_extmem_bridge_tb.ps1" },
    @{ Name = "EXTERNAL memory wrapper"; Script = "run_external_memory_wrapper_tb.ps1" }
)

foreach ($test in $tests) {
    Write-Host ("=== {0} ===" -f $test.Name)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root ("tools\" + $test.Script)) -VivadoBin $VivadoBin
    if ($LASTEXITCODE -ne 0) {
        throw ("Final SoC regression failed: {0}" -f $test.Name)
    }
}

Write-Host "FINAL_SOC_REGRESSION_PASS"
