$ip = '192.168.1.155'
Write-Host "Pressing Home..."
Invoke-RestMethod -Uri "http://$($ip):8060/keypress/Home" -Method Post
Start-Sleep -Seconds 3

Write-Host "Launching dev app..."
Invoke-RestMethod -Uri "http://$($ip):8060/launch/dev" -Method Post
Start-Sleep -Seconds 10

Write-Host "Starting telnet listener in background..."
$telnetJob = Start-Job -ScriptBlock {
    python C:\Users\aricz\Documents\GitHub\spamfilms3_ui\spamfilms-roku\hero-grid-channel\telnet_verify_socket.py
}
Start-Sleep -Seconds 2

Write-Host "Pressing DOWN to go to Series..."
Invoke-RestMethod -Uri "http://$($ip):8060/keypress/Down" -Method Post
Start-Sleep -Seconds 3

Write-Host "Pressing OK to open the series..."
Invoke-RestMethod -Uri "http://$($ip):8060/keypress/Select" -Method Post
Start-Sleep -Seconds 15

Write-Host "Pressing RIGHT to select an episode..."
Invoke-RestMethod -Uri "http://$($ip):8060/keypress/Right" -Method Post
Start-Sleep -Seconds 2

Write-Host "Pressing OK to play episode..."
Invoke-RestMethod -Uri "http://$($ip):8060/keypress/Select" -Method Post
Start-Sleep -Seconds 10

Write-Host "Stopping telnet listener..."
Stop-Job $telnetJob
$logs = Receive-Job $telnetJob
Remove-Job $telnetJob

Write-Host "
--- TELNET LOGS ---"
$logs | ForEach-Object { Write-Host $_ }
