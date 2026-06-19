param(
    [string]$RokuIP = "192.168.1.155",
    [int]$Port = 8085
)

Write-Host "Connecting to Roku at ${RokuIP}:${Port}..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop capturing logs" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient($RokuIP, $Port)
    $stream = $tcpClient.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    
    Write-Host "Connected! Waiting for logs..." -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Gray
    
    while ($true) {
        if ($stream.DataAvailable) {
            $line = $reader.ReadLine()
            if ($line) {
                if ($line -match "ERROR|WARNING") {
                    Write-Host $line -ForegroundColor Red
                } elseif ($line -match "====|Stream URL|Magnet") {
                    Write-Host $line -ForegroundColor Cyan
                } elseif ($line -match "response code|POST") {
                    Write-Host $line -ForegroundColor Yellow
                } else {
                    Write-Host $line
                }
            }
        }
        Start-Sleep -Milliseconds 10
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nMake sure:" -ForegroundColor Yellow
    Write-Host "  1. Roku is powered on and on same network" -ForegroundColor Yellow
    Write-Host "  2. Developer mode is enabled" -ForegroundColor Yellow
    Write-Host "  3. IP address is correct: $RokuIP" -ForegroundColor Yellow
}
finally {
    if ($reader) { $reader.Close() }
    if ($stream) { $stream.Close() }
    if ($tcpClient) { $tcpClient.Close() }
}
