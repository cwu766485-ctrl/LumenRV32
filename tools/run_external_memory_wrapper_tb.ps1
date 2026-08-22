param(
    [string]$IverilogBin = "C:\iverilog\bin"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outDir = Join-Path $root "build\extmem_tb"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$env:PATH = "$IverilogBin;$env:PATH"
Push-Location $outDir
try {
    & iverilog -g2012 -I (Join-Path $root "rtl\core") -o extmem_tb.vvp `
        (Join-Path $root "tb\external_memory_wrapper_tb.sv") `
        (Join-Path $root "rtl\core\defines.v") `
        (Join-Path $root "rtl\perips\external_memory_wrapper.v")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & vvp .\extmem_tb.vvp
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
