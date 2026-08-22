param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin"
)

# This deliberately compiles only repository DUT harnesses.  Licensed VIP
# sources are supplied by the user's own VIP project and must not be copied in.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$build = Join-Path $root 'build\vip_sanity_compile'
$rtlCore = Join-Path $root 'rtl\core'

$sets = @(
    @{ Name = 'apb'; Sources = @('rtl\core\defines.v','rtl\perips\timer.v','rtl\perips\uart.v','rtl\perips\gpio.v','rtl\perips\spi.v','rtl\perips\qspi.v','rtl\perips\i2c_master.v','rtl\perips\pmu.v','rtl\perips\dma.v','rtl\perips\apb_perips.v','verify\vip_sanity\apb\apb_perips_vip_harness.sv') },
    @{ Name = 'axi_lite'; Sources = @('rtl\core\defines.v','rtl\perips\axi_lite_apb_bridge.v','verify\vip_sanity\axi_lite\axi_lite_to_apb_vip_harness.sv') },
    @{ Name = 'axi4'; Sources = @('rtl\core\defines.v','rtl\interconnect\axi4_to_apb_bridge.v','rtl\interconnect\axi4_control_island.v','verify\vip_sanity\axi4\axi4_control_island_vip_harness.sv') },
    @{ Name = 'uart'; Sources = @('rtl\perips\uart.v','verify\vip_sanity\uart\uart_vip_harness.sv') },
    @{ Name = 'i2c'; Sources = @('rtl\core\defines.v','rtl\perips\i2c_master.v','verify\vip_sanity\i2c\i2c_vip_harness.sv') },
    @{ Name = 'spi'; Sources = @('rtl\perips\spi.v','verify\vip_sanity\spi\spi_vip_harness.sv') }
)

New-Item -ItemType Directory -Force -Path $build | Out-Null
Push-Location $build
try {
    foreach ($set in $sets) {
        $library = "vip_sanity_$($set.Name)"
        Remove-Item -Recurse -Force (Join-Path $build $library) -ErrorAction SilentlyContinue
        foreach ($source in $set.Sources) {
            & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '-work' $library '-i' $rtlCore (Join-Path $root $source)
            if ($LASTEXITCODE -ne 0) { throw "xvlog failed for $($set.Name): $source" }
        }
        Write-Host "VIP_SANITY_DUT_COMPILE_PASS: $($set.Name)"
    }
}
finally {
    Pop-Location
}
