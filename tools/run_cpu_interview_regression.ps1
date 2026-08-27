[CmdletBinding()]
param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [switch]$IncludeIsa
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tests = @(
    @{ Name = 'cpu_uvm_smoke'; Script = 'run_cpu_uvm_smoke.ps1' },
    @{ Name = 'cpu_uvm_pipeline_hazard'; Script = 'run_cpu_uvm_smoke.ps1'; TestName = 'pipeline_hazard_test'; Snapshot = 'cpu_uvm_pipeline_hazard' },
    @{ Name = 'jtag_dmi_cdc'; Script = 'run_jtag_dmi_cdc_tb.ps1' },
    @{ Name = 'jtag_user2_transport'; Script = 'run_jtag_user2_transport_tb.ps1' },
    @{ Name = 'id_jalr_forwarding'; Script = 'run_id_jalr_forwarding_tb.ps1' },
    @{ Name = 'branch_predictor'; Script = 'run_branch_predictor_tb.ps1' },
    @{ Name = 'dcache_store_path'; Script = 'run_dcache_store_path_tb.ps1' },
    @{ Name = 'axi4_cpu_ram_path'; Script = 'run_axi4_cpu_ram_path_tb.ps1' }
)

if ($IncludeIsa) {
    $tests += @{ Name = 'rv32ui_isa'; Script = 'run_isa_regression.ps1' }
}

$passed = 0
foreach ($test in $tests) {
    Write-Host "=== CPU_DV $($test.Name) ==="
    $invokeArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot $test.Script), '-VivadoBin', $VivadoBin)
    if ($test.ContainsKey('TestName')) { $invokeArgs += @('-TestName', $test.TestName) }
    if ($test.ContainsKey('Snapshot')) { $invokeArgs += @('-Snapshot', $test.Snapshot) }
    & powershell.exe @invokeArgs
    if ($LASTEXITCODE -ne 0) { throw "CPU DV regression failed: $($test.Name)" }
    $passed++
}

Write-Host "CPU_INTERVIEW_REGRESSION_PASS $passed/$($tests.Count)"
