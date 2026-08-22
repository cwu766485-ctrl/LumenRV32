param([string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin", [string]$Snapshot = "axi4_cpu_ram_path_tb")
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildDir = Join-Path $root "build\axi4_cpu_ram_path_tb"
$sources = @("rtl\core\defines.v", "rtl\interconnect\native_to_axi4_master.v", "rtl\interconnect\axi4_crossbar.v", "rtl\interconnect\axi4_to_native_slave.v", "rtl\perips\ram.v", "tb\axi4_cpu_ram_path_tb.sv") | ForEach-Object { Join-Path $root $_ }
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
Push-Location $buildDir
try {
    Remove-Item -Recurse -Force xsim.dir -ErrorAction SilentlyContinue
    foreach ($source in $sources) { & (Join-Path $VivadoBin "xvlog.bat") "--sv" "-i" (Join-Path $root "rtl\core") $source; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }
    & (Join-Path $VivadoBin "xelab.bat") "axi4_cpu_ram_path_tb" "-s" $Snapshot; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $output = & (Join-Path $VivadoBin "xsim.bat") $Snapshot "--runall" 2>&1; $output | Set-Content -Encoding ASCII (Join-Path $buildDir "run.log")
    if ($LASTEXITCODE -ne 0 -or ($output | Out-String) -notmatch "AXI4_CPU_RAM_PATH_PASS") { throw "AXI4 CPU RAM path test failed." }
    $output | Select-String "AXI4_CPU_RAM_PATH_PASS"
} finally { Pop-Location }
