[CmdletBinding()]
param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.1\bin",
    [string]$Snapshot = "tinyriscv_tb",
    [string]$BinaryPath = "",
    [string]$PythonExe = "python",
    [UInt64]$SimTimeoutNs = 500000,
    [int]$RomDepth = 8192,
    [int]$RomWaitCycles = -1,
    [int]$RamWaitCycles = -1,
    [int]$ICacheLineWords = -1,
    [int]$ICacheLineCount = -1,
    [int]$DCacheLineWords = -1,
    [int]$DCacheLineCount = -1,
    [switch]$DisableICache,
    [switch]$CoreMarkDone,
    [string]$SimDir = "",
    [string]$ExtMemInitFile = "",
    [int]$ExtMemDepthWords = -1,
    [string[]]$ExtraDefines = @()
)

$ErrorActionPreference = "Stop"

function Resolve-ExecutablePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Candidate,
        [string[]]$Fallbacks = @()
    )

    $command = Get-Command $Candidate -ErrorAction SilentlyContinue
    if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
        if ($command.Source -notlike "*WindowsApps\\python.exe") {
            return $command.Source
        }
    }

    foreach ($fallback in $Fallbacks) {
        if (-not [string]::IsNullOrWhiteSpace($fallback) -and (Test-Path $fallback)) {
            return $fallback
        }
    }

    throw "Unable to resolve executable: $Candidate"
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($SimDir)) {
    $simDir = Join-Path $root "sim"
    $macroFile = Join-Path $root "build\xsim_program_macros.v"
} else {
    if (-not [System.IO.Path]::IsPathRooted($SimDir)) {
        $SimDir = Join-Path $root $SimDir
    }
    New-Item -ItemType Directory -Force -Path $SimDir | Out-Null
    $simDir = (Resolve-Path $SimDir).Path
    # Keep isolated runs independent from the shared sim/inst.data and the
    # default build macro file used by older scripts.
    $macroFile = Join-Path $simDir "xsim_program_macros.v"
}
$binToMem = Join-Path $root "tools\BinToMem_CLI.py"
$instData = Join-Path $simDir "inst.data"
$rtlCoreDir = Join-Path $root "rtl\core"
$pythonResolved = Resolve-ExecutablePath -Candidate $PythonExe -Fallbacks @(
    "C:\.platformio\penv\Scripts\python.exe",
    "C:\.platformio\python3\python.exe"
)
$sourceFiles = @(
    (Join-Path $root "tb\tinyriscv_soc_tb.v"),
    (Join-Path $root "rtl\core\clint.v"),
    (Join-Path $root "rtl\core\csr_reg.v"),
    (Join-Path $root "rtl\core\ctrl.v"),
    (Join-Path $root "rtl\core\defines.v"),
    (Join-Path $root "rtl\core\cache_ram_1r1w.v"),
    (Join-Path $root "rtl\core\branch_predictor.v"),
    (Join-Path $root "rtl\core\div.v"),
    (Join-Path $root "rtl\core\ex.v"),
    (Join-Path $root "rtl\core\ex_mem.v"),
    (Join-Path $root "rtl\core\dcache.v"),
    (Join-Path $root "rtl\core\icache.v"),
    (Join-Path $root "rtl\core\id.v"),
    (Join-Path $root "rtl\core\id_ex.v"),
    (Join-Path $root "rtl\core\ifetch.v"),
    (Join-Path $root "rtl\core\if_id.v"),
    (Join-Path $root "rtl\core\mem.v"),
    (Join-Path $root "rtl\core\mem_wb.v"),
    (Join-Path $root "rtl\core\pc_reg.v"),
    (Join-Path $root "rtl\core\regs.v"),
    (Join-Path $root "rtl\core\riscv_cpu_core.v"),
    (Join-Path $root "rtl\interconnect\native_to_axi4_master.v"),
    (Join-Path $root "rtl\interconnect\axi4_crossbar.v"),
    (Join-Path $root "rtl\interconnect\axi4_to_native_slave.v"),
    (Join-Path $root "rtl\interconnect\axi4_to_apb_bridge.v"),
    (Join-Path $root "rtl\interconnect\axi4_control_island.v"),
    (Join-Path $root "rtl\perips\axi_lite_bridge.v"),
    (Join-Path $root "rtl\perips\axi_lite_apb_bridge.v"),
    (Join-Path $root "rtl\perips\apb_perips.v"),
    (Join-Path $root "rtl\perips\ram.v"),
    (Join-Path $root "rtl\perips\rom.v"),
    (Join-Path $root "rtl\perips\timer.v"),
    (Join-Path $root "rtl\perips\uart.v"),
    (Join-Path $root "rtl\perips\gpio.v"),
    (Join-Path $root "rtl\perips\i2c_master.v"),
    (Join-Path $root "rtl\perips\spi.v"),
    (Join-Path $root "rtl\perips\qspi.v"),
    (Join-Path $root "rtl\perips\pmu.v"),
    (Join-Path $root "rtl\perips\dma.v"),
    (Join-Path $root "rtl\perips\dma_axil_wrapper.v"),
    (Join-Path $root "rtl\perips\external_memory_wrapper.v"),
    (Join-Path $root "rtl\perips\axi4_extmem_bridge.v"),
    (Join-Path $root "rtl\perips\axi4_mem_model.v"),
    (Join-Path $root "rtl\debug\jtag_dm.v"),
    (Join-Path $root "rtl\debug\jtag_driver.v"),
    (Join-Path $root "rtl\utils\jtag_cdc_reset_sync.v"),
    (Join-Path $root "rtl\debug\jtag_top.v"),
    (Join-Path $root "rtl\debug\uart_debug.v"),
    (Join-Path $root "rtl\soc\heterogeneous_soc_top.v"),
    (Join-Path $root "rtl\utils\full_handshake_rx.v"),
    (Join-Path $root "rtl\utils\full_handshake_tx.v"),
    (Join-Path $root "rtl\utils\gen_buf.v"),
    (Join-Path $root "rtl\utils\gen_dff.v")
)

