#!/usr/bin/env pwsh
#
# Validation utilities for deployment scripts
#

function Test-DeploymentEnvironment {
    param([switch]$Verbose)
    
    Write-LogInfo "Checking deployment environment..."
    
    $errors = @()
    
    # Check gcloud CLI
    $gcloudCmd = Get-Command gcloud -ErrorAction SilentlyContinue
    if (-not $gcloudCmd) {
        $errors += "gcloud CLI not found or not in PATH"
    }
    else {
        $gcloudVersion = gcloud --version 2>&1 | Select-Object -First 1
        if ($Verbose) { Write-LogInfo "  [OK] gcloud CLI: $gcloudVersion" }
    }
    
    # Check gcloud authentication
    if ($gcloudCmd) {
        $gcloudAuth = gcloud auth list --format='value(account)' 2>$null | Select-Object -First 1
        if ($gcloudAuth) {
            if ($Verbose) { Write-LogInfo "  [OK] gcloud authenticated as: $gcloudAuth" }
        }
        else {
            $errors += "gcloud CLI not authenticated. Run: gcloud auth login"
        }
    }
    
    # Deployments use Cloud Build, so local Docker is not required.
    if ($Verbose) { Write-LogInfo "  [OK] Docker not required (Cloud Build pipeline)" }
    
    # Check GCP project
    if ($gcloudCmd) {
        $project = gcloud config get-value project 2>$null
        if ($project -and $project -ne '(unset)') {
            if ($Verbose) { Write-LogInfo "  [OK] GCP Project: $project" }
        }
        else {
            $errors += "GCP project not configured. Run: gcloud config set project PROJECT_ID"
        }
    }
    
    # Check Cloud Run API
    if ($gcloudCmd) {
        $services = gcloud run services list --region us-central1 --format='value(metadata.name)' 2>$null
        if ($LASTEXITCODE -eq 0) {
            if ($Verbose) { Write-LogInfo "  [OK] Cloud Run API accessible" }
        }
        else {
            $errors += "Cloud Run API not accessible"
        }
    }
    
    return @{
        Success = $errors.Count -eq 0
        Errors  = $errors
    }
}

function Test-ServiceDeployability {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('backend', 'admin', 'website')]
        [string]$Service
    )
    
    Write-LogInfo "Validating $Service service..."
    
    $issues = @()
    $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    
    # Check service-specific requirements
    if ($Service -eq 'backend') {
        $backendDir = Join-Path $repoRoot 'backend'
        if (-not (Test-Path $backendDir)) { $issues += "backend directory not found" }
        if (-not (Test-Path (Join-Path $backendDir 'package.json'))) { $issues += "backend/package.json not found" }
        if (-not (Test-Path (Join-Path $backendDir 'Dockerfile'))) { $issues += "backend/Dockerfile not found" }
        if (-not (Test-Path (Join-Path $backendDir 'cloudbuild.yaml'))) { $issues += "backend/cloudbuild.yaml not found" }
    }
    elseif ($Service -eq 'admin') {
        $adminDir = Join-Path $repoRoot 'admin'
        if (-not (Test-Path $adminDir)) { $issues += "admin directory not found" }
        if (-not (Test-Path (Join-Path $adminDir 'package.json'))) { $issues += "admin/package.json not found" }
        if (-not (Test-Path (Join-Path $adminDir 'cloudbuild.yaml'))) { $issues += "admin/cloudbuild.yaml not found" }
    }
    elseif ($Service -eq 'website') {
        $websiteDir = Join-Path $repoRoot 'website'
        if (-not (Test-Path $websiteDir)) { $issues += "website directory not found" }
        if (-not (Test-Path (Join-Path $websiteDir 'package.json'))) { $issues += "website/package.json not found" }
    }
    
    return @{
        Valid  = $issues.Count -eq 0
        Issues = $issues
    }
}

function Test-ServiceHealth {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('backend', 'admin', 'website')]
        [string]$Service
    )
    
    $config = Get-DeploymentConfig
    
    $urls = @{
        backend = "$($config.BackendUrl.TrimEnd('/'))/api/health"
        admin   = $config.AdminUrl
        website = $config.WebsiteUrl
    }
    
    $testUrl = $urls[$Service]
    
    $response = $null
    $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
    
    if ($response -and $response.StatusCode -eq 200) {
        return @{
            Healthy = $true
            Url     = $testUrl
            Status  = $response.StatusCode
        }
    } else {
        return @{
            Healthy = $false
            Url     = $testUrl
            Status  = "Unreachable"
        }
    }
}
