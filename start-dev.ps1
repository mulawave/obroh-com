# Obroh.com Development Server Starter
# Starts all three services: backend (5000), website (3000), admin (3001)

Write-Host "Starting Obroh.com Development Environment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Check if we're in the right directory
if (-not (Test-Path "backend\src\server.ts")) {
    Write-Host "Error: Please run this script from the obroh.com root directory" -ForegroundColor Red
    exit 1
}

# Start all three services
Write-Host "`nStarting services..." -ForegroundColor Cyan

Write-Host "Starting Backend API on port 5000..." -ForegroundColor Yellow
$backendProcess = Start-Process -FilePath "npm" -ArgumentList "run", "dev" -WorkingDirectory "backend" -NoNewWindow -PassThru

Write-Host "Starting Website Frontend on port 3000..." -ForegroundColor Yellow
$websiteProcess = Start-Process -FilePath "npm" -ArgumentList "run", "dev" -WorkingDirectory "website" -NoNewWindow -PassThru

Write-Host "Starting Admin Panel on port 3001..." -ForegroundColor Yellow
$adminProcess = Start-Process -FilePath "npm" -ArgumentList "run", "dev" -WorkingDirectory "admin" -NoNewWindow -PassThru

Write-Host "`nWaiting for services to start..." -ForegroundColor Yellow

# Wait a bit for services to initialize
Start-Sleep -Seconds 10

Write-Host "`nService Status:" -ForegroundColor Cyan
Write-Host "-------------------" -ForegroundColor Cyan

if (-not $backendProcess.HasExited) {
    Write-Host "Backend API is running (PID: $($backendProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "Backend API failed to start" -ForegroundColor Red
}

if (-not $websiteProcess.HasExited) {
    Write-Host "Website Frontend is running (PID: $($websiteProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "Website Frontend failed to start" -ForegroundColor Red
}

if (-not $adminProcess.HasExited) {
    Write-Host "Admin Panel is running (PID: $($adminProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "Admin Panel failed to start" -ForegroundColor Red
}

Write-Host "`nDevelopment URLs:" -ForegroundColor Cyan
Write-Host "-------------------" -ForegroundColor Cyan
Write-Host "Website:     http://localhost:3000" -ForegroundColor White
Write-Host "Admin Panel: http://localhost:3001" -ForegroundColor White
Write-Host "Backend API: http://localhost:5000" -ForegroundColor White
Write-Host "API Health:  http://localhost:5000/api/health" -ForegroundColor White

Write-Host "`nTo stop all services, run:" -ForegroundColor Cyan
Write-Host "Stop-Process -Id $($backendProcess.Id),$($websiteProcess.Id),$($adminProcess.Id)" -ForegroundColor White
Write-Host "Or run: ./stop-dev.ps1" -ForegroundColor White

Write-Host "`nDevelopment environment ready!" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop monitoring (services will continue running)" -ForegroundColor White

# Monitor output
try {
    while ($true) {
        Start-Sleep -Seconds 30
        Write-Host "`n$(Get-Date -Format 'HH:mm:ss') - Services running..." -ForegroundColor Gray
    }
} catch {
    Write-Host "`nStopping monitor..." -ForegroundColor Yellow
}

# Cleanup on exit
Write-Host "`nStopping all services..." -ForegroundColor Yellow
Stop-Process -Id $backendProcess.Id -ErrorAction SilentlyContinue
Stop-Process -Id $websiteProcess.Id -ErrorAction SilentlyContinue
Stop-Process -Id $adminProcess.Id -ErrorAction SilentlyContinue
Write-Host "All services stopped" -ForegroundColor Green