if ([string]::IsNullOrWhiteSpace($BinaryPath)) {
    $BinaryPath = Join-Path $root "tests\example\coremark\coremark.bin"
} elseif (-not [System.IO.Path]::IsPathRooted($BinaryPath)) {
    $BinaryPath = (Resolve-Path $BinaryPath).Path
}

New-Item -ItemType Directory -Force -Path (Split-Path $macroFile) | Out-Null
$macroLines = [System.Collections.Generic.List[string]]::new()
$macroLines.Add(('`define RomNum {0}' -f $RomDepth))
$macroLines.Add(('`define SIM_TIMEOUT 64''d{0}' -f $SimTimeoutNs))
$macroLines.Add('`define DISABLE_WAVE_DUMP')
if ($CoreMarkDone) {
    $macroLines.Add('`define COREMARK_SIM_DONE')
}
if ($RomWaitCycles -ge 0) {
    $macroLines.Add(('`define RomWaitCycles {0}' -f $RomWaitCycles))
}
if ($RamWaitCycles -ge 0) {
    $macroLines.Add(('`define RamWaitCycles {0}' -f $RamWaitCycles))
}
if ($ICacheLineWords -ge 0) {
    $macroLines.Add(('`define ICacheLineWords {0}' -f $ICacheLineWords))
}
if ($ICacheLineCount -ge 0) {
    $macroLines.Add(('`define ICacheLineCount {0}' -f $ICacheLineCount))
}
if ($DCacheLineWords -ge 0) {
    $macroLines.Add(('`define DCacheLineWords {0}' -f $DCacheLineWords))
}
if ($DCacheLineCount -ge 0) {
    $macroLines.Add(('`define DCacheLineCount {0}' -f $DCacheLineCount))
}
if ($DisableICache) {
    $macroLines.Add('`define DisableICache')
}
if ($ExtMemDepthWords -gt 0) {
    $macroLines.Add(('`define ExtMemDepthWords {0}' -f $ExtMemDepthWords))
}
if (-not [string]::IsNullOrWhiteSpace($ExtMemInitFile)) {
    if (-not [System.IO.Path]::IsPathRooted($ExtMemInitFile)) {
        $ExtMemInitFile = Join-Path $root $ExtMemInitFile
    }
    $resolvedExtMemInit = (Resolve-Path $ExtMemInitFile).Path.Replace('\', '/')
    $macroLines.Add(('`define ExtMemInitFile "{0}"' -f $resolvedExtMemInit))
}
foreach ($define in $ExtraDefines) {
    if (-not [string]::IsNullOrWhiteSpace($define)) {
        $parts = $define.Split('=', 2)
        if ($parts.Length -eq 2) {
            $macroLines.Add(('`define {0} {1}' -f $parts[0], $parts[1]))
        } else {
            $macroLines.Add(('`define {0}' -f $define))
        }
    }
}
Set-Content -Path $macroFile -Encoding ASCII -Value $macroLines

$compileArgs = @("--sv", "-i", $rtlCoreDir)

Push-Location $simDir
try {
    & $pythonResolved $binToMem $BinaryPath $instData
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    foreach ($source in $sourceFiles) {
        & (Join-Path $VivadoBin "xvlog.bat") @compileArgs $macroFile $source
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    & (Join-Path $VivadoBin "xelab.bat") "tinyriscv_soc_tb" "-s" $Snapshot "--timescale" "1ns/1ps" "--override_timeunit" "--override_timeprecision"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $null = & (Join-Path $VivadoBin "xsim.bat") $Snapshot "--runall" 2>&1 |
        Tee-Object -Variable simOutput |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $simLines = @($simOutput | ForEach-Object { $_.ToString() })
    if ($simLines -match 'Time Out\.') {
        Write-Error "Simulation timed out before PASS."
        exit 1
    }
    if ($simLines -match '(ARCH_X:|TEST_FAIL|[A-Z0-9_]+_FAIL\b)') {
        Write-Error "Simulation reported FAIL."
        exit 1
    }

    exit 0
}
finally {
    Pop-Location
}
