param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('backend', 'admin', 'website', 'all')]
    [string]$Service,

    [switch]$Validate,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$utilsPath = Join-Path $scriptRoot 'utils'
$servicesPath = Join-Path $scriptRoot 'services'
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)

function Test-DeployPipelineIntegrity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    if (-not (Test-Path $ManifestPath)) {
        throw "Deployment manifest not found: $ManifestPath"
    }

    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $issues = @()

    foreach ($entry in $manifest.files) {
        $relativePath = [string]$entry.path
        $expectedSha256 = [string]$entry.sha256
        $targetPath = Join-Path $RootPath $relativePath

        if (-not (Test-Path $targetPath)) {
            $issues += "Missing protected deployment file: $relativePath"
            continue
        }

        $actualSha256 = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualSha256 -ne $expectedSha256.ToLowerInvariant()) {
            $issues += "Protected deployment file changed: $relativePath"
        }
    }

    return $issues
}

. (Join-Path $utilsPath 'logging.ps1')
. (Join-Path $utilsPath 'validation.ps1')
. (Join-Path $utilsPath 'config.ps1')

Initialize-Logging

Write-LogSection "Deployment Pipeline Lock"
$manifestPath = Join-Path $scriptRoot 'pipeline-manifest.json'
$integrityIssues = Test-DeployPipelineIntegrity -ManifestPath $manifestPath -RootPath $repoRoot

if ($integrityIssues.Count -gt 0) {
    $override = $env:OBROH_DEPLOY_PIPELINE_CHANGE_APPROVED
    if ($override -ne 'true') {
        Write-LogError "Deployment pipeline integrity check failed. This pipeline is locked and cannot be changed without explicit approval."
        foreach ($issue in $integrityIssues) {
            Write-LogError " - $issue"
        }
        Write-LogError "If and only if the owner approved pipeline changes, set OBROH_DEPLOY_PIPELINE_CHANGE_APPROVED=true for this run."
        exit 1
    }

    Write-LogWarning "Pipeline integrity override is active via OBROH_DEPLOY_PIPELINE_CHANGE_APPROVED=true"
}

$env:OBROH_DEPLOY_ENTRYPOINT = 'scripts/deploy/deploy.ps1'
Write-LogSuccess "Single source deploy entrypoint enforced"

Write-LogInfo "Obroh deployment started"
Write-LogInfo "Service=$Service Validate=$Validate Force=$Force"

Write-LogSection "Phase 1: Environment Validation"
$validationResult = Test-DeploymentEnvironment -Verbose
if (-not $validationResult.Success) {
    Write-LogError "Environment validation failed"
    foreach ($err in $validationResult.Errors) {
        Write-LogError " - $err"
    }
    exit 1
}
Write-LogSuccess "Environment validation passed"

Write-LogSection "Phase 2: Service Validation"
$servicesToDeploy = @()
if ($Service -eq 'all') {
    $servicesToDeploy = @('backend', 'admin', 'website')
}
else {
    $servicesToDeploy = @($Service)
}

Write-LogInfo ("Services to deploy: {0}" -f ($servicesToDeploy -join ', '))

foreach ($svc in $servicesToDeploy) {
    $svcValidation = Test-ServiceDeployability -Service $svc
    if (-not $svcValidation.Valid) {
        Write-LogError ("Service validation failed for {0}: {1}" -f $svc, ($svcValidation.Issues -join '; '))
        exit 1
    }
    Write-LogSuccess ("{0} service validated" -f $svc)
}

if (-not $Validate -and -not $Force) {
    Write-LogSection "Phase 3: Deployment Confirmation"
    Write-LogWarning "This will deploy to PRODUCTION"
    foreach ($svc in $servicesToDeploy) {
        Write-Host (" - {0}" -f $svc) -ForegroundColor Cyan
    }

    $response = Read-Host "Continue with deployment? (yes/no)"
    if ($response -ne 'yes') {
        Write-LogWarning "Deployment cancelled"
        exit 0
    }
}

if ($Force) {
    Write-LogInfo "Force mode enabled; skipping confirmation"
}

Write-LogSection "Phase 4: Deployment Execution"
$deploymentResults = @()

foreach ($svc in $servicesToDeploy) {
    $scriptPath = Join-Path $servicesPath ("{0}.ps1" -f $svc)

    if ($Validate) {
        Write-LogInfo ("Validating service script for {0}" -f $svc)
        $result = & $scriptPath -Validate -Force
        if ($null -ne $result -and $result.ContainsKey('Success') -and -not $result.Success) {
            Write-LogError ("Validation failed for {0}" -f $svc)
            exit 1
        }
    }
    else {
        Write-LogInfo ("Deploying {0}" -f $svc)
        $result = & $scriptPath -Force
        if ($null -eq $result) {
            Write-LogError ("Deployment script for {0} returned no result" -f $svc)
            exit 1
        }

        if ($result.ContainsKey('Success') -and -not $result.Success) {
            Write-LogError ("Deployment failed for {0}" -f $svc)
            exit 1
        }

        if ($result) {
            $deploymentResults += $result
        }
    }
}

if (-not $Validate) {
    Write-LogSection "Phase 5: Post Deployment Verification"

    foreach ($result in $deploymentResults) {
        if ($null -ne $result -and $result.Service) {
            $svc = $result.Service
            Write-LogInfo ("Verifying {0}" -f $svc)

            $healthResult = Test-ServiceHealth -Service $svc
            if ($healthResult.Healthy) {
                Write-LogSuccess ("{0} is healthy" -f $svc)
                Write-LogInfo ("Revision: {0}" -f $result.Revision)
                Write-LogInfo ("URL: {0}" -f $healthResult.Url)
            }
            else {
                Write-LogWarning ("Health check failed or inconclusive for {0}" -f $svc)
            }
        }
    }
}

Write-LogSection "Deployment Summary"
if ($Validate) {
    Write-LogSuccess "Validation completed successfully"
}
else {
    Write-LogSuccess "Deployment completed successfully"
}

exit 0
