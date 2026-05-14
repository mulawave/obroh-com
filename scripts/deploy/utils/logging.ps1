#!/usr/bin/env pwsh
#
# Logging utilities for deployment scripts
#

$global:LogFile = $null
$global:LogStartTime = Get-Date

function Initialize-Logging {
    $logDir = Join-Path $env:TEMP 'obroh-deployments'
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $global:LogFile = Join-Path $logDir "deploy_$timestamp.log"
    
    Write-Host ""
    Write-Host "[LOG] Log file: $($global:LogFile)" -ForegroundColor Gray
    Write-Host ""
}

function Write-LogSection {
    param([string]$Message)
    
    $divider = "=" * 80
    Write-Host ""
    Write-Host $divider -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host $divider -ForegroundColor Cyan
    Write-Host ""
    
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content $global:LogFile "[$timestamp] [SECTION] $Message"
}

function Write-LogInfo {
    param([string]$Message)
    
    Write-Host "[*] $Message" -ForegroundColor White
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content $global:LogFile "[$timestamp] [INFO] $Message"
}

function Write-LogSuccess {
    param([string]$Message)
    
    Write-Host $Message -ForegroundColor Green
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content $global:LogFile "[$timestamp] [SUCCESS] $Message"
}

function Write-LogWarning {
    param([string]$Message)
    
    Write-Host $Message -ForegroundColor Yellow
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content $global:LogFile "[$timestamp] [WARNING] $Message"
}

function Write-LogError {
    param([string]$Message)
    
    Write-Host $Message -ForegroundColor Red
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content $global:LogFile "[$timestamp] [ERROR] $Message"
}

function Get-ElapsedTime {
    $elapsed = (Get-Date) - $global:LogStartTime
    return "{0:hh\:mm\:ss}" -f $elapsed
}
