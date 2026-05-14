#!/usr/bin/env pwsh
#
# Deployment configuration and service details
#

function Get-DeploymentConfig {
    
    return @{
        Project                = 'raven-ai-6ff76'
        Region                 = 'us-central1'
        RegistryUrl            = 'us-central1-docker.pkg.dev/raven-ai-6ff76/raven-api'
        
        # Services
        BackendService         = 'obroh-backend'
        AdminService           = 'obroh-admin'
        WebsiteService         = 'obroh-website'
        
        # URLs
        BackendUrl             = 'https://obroh-backend-zoeqld5lsa-uc.a.run.app'
        AdminUrl               = 'https://obroh-admin-zoeqld5lsa-uc.a.run.app'
        WebsiteUrl             = 'https://obroh-website-zoeqld5lsa-uc.a.run.app'
        
        # Build configs
        Backend = @{
            Name               = 'obroh-backend'
            ServiceName        = 'obroh-backend'
            ImageName          = 'obroh-backend'
            Memory             = '512Mi'
            Cpu                = '1'
            Timeout            = '300'
            MaxInstances       = '20'
            MinInstances       = '0'
            AllowUnauthenticated = $true
        }
        
        Admin = @{
            Name               = 'obroh-admin'
            ServiceName        = 'obroh-admin'
            ImageName          = 'obroh-admin'
            Memory             = '1Gi'
            Cpu                = '1'
            Timeout            = '300'
            MaxInstances       = '50'
            MinInstances       = '0'
            AllowUnauthenticated = $true
        }
        
        Website = @{
            Name               = 'obroh-website'
            ServiceName        = 'obroh-website'
            ImageName          = 'obroh-website'
            Memory             = '512Mi'
            Cpu                = '1'
            Timeout            = '300'
            MaxInstances       = '10'
            MinInstances       = '0'
            AllowUnauthenticated = $true
        }
    }
}

function Get-ServiceConfig {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('backend', 'admin', 'website')]
        [string]$Service
    )
    
    $config = Get-DeploymentConfig
    
    switch ($Service) {
        'backend' { return $config.Backend }
        'admin' { return $config.Admin }
        'website' { return $config.Website }
    }
}

function Get-CurrentRevision {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('backend', 'admin', 'website')]
        [string]$Service
    )
    
    $config = Get-DeploymentConfig
    $serviceName = $config."$($Service)Service"
    
    try {
        $revision = gcloud run services describe $serviceName `
            --region $config.Region `
            --format='value(status.traffic[0].revisionName)' 2>&1
        
        return $revision -replace '-\d{5}-\w{3}$', ''
    }
    catch {
        return $null
    }
}

function Get-ServiceUrl {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('backend', 'admin', 'website')]
        [string]$Service
    )
    
    $config = Get-DeploymentConfig
    $serviceName = $config."$($Service)Service"
    
    try {
        $url = gcloud run services describe $serviceName `
            --region $config.Region `
            --format='value(status.url)' 2>&1
        
        return $url
    }
    catch {
        return $null
    }
}
