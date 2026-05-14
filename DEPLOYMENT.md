# Obroh Deployment System

**Enterprise-grade, locked-down deployment system for safe, repeatable, and auditable production deployments.**

---

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [System Architecture](#system-architecture)
- [Installation & Prerequisites](#installation--prerequisites)
- [Usage Guide](#usage-guide)
- [Services & Configuration](#services--configuration)
- [Safety Features](#safety-features)
- [Troubleshooting](#troubleshooting)
- [For Agents & Automation](#for-agents--automation)

---

## 🚀 Quick Start

### Deploy a Single Service

```powershell
# Deploy backend service
cd z:\obroh.com\scripts\deploy
.\deploy.ps1 -Service backend

# Deploy admin service
.\deploy.ps1 -Service admin

# Deploy website service
.\deploy.ps1 -Service website
```

### Deploy All Services

```powershell
.\deploy.ps1 -Service all
```

### Validate Without Deploying

```powershell
# Validate backend readiness
.\deploy.ps1 -Service backend -Validate

# Validate all services
.\deploy.ps1 -Service all -Validate
```

### Force Deployment (Automation)

```powershell
# Skip confirmation prompts (useful in CI/CD)
.\deploy.ps1 -Service backend -Force
```

---

## 🏗️ System Architecture

### Directory Structure

```
z:\obroh.com\
├── scripts/deploy/                    # Main deployment system
│   ├── deploy.ps1                     # Main orchestration script
│   ├── services/                      # Service-specific deployments
│   │   ├── backend.ps1                # Backend service deployment
│   │   ├── admin.ps1                  # Admin service deployment
│   │   └── website.ps1                # Website service deployment
│   └── utils/                         # Shared utilities
│       ├── logging.ps1                # Logging and output formatting
│       ├── validation.ps1             # Pre-deployment validation
│       └── config.ps1                 # Configuration and service details
├── backend/                           # Backend service
│   ├── Dockerfile
│   ├── cloudbuild.yaml
│   └── package.json
├── admin/                             # Admin service
│   ├── Dockerfile
│   ├── cloudbuild.yaml
│   └── package.json
└── website/                           # Website service
    ├── Dockerfile
    └── package.json
```

### Deployment Flow

```
┌─────────────────┐
│ User/CI invokes │
│  deploy.ps1     │
└────────┬────────┘
         │
         ▼
┌────────────────────────────────┐
│ PHASE 1: Environment Validation│
│ - gcloud CLI auth              │
│ - Docker running               │
│ - GCP project configured       │
└────────┬───────────────────────┘
         │
         ▼
┌────────────────────────────────┐
│ PHASE 2: Service Validation    │
│ - Source files exist           │
│ - Dockerfile present           │
│ - package.json valid           │
└────────┬───────────────────────┘
         │
         ▼
┌────────────────────────────────┐
│ PHASE 3: Confirmation          │
│ - Display services to deploy   │
│ - Get user approval (or -Force)│
└────────┬───────────────────────┘
         │
         ▼
┌────────────────────────────────┐
│ PHASE 4: Build & Deploy        │
│ For each service:              │
│ 1. Docker build                │
│ 2. Push to Artifact Registry   │
│ 3. Deploy to Cloud Run         │
│ 4. Update routing (100% new)   │
└────────┬───────────────────────┘
         │
         ▼
┌────────────────────────────────┐
│ PHASE 5: Health Verification   │
│ - Service health check         │
│ - Endpoint responsiveness      │
│ - Display results              │
└────────┬───────────────────────┘
         │
         ▼
┌────────────────────────────────┐
│ Deployment Summary             │
│ - Revision info                │
│ - Service URLs                 │
│ - Status: SUCCESS or FAILED    │
└────────────────────────────────┘
```

---

## ⚙️ Installation & Prerequisites

### Required Tools

1. **PowerShell 5.1+** (Windows) or **PowerShell Core 7+** (Linux/macOS)
   - Check: `$PSVersionTable.PSVersion`

2. **Google Cloud CLI (gcloud)**
   - Installation: https://cloud.google.com/sdk/docs/install
   - Verify: `gcloud --version`
   - Authenticate: `gcloud auth login`

3. **Docker**
   - Installation: https://www.docker.com/products/docker-desktop
   - Verify: `docker --version`
   - Running: `docker ps` (must not error)

4. **Git** (recommended, for source control)
   - Verify: `git --version`

### GCP Setup

1. **Authenticate with GCP**
   ```powershell
   gcloud auth login
   ```

2. **Set active project**
   ```powershell
   gcloud config set project raven-ai-6ff76
   ```

3. **Verify permissions**
   ```powershell
   # You need roles: Cloud Run Admin, Service Accounts Admin, Editor
   gcloud projects get-iam-policy raven-ai-6ff76 --flatten="bindings[].members" --filter="bindings.members:serviceAccount:*"
   ```

4. **Configure Docker authentication** (first time only)
   ```powershell
   gcloud auth configure-docker us-central1-docker.pkg.dev
   ```

### Verify Installation

```powershell
# Run validation
cd z:\obroh.com\scripts\deploy
.\deploy.ps1 -Service backend -Validate

# Should output:
# ✓ Environment validation passed
# ✓ backend service validated
```

---

## 📖 Usage Guide

### Command: `deploy.ps1`

**Syntax:**
```powershell
.\deploy.ps1 -Service <service> [-Validate] [-Force]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-Service` | String | Yes | Service to deploy: `backend`, `admin`, `website`, or `all` |
| `-Validate` | Switch | No | Perform validation only (dry-run), don't deploy |
| `-Force` | Switch | No | Skip confirmation prompts (for automation/CI) |

**Exit Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Failure (validation, build, deploy, or verification failed) |

### Examples

#### 1. Deploy Backend Service (with confirmation)
```powershell
cd z:\obroh.com\scripts\deploy
.\deploy.ps1 -Service backend

# Output:
# ℹ️  Obroh Deployment System Started
# ... validation checks ...
# ⚠️  This will deploy the following service(s) to PRODUCTION:
#    - backend
# Continue with deployment? (yes/no): yes
# ... building, pushing, deploying ...
# ✅ Deployment completed successfully
```

#### 2. Validate All Services Without Deploying
```powershell
.\deploy.ps1 -Service all -Validate

# Output:
# ✓ Environment validation passed
# ✓ backend service validated
# ✓ admin service validated
# ✓ website service validated
# ✅ All validation checks passed - ready for deployment
```

#### 3. Deploy Admin in Automation (No Prompts)
```powershell
.\deploy.ps1 -Service admin -Force

# Outputs:
# ... performs deployment without asking for confirmation ...
```

#### 4. Deploy All Services
```powershell
.\deploy.ps1 -Service all

# Deploys backend, then admin, then website sequentially
# Each service gets full validation and deployment cycle
```

---

## 🔧 Services & Configuration

### Backend Service (obroh-backend)

**Purpose:** Node.js Express REST API for Obroh family management  
**Location:** `z:\obroh.com\backend`  
**Technology:** Node.js 22 + Express + TypeScript  
**Cloud Run Settings:**
- CPU: 1 vCPU
- Memory: 512 MB
- Timeout: 300 seconds
- Max Instances: 100
- Requires Authentication: Yes

**Deploy:**
```powershell
.\deploy.ps1 -Service backend
```

**Verify:**
```powershell
# Check service status
gcloud run services describe obroh-backend --region us-central1

# Test health endpoint
Invoke-WebRequest -Uri "https://obroh-backend-zoeqld5lsa-uc.a.run.app/api/health"
```

---

### Admin Service (obroh-admin)

**Purpose:** Next.js administrative dashboard  
**Location:** `z:\obroh.com\admin`  
**Technology:** Next.js 16 + Tailwind CSS + TypeScript  
**Cloud Run Settings:**
- CPU: 1 vCPU
- Memory: 1 GB
- Timeout: 300 seconds
- Max Instances: 50
- Requires Authentication: No (public)

**Features Deployed:**
- `/family-tree` - Family tree visualization
- `/members` - Member management
- `/notifications` - Notification center
- `/pending` - Pending approvals
- `/roles` - Role management
- `/settings` - Admin settings
- `/analytics` - Analytics dashboard
- `/content` - Content management
- `/knowledge-base` - Knowledge base
- `/legacy` - Legacy data management
- `/login` - Authentication

**Deploy:**
```powershell
.\deploy.ps1 -Service admin
```

**Verify:**
```powershell
# Check service status
gcloud run services describe obroh-admin --region us-central1

# Test homepage
Invoke-WebRequest -Uri "https://obroh-admin-zoeqld5lsa-uc.a.run.app" | Select-Object StatusCode
```

---

### Website Service (obroh-website)

**Purpose:** Public-facing Next.js website  
**Location:** `z:\obroh.com\website`  
**Technology:** Next.js 16 + Tailwind CSS + TypeScript  
**Cloud Run Settings:**
- CPU: 1 vCPU
- Memory: 512 MB
- Timeout: 300 seconds
- Max Instances: 50
- Requires Authentication: No (public)

**Deploy:**
```powershell
.\deploy.ps1 -Service website
```

**Verify:**
```powershell
# Check service status
gcloud run services describe obroh-website --region us-central1
```

---

## 🔒 Safety Features

### 1. **Multi-Stage Validation**
- Environment checks (gcloud, Docker, GCP project)
- Service readiness checks (source files, configuration)
- Pre-deployment verification

### 2. **Confirmation Gate**
- Displays services about to deploy
- Requires explicit user confirmation
- Can be bypassed with `-Force` flag for automation

### 3. **Atomic Deployments**
- Each service deploys independently
- Failed service doesn't affect others
- Revision tracking for rollback capability

### 4. **Health Verification**
- Post-deployment health checks
- Confirms services responding correctly
- Alerts on health issues

### 5. **Comprehensive Logging**
- All operations logged to file
- Log file location: `$env:TEMP\obroh-deployments\deploy_YYYYMMDD_HHmmss.log`
- Timestamps and severity levels

### 6. **Resource Limits**
- CPU and memory limits per service
- Timeout specifications
- Instance scaling limits

---

## 🚨 Troubleshooting

### Error: "gcloud CLI not found"

**Solution:**
```powershell
# Install Google Cloud CLI
# https://cloud.google.com/sdk/docs/install

# Verify installation
gcloud --version

# Ensure it's in PATH
$env:PATH -split ';' | Where-Object { $_ -match 'google' }
```

### Error: "Docker not running"

**Solution:**
```powershell
# Start Docker Desktop or Docker daemon
# Windows: Start Docker Desktop app
# Linux: sudo systemctl start docker

# Verify
docker ps
```

### Error: "gcloud not authenticated"

**Solution:**
```powershell
# Login to Google Cloud
gcloud auth login

# Set project
gcloud config set project raven-ai-6ff76

# Verify authentication
gcloud auth list
```

### Error: "Docker build failed"

**Solution:**
```powershell
# Check service directory
cd z:\obroh.com\<service-name>

# Verify Dockerfile exists
ls Dockerfile

# Try building manually
docker build -t test . --progress=plain

# Check for syntax errors in Dockerfile
```

### Error: "Cloud Run deployment failed"

**Solution:**
```powershell
# Check service quotas
gcloud run services list --region us-central1

# Check service exists
gcloud run services describe obroh-<service> --region us-central1

# View recent deployments
gcloud run revisions list --service obroh-<service> --region us-central1
```

### Check Deployment Logs

```powershell
# View log file from last deployment
$logDir = "$env:TEMP\obroh-deployments"
Get-ChildItem $logDir | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1

# View Cloud Run logs
gcloud run services logs read obroh-<service> --region us-central1 --limit 50
```

---

## 🤖 For Agents & Automation

This deployment system is designed to be called programmatically by agents, CI/CD pipelines, and automation systems.

### Agent Integration

**From Another Agent:**
```powershell
# Deploy backend service
& "z:\obroh.com\scripts\deploy\deploy.ps1" -Service backend -Force

# Store result
$result = & "z:\obroh.com\scripts\deploy\deploy.ps1" -Service admin -Validate -Force
if ($result.Success) {
    Write-Host "Admin service ready for deployment"
}
```

### CI/CD Integration

**GitHub Actions:**
```yaml
- name: Deploy Backend
  run: |
    cd z:\obroh.com\scripts\deploy
    .\deploy.ps1 -Service backend -Force
```

**GitLab CI:**
```yaml
deploy_backend:
  script:
    - cd z:\obroh.com\scripts\deploy
    - .\deploy.ps1 -Service backend -Force
```

### Return Values

Each service deployment script returns a hashtable:

```powershell
@{
    Success   = $true or $false
    Service   = 'backend' | 'admin' | 'website'
    Revision  = 'obroh-backend-00006-cxw'
    Url       = 'https://obroh-backend-zoeqld5lsa-uc.a.run.app'
}
```

### Automation Best Practices

1. **Always use `-Force` flag**
   ```powershell
   .\deploy.ps1 -Service backend -Force
   ```

2. **Capture output**
   ```powershell
   $deploymentResult = & ".\deploy.ps1" -Service backend -Force
   ```

3. **Check success before proceeding**
   ```powershell
   if ($deploymentResult.Success) {
       # Continue with post-deployment steps
   } else {
       # Handle failure
   }
   ```

4. **Parse logs for monitoring**
   ```powershell
   $latestLog = Get-ChildItem "$env:TEMP\obroh-deployments" | 
       Sort-Object -Property LastWriteTime -Descending | 
       Select-Object -First 1 -ExpandProperty FullName
   
   Get-Content $latestLog | Select-String "ERROR|FAILURE"
   ```

### Service-Specific Scripts

Individual service scripts can be called directly:

```powershell
# Call backend deployment directly
& "z:\obroh.com\scripts\deploy\services\backend.ps1" -Force

# Call admin deployment directly
& "z:\obroh.com\scripts\deploy\services\admin.ps1" -Force

# Call website deployment directly
& "z:\obroh.com\scripts\deploy\services\website.ps1" -Force
```

---

## 📞 Support & Documentation

**Location:** `z:\obroh.com\scripts\deploy`

**Key Files:**
- **Main Script:** `deploy.ps1`
- **Backend Deployment:** `services/backend.ps1`
- **Admin Deployment:** `services/admin.ps1`
- **Website Deployment:** `services/website.ps1`
- **Utilities:** `utils/logging.ps1`, `utils/validation.ps1`, `utils/config.ps1`

**Help:**
```powershell
Get-Help .\deploy.ps1 -Full
Get-Help .\services\backend.ps1 -Full
```

---

## 🔄 Common Workflows

### Workflow 1: Deploy Single Service
```powershell
.\deploy.ps1 -Service backend
# Follow prompts
```

### Workflow 2: Deploy All Services at Once
```powershell
.\deploy.ps1 -Service all
# Follow prompts for confirmation
```

### Workflow 3: Validate Before Deploying
```powershell
# First validate
.\deploy.ps1 -Service backend -Validate

# If validation passes, deploy
.\deploy.ps1 -Service backend
```

### Workflow 4: Automated CI/CD Deployment
```powershell
# In CI/CD pipeline
.\deploy.ps1 -Service backend -Force
.\deploy.ps1 -Service admin -Force
.\deploy.ps1 -Service website -Force
```

### Workflow 5: Rollback to Previous Revision
```powershell
# List revisions
gcloud run revisions list --service obroh-backend --region us-central1

# Route traffic to previous revision
gcloud run services update-traffic obroh-backend --to-revisions=<PREVIOUS-REVISION>=100 --region us-central1
```

---

## 📊 Deployment Status Dashboard

Check all services:
```powershell
# Get all service status
gcloud run services list --region us-central1 --format=table(NAME,STATUS,LAST_MODIFIED_BY,LAST_MODIFIED_AT)

# Get detailed service info
gcloud run services describe obroh-backend --region us-central1
gcloud run services describe obroh-admin --region us-central1
gcloud run services describe obroh-website --region us-central1
```

---

**Last Updated:** May 13, 2026  
**Maintained By:** Obroh Development Team  
**Version:** 1.0 (Production Ready)
