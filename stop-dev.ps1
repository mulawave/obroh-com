# Obroh.com Development Server Stopper
# Stops all three services

Write-Host "Stopping Obroh.com Development Environment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Stop all npm dev processes
Write-Host "Stopping npm dev processes..." -ForegroundColor Yellow
Get-Process | Where-Object { $_.ProcessName -eq "node" } | ForEach-Object {
    Write-Host "Stopping node process (PID: $($_.Id))" -ForegroundColor Gray
    Stop-Process -Id $_.Id -ErrorAction SilentlyContinue
}

Write-Host "All services stopped" -ForegroundColor Green
