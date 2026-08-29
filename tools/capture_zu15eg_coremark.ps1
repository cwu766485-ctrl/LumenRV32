[CmdletBinding()]
param(
    [string[]]$Ports = @('COM9', 'COM10', 'COM11'),
    [int]$BaudRate = 115200,
    [ValidateRange(1, 200)]
    [int]$CpuClockMHz = 50,
    [ValidateRange(15, 600)]
    [int]$TimeoutSeconds = 45,
    [string]$OutDir = '.\build\zu15eg_coremark\uart_capture'
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
        $valid = $data -match 'Correct operation validated\.'
        $longEnough = $data -notmatch 'ERROR! Must execute for at least 10 secs'
        # CoreMark ports commonly print either the EEMBC-style "CoreMark 1.0"
        # line or the upstream "Iterations/Sec" line. Both report iterations/s.
        $score = [regex]::Match($data, '(?:CoreMark 1\.0\s*:\s*|Iterations/Sec\s*:\s*)([0-9]+(?:\.[0-9]+)?)')
        if ($valid -and $longEnough -and $score.Success) {
            $perSecond = [double]$score.Groups[1].Value
            $perMHz = $perSecond / $CpuClockMHz
            Write-Output "$port`: COREMARK_UART_PASS score_per_sec=$perSecond coremark_per_mhz=$perMHz cpu_clock_mhz=$CpuClockMHz"
            $overallPass = $true
        }
        else {
            Write-Output "$port`: CoreMark completion/CRC/duration marker not observed"
        }
    }
    catch {
        Set-Content -Path $outFile -Value ('OPEN_ERROR: ' + $_.Exception.Message)
        Write-Output "$port`: OPEN_ERROR: $($_.Exception.Message)"
    }
    finally {
        if ($serial.IsOpen) { $serial.Close() }
        $serial.Dispose()
    }
}

if (-not $overallPass) {
    throw 'ZU15EG_COREMARK_UART=FAIL: no valid >=10-second CoreMark output was captured.'
}

Write-Output 'ZU15EG_COREMARK_UART=PASS'
