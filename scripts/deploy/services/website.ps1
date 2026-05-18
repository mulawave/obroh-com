#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Website Service Deployment Script
    
.DESCRIPTION
    Builds and deploys the Next.js website to Cloud Run.
    Handles Docker build, image push to Artifact Registry, and Cloud Run deployment.
    
.PARAMETER Validate
    Perform validation only without deploying
    
.PARAMETER Force
    Skip confirmation prompts

.NOTES
    Location: z:\obroh.com\scripts\deploy\services\website.ps1
    Service: obroh-website
    Platform: Cloud Run (us-central1)
#>

param(
    [switch]$Validate,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
$PSNativeCommandUseErrorActionPreference = $false

if ($env:OBROH_DEPLOY_ENTRYPOINT -ne 'scripts/deploy/deploy.ps1') {
    Write-Error "Direct execution is blocked. Use scripts/deploy/deploy.ps1 as the only approved deployment entrypoint."
    exit 1
}

$scriptRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$utilsPath = Join-Path $scriptRoot 'utils'

# Import utilities
. (Join-Path $utilsPath 'logging.ps1')
. (Join-Path $utilsPath 'validation.ps1')
. (Join-Path $utilsPath 'config.ps1')

if (-not $global:LogFile) {
    Initialize-Logging
}

try {
    Write-LogInfo "Website Service Deployment"
    
    $config = Get-DeploymentConfig
    $svcConfig = Get-ServiceConfig -Service 'website'
    $websiteDir = Join-Path $repoRoot 'website'
    $backendUrl = gcloud run services describe $config.BackendService `
        --region $config.Region `
        --project $config.Project `
        --format='value(status.url)' 2>$null

    if (-not $backendUrl) {
        Write-LogError "Unable to resolve backend service URL for NEXT_PUBLIC_API_URL"
        return @{ Success = $false }
    }

    $backendApiUrl = "$($backendUrl.TrimEnd('/'))/api"
    
    Write-LogInfo "Service: $($svcConfig.ServiceName)"
    Write-LogInfo "Region: $($config.Region)"
    Write-LogInfo "Image: $($config.RegistryUrl)/$($svcConfig.ImageName)"
    
    # ============================================================================
    # VALIDATION
    # ============================================================================
    Write-LogInfo "Validating website service..."
    
    $validation = Test-ServiceDeployability -Service 'website'
    if (-not $validation.Valid) {
        Write-LogError "Validation failed: $($validation.Issues -join ', ')"
        return @{ Success = $false }
    }
    
    Write-LogSuccess "Website service validation passed"
    
    if ($Validate) {
        return @{ Success = $true }
    }
    
    # ============================================================================
    # BUILD (Cloud Build)
    # ============================================================================
    Write-LogInfo "Building image with Cloud Build..."
    Push-Location $websiteDir
    
    try {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $imageTag = "$($config.RegistryUrl)/$($svcConfig.ImageName):$timestamp"
        
        Write-LogInfo "Building: $imageTag"
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $buildOutput = gcloud builds submit . `
            --config cloudbuild.yaml `
            --project $config.Project `
            --region $config.Region `
            --quiet `
            --substitutions "_IMAGE=$imageTag,_NEXT_PUBLIC_API_URL=$backendApiUrl,_NEXT_PUBLIC_FIREBASE_ANALYTICS_ENABLED=true" 2>&1
        $buildExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference

        if ($buildExitCode -ne 0) {
            Write-LogError ("Cloud Build failed with exit code {0}" -f $buildExitCode)
            if ($buildOutput) {
                Write-LogError ($buildOutput | Out-String)
            }
            return @{ Success = $false }
        }

        Write-LogSuccess "Cloud Build completed and image pushed"
        
        # ========================================================================
        # DEPLOY
        # ========================================================================
        Write-LogInfo "Deploying to Cloud Run..."
        $envVars = "NODE_ENV=production,HOSTNAME=0.0.0.0,NEXT_PUBLIC_API_URL=$backendApiUrl"
        
        $ErrorActionPreference = 'Continue'
        $deployOutput = gcloud run deploy $svcConfig.ServiceName `
            --image $imageTag `
            --region $config.Region `
            --project $config.Project `
            --quiet `
            --memory $svcConfig.Memory `
            --cpu $svcConfig.Cpu `
            --timeout $svcConfig.Timeout `
            --max-instances $svcConfig.MaxInstances `
            --min-instances $svcConfig.MinInstances `
            --set-env-vars "$envVars" `
            --allow-unauthenticated `
            --platform managed 2>&1
        $deployExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        
        if ($deployExitCode -ne 0) {
            Write-LogError ("Cloud Run deployment failed with exit code {0}" -f $deployExitCode)
            if ($deployOutput) {
                Write-LogError ($deployOutput | Out-String)
            }
            return @{ Success = $false }
        }
        
        Write-LogSuccess "Deployed to Cloud Run successfully"
        
        # ========================================================================
        # GET REVISION INFO
        # ========================================================================
        $revision = gcloud run services describe $svcConfig.ServiceName `
            --region $config.Region `
            --format='value(status.traffic[0].revisionName)' 2>&1
        
        $url = gcloud run services describe $svcConfig.ServiceName `
            --region $config.Region `
            --format='value(status.url)' 2>&1
        
        Write-LogSuccess "Website deployment completed"
        Write-LogInfo "  Revision: $revision"
        Write-LogInfo "  URL: $url"
        
        return @{
            Success  = $true
            Service  = 'website'
            Revision = $revision
            Url      = $url
        }
    }
    finally {
        Pop-Location
    }
}
catch {
    Write-LogError "Website deployment error: $_"
    return @{ Success = $false }
}
finally {
    $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
}
