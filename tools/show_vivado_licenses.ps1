param(
    [string]$LicensePath = $env:XILINXD_LICENSE_FILE,
    [switch]$All
)

if ([string]::IsNullOrWhiteSpace($LicensePath)) {
    $LicensePath = [Environment]::GetEnvironmentVariable("XILINXD_LICENSE_FILE", "User")
}

Write-Host "Vivado license search path:"
Write-Host "  XILINXD_LICENSE_FILE = $LicensePath"
Write-Host "  LM_LICENSE_FILE      = $env:LM_LICENSE_FILE"
Write-Host ""

if ([string]::IsNullOrWhiteSpace($LicensePath)) {
    throw "XILINXD_LICENSE_FILE is not configured."
}

$files = $LicensePath -split ";" | Where-Object {
    $_ -and (Test-Path -LiteralPath $_ -PathType Leaf)
}

if ($files.Count -eq 0) {
    throw "No local license file was found in XILINXD_LICENSE_FILE."
}

$features = foreach ($file in $files) {
    $lines = Get-Content -LiteralPath $file
    foreach ($line in $lines) {
        if ($line -match "^\s*(INCREMENT|FEATURE|PACKAGE)\s+(\S+)\s+\S+\s+(\S+)\s+(\S+)") {
            [PSCustomObject]@{
                File    = $file
                Type    = $Matches[1]
                Feature = $Matches[2]
                Version = $Matches[3]
                Expiry  = $Matches[4]
            }
        }
    }
}

Write-Host "Vivado edition and implementation features:"
$features |
    Where-Object {
        $_.Feature -match "Vivado|Synthesis|Implementation|Simulation|HLS|PartialReconfiguration"
    } |
    Sort-Object Feature, Type -Unique |
    Format-Table Type, Feature, Version, Expiry -AutoSize

if ($All) {
    Write-Host ""
    Write-Host "All licensed feature names:"
    $features |
        Sort-Object Feature, Type -Unique |
        Format-Table Type, Feature, Version, Expiry -AutoSize
} else {
    Write-Host ""
    Write-Host "Use -All to list every licensed IP feature:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File tools/show_vivado_licenses.ps1 -All"
}

Write-Host ""
Write-Host "Note: the license file contents describe available features."
Write-Host "A real synth_design/route_design checkout is the final proof that a device is usable."
