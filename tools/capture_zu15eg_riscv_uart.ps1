param(
    [string[]]$Ports = @('COM9', 'COM10', 'COM11'),
    [int]$BaudRate = 115200,
    [int]$TimeoutSeconds = 5,
    [string]$OutDir = '.\build\zu15eg_riscv_bram_uart_20260813_cpu_only\uart_capture'
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$overallPass = $false

foreach ($port in $Ports) {
    $safeName = $port -replace '[^A-Za-z0-9_.-]', '_'
    $outFile = Join-Path $OutDir ("$safeName.txt")
    $serial = New-Object System.IO.Ports.SerialPort $port, $BaudRate, 'None', 8, 'One'
    $serial.ReadTimeout = 200
    $data = ''

    try {
        $serial.Open()
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 50
            $data += $serial.ReadExisting()
        }
        Set-Content -NoNewline -Path $outFile -Value $data
        if ($data -match 'TINYRISCV_BRAM_UART_SMOKE') {
            Write-Output "$port`: TINYRISCV_BRAM_UART_SMOKE"
            $overallPass = $true
        }
        else {
            Write-Output "$port`: marker not observed"
        }
    }
    catch {
        Set-Content -Path $outFile -Value ("OPEN_ERROR: " + $_.Exception.Message)
        Write-Output "$port`: OPEN_ERROR: $($_.Exception.Message)"
    }
    finally {
        if ($serial.IsOpen) { $serial.Close() }
        $serial.Dispose()
    }
}

if (-not $overallPass) {
    throw 'ZU15EG_RISCV_BRAM_UART_SMOKE=FAIL: marker was not observed on any selected COM port.'
}

Write-Output 'ZU15EG_RISCV_BRAM_UART_SMOKE=PASS'
