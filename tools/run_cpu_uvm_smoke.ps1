[CmdletBinding()]
param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "cpu_core_uvm_smoke",
    [ValidateSet('cpu_smoke_test', 'pipeline_hazard_test')]
    [string]$TestName = 'cpu_smoke_test'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$core = Join-Path $root 'rtl\core'
$uvm = Join-Path $root 'verify\uvm_cpu'
$uvmTb = Join-Path $uvm 'tb'
$uvmCommon = Join-Path $uvm 'common'
$uvmFormal = Join-Path $uvm 'formal'
$sim = Join-Path $root 'sim'
$sources = @('defines.v', 'cache_ram_1r1w.v', 'branch_predictor.v', 'clint.v', 'csr_reg.v', 'ctrl.v', 'div.v', 'ex.v', 'ex_mem.v', 'dcache.v', 'icache.v', 'id.v', 'id_ex.v', 'ifetch.v', 'if_id.v', 'mem.v', 'mem_wb.v', 'pc_reg.v', 'regs.v', 'riscv_cpu_core.v')

Push-Location $sim
try {
    foreach ($source in $sources) {
        & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '--uvm_version' '1.2' '-L' 'uvm' '-i' $core (Join-Path $core $source)
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    foreach ($source in @((Join-Path $uvmTb 'cpu_core_if.sv'), (Join-Path $uvmCommon 'cpu_core_uvm_pkg.sv'), (Join-Path $uvmFormal 'cpu_core_properties.sv'), (Join-Path $uvmTb 'cpu_core_uvm_tb.sv'))) {
        & (Join-Path $VivadoBin 'xvlog.bat') '--sv' '--uvm_version' '1.2' '-L' 'uvm' '-i' $core '-i' $uvmCommon '-i' $uvmTb '-i' (Join-Path $uvm 'agent') '-i' (Join-Path $uvm 'env') '-i' (Join-Path $uvm 'tests') $source
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & (Join-Path $VivadoBin 'xelab.bat') 'cpu_core_uvm_tb' '-L' 'uvm' '-s' $Snapshot '--timescale' '1ns/1ps'
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $xsimArgs = @($Snapshot)
    if ($TestName -eq 'pipeline_hazard_test') { $xsimArgs += @('--testplusarg', 'PIPELINE_HAZARD') }
    $xsimArgs += '--runall'
    $null = & (Join-Path $VivadoBin 'xsim.bat') @xsimArgs 2>&1 | Tee-Object -Variable output | Out-Host
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $lines = @($output | ForEach-Object { $_.ToString() })
    $transcript = $lines -join "`n"
    $uvmFailure = $transcript -match '(?m)^\s*UVM_(ERROR|FATAL)\s+[A-Za-z]'
    $assertionFailure = $transcript -match '(?im)^.*assertion.*(failed|error).*'
    $passTokens = switch ($TestName) {
        'pipeline_hazard_test' { @('CPU_UVM_PIPELINE_HAZARD_SCOREBOARD_PASS', 'CPU_UVM_PIPELINE_HAZARD_PASS') }
        default                { @('CPU_UVM_SCOREBOARD_PASS', 'CPU_UVM_SMOKE_PASS') }
    }
    if ($uvmFailure -or $assertionFailure -or (($passTokens | Where-Object { $transcript -notmatch $_ }).Count -ne 0)) {
        Write-Error "UVM test '$TestName' ended without all PASS tokens."
        exit 1
    }
} finally {
    Pop-Location
}
