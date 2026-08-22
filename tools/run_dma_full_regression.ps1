param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin"
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$script:summary = @()

function Invoke-Regression {
    param(
        [string]$Name,
        [string]$ScriptPath
    )

    Write-Host ("=== {0} ===" -f $Name)
    $output = & powershell -ExecutionPolicy Bypass -File $ScriptPath -VivadoBin $VivadoBin 2>&1
    if ($LASTEXITCODE -ne 0) {
        $output
        throw ("Regression failed: {0}" -f $Name)
    }
    $script:summary += [pscustomobject]@{
        Name = $Name
        Result = "PASS"
        Tail = ($output | Select-Object -Last 1)
    }
    $output | Select-Object -Last 3 | ForEach-Object { Write-Host $_ }
}

Invoke-Regression -Name "DMA mem2mem" -ScriptPath (Join-Path $root "tools\run_dma_regression.ps1")
Invoke-Regression -Name "DMA UART" -ScriptPath (Join-Path $root "tools\run_dma_uart_regression.ps1")
Invoke-Regression -Name "DMA SPI" -ScriptPath (Join-Path $root "tools\run_dma_spi_regression.ps1")
Invoke-Regression -Name "DMA contention" -ScriptPath (Join-Path $root "tools\run_dma_contention_regression.ps1")
Invoke-Regression -Name "AXI/APB subsystem" -ScriptPath (Join-Path $root "tools\run_axi_apb_regression.ps1")

Write-Host ""
Write-Host "Unified regression summary:"
$script:summary | ForEach-Object {
    Write-Host ("- {0}: {1} ({2})" -f $_.Name, $_.Result, $_.Tail)
}
