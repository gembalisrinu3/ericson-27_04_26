# =============================================================================
# EduRamp Advanced GitOps - Complete Setup & Validate (Windows v2)
# =============================================================================
# This script does EVERYTHING needed to be ready for the training:
#   1. Installs all CLI tools (kind, kubectl, helm, flux, gh, sops, age, jq, git)
#   2. UPGRADES tools that are present but old (kind v0.30+, flux v2.8+ required)
#   3. Installs Docker Desktop + WSL 2 if missing
#   4. Waits for Docker daemon to actually be reachable (with 90s timeout)
#   5. Authenticates GitHub CLI
#   6. Creates a real kind cluster on K8s v1.32 and validates with flux check
#   7. Cleans up the test cluster
#
# Idempotent - re-run anytime. Skips already-correct items.
#
# USAGE (as Administrator):
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#   Unblock-File .\EduRamp_Setup_All_Windows.ps1
#   .\EduRamp_Setup_All_Windows.ps1
# =============================================================================

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "EduRamp Setup & Validate"

# ---------- helpers ----------
function Write-Section($t) {
    Write-Host ""
    Write-Host ("=" * 72) -ForegroundColor DarkCyan
    Write-Host "  $t" -ForegroundColor Cyan
    Write-Host ("=" * 72) -ForegroundColor DarkCyan
}
function Write-OK($t)    { Write-Host "  [OK]    $t" -ForegroundColor Green }
function Write-Warn($t)  { Write-Host "  [WARN]  $t" -ForegroundColor Yellow }
function Write-Fail($t)  { Write-Host "  [FAIL]  $t" -ForegroundColor Red }
function Write-Info($t)  { Write-Host "  [INFO]  $t" -ForegroundColor White }
function Write-Step($t)  { Write-Host "  >>>     $t" -ForegroundColor Magenta }
function Has-Cmd($c)     { return $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path", "User")
}

# Required minimum versions (parsed loosely - just for messaging)
$REQUIRED_KIND_MIN = "0.30"
$REQUIRED_FLUX_MIN = "2.8"
$REQUIRED_K8S_VER  = "v1.32.0"
$KIND_NODE_IMAGE   = "kindest/node:v1.32.0"
$REQUIRED_DOCKER_GB = 6

# ---------- BANNER ----------
Clear-Host
Write-Host ""
Write-Host "  EduRamp Advanced GitOps - Complete Setup & Validate" -ForegroundColor Cyan
Write-Host "  Installs everything, upgrades stale tools, runs end-to-end smoke test" -ForegroundColor DarkCyan
Write-Host "  Run as ADMINISTRATOR. Allow 10-20 minutes if Docker Desktop needs install." -ForegroundColor Gray
Write-Host ""

# ---------- prerequisite: admin ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Fail "This script requires Administrator privileges."
    Write-Info "Right-click PowerShell -> 'Run as Administrator', then re-run."
    exit 1
}
Write-OK "Running as Administrator"

# ---------- prerequisite: winget ----------
Write-Section "Step 0: Verify winget (Windows package manager)"
if (-not (Has-Cmd "winget")) {
    Write-Fail "winget not found."
    Write-Info "Install 'App Installer' from the Microsoft Store, then re-run this script."
    Write-Info "Direct link: https://apps.microsoft.com/detail/9NBLGGH4NNS1"
    exit 1
}
$wingetVer = (winget --version).Trim()
Write-OK "winget $wingetVer present"

# Choco detection (some installs may have used choco previously)
$hasChoco = Has-Cmd "choco"
if ($hasChoco) {
    Write-Info "Chocolatey also detected - some tools may be choco-managed (we handle that below)"
}

# =============================================================================
# STEP 1: WSL 2  (Docker Desktop requires this)
# =============================================================================
Write-Section "Step 1: WSL 2 (required by Docker Desktop)"

$wslOk = $false
try {
    $wslStatus = wsl --status 2>&1 | Out-String
    if ($wslStatus -match "Default Version:\s*2") {
        Write-OK "WSL 2 is enabled"
        $wslOk = $true
    } elseif ($wslStatus -match "Default Version:\s*1") {
        Write-Warn "WSL 1 detected - upgrading default to WSL 2"
        wsl --set-default-version 2
        $wslOk = $true
    }
} catch {}

if (-not $wslOk) {
    Write-Warn "WSL 2 not installed. Installing now..."
    wsl --install --no-distribution
    Write-Warn "REBOOT REQUIRED. After reboot, re-run this script to continue."
    Write-Info "Run: Restart-Computer"
    Write-Info "Or restart manually from Start Menu."
    Read-Host "Press Enter to acknowledge (do NOT reboot until you've read this)"
    exit 0
}

# =============================================================================
# STEP 2: Docker Desktop
# =============================================================================
Write-Section "Step 2: Docker Desktop (install if missing)"
if (Has-Cmd "docker") {
    $dv = (docker --version) 2>$null
    Write-OK "Docker CLI present: $dv"
} else {
    Write-Warn "Docker Desktop not installed. Installing via winget (~500 MB download)..."
    winget install -e --id Docker.DockerDesktop --silent --accept-source-agreements --accept-package-agreements
    Refresh-Path
    if (Has-Cmd "docker") {
        Write-OK "Docker Desktop installed"
    } else {
        Write-Fail "Docker Desktop install failed. Manual download:"
        Write-Info "  https://www.docker.com/products/docker-desktop/"
        exit 1
    }
}

# =============================================================================
# STEP 3: Start Docker Desktop and WAIT for engine to be reachable
# =============================================================================
Write-Section "Step 3: Start Docker Desktop and wait for engine"

# Check if Docker Desktop process is running
$dockerProc = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
if (-not $dockerProc) {
    Write-Info "Docker Desktop process not running. Starting it..."
    $dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerExe) {
        Start-Process $dockerExe
        Write-Info "Launched Docker Desktop. Waiting for engine to come online..."
    } else {
        Write-Fail "Cannot find Docker Desktop.exe at expected path"
        Write-Info "Open Docker Desktop manually from Start Menu, then re-run this script"
        exit 1
    }
} else {
    Write-OK "Docker Desktop process is already running"
}

# Wait loop for Docker daemon to respond (up to 120 seconds)
Write-Step "Waiting up to 120s for Docker engine to respond..."
$dockerReady = $false
for ($i = 1; $i -le 60; $i++) {
    docker info 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) {
        $dockerReady = $true
        Write-OK "Docker engine is reachable (after ${i}x 2s = $($i*2)s)"
        break
    }
    Start-Sleep -Seconds 2
    if ($i % 5 -eq 0) {
        Write-Host "          still waiting... ($($i*2)s elapsed)" -ForegroundColor DarkGray
    }
}

if (-not $dockerReady) {
    Write-Fail "Docker engine did NOT come online within 120 seconds."
    Write-Info "Manual checks:"
    Write-Info "  1. Look for the whale icon in your system tray (bottom-right)"
    Write-Info "  2. Right-click whale -> if you see 'Switch to Linux containers...' click it"
    Write-Info "  3. If whale icon shows error, right-click -> Troubleshoot -> Reset to factory defaults"
    Write-Info "  4. After Docker is reachable, re-run this script"
    exit 1
}

# Verify Linux container mode (kind requires this)
$dockerOS = (docker info --format "{{.OSType}}") 2>$null
if ($dockerOS -ne "linux") {
    Write-Fail "Docker is in '$dockerOS' container mode. Need 'linux' for kind."
    Write-Info "Right-click whale icon -> 'Switch to Linux containers...'"
    exit 1
}
Write-OK "Docker is in Linux container mode"

# Check resources
$mem = (docker info --format "{{.MemTotal}}") 2>$null
$cpus = (docker info --format "{{.NCPU}}") 2>$null
if ($mem -and $mem -gt 0) {
    $memGB = [math]::Round($mem / 1GB, 1)
    if ($memGB -lt $REQUIRED_DOCKER_GB) {
        Write-Warn "Docker has only ${memGB} GB allocated. Bump to ${REQUIRED_DOCKER_GB}+ GB:"
        Write-Info "  Docker Desktop -> Settings -> Resources -> Memory -> drag to ${REQUIRED_DOCKER_GB}+ GB -> Apply & restart"
    } else {
        Write-OK "Docker memory: ${memGB} GB"
    }
}
if ($cpus -and $cpus -gt 0) {
    Write-OK "Docker CPUs: $cpus"
}

# =============================================================================
# STEP 4: Install / upgrade CLI tools
# =============================================================================
Write-Section "Step 4: Install / upgrade CLI tools"

# Each tool: name, winget id, command-to-get-version, optional GitHub fallback URL+expected-asset-pattern
$tools = @(
    @{ name = "git";     wingetId = "Git.Git";              versionCmd = "git --version" }
    @{ name = "kubectl"; wingetId = "Kubernetes.kubectl";   versionCmd = "kubectl version --client --output=yaml" }
    @{ name = "kind";    wingetId = "Kubernetes.kind";      versionCmd = "kind version" }
    @{ name = "helm";    wingetId = "Helm.Helm";            versionCmd = "helm version --short" }
    @{ name = "flux";    wingetId = "FluxCD.Flux";          versionCmd = "flux --version" }
    @{ name = "gh";      wingetId = "GitHub.cli";           versionCmd = "gh --version" }
    @{ name = "jq";      wingetId = "jqlang.jq";            versionCmd = "jq --version" }
    @{ name = "sops";    wingetId = "Mozilla.SOPS";         versionCmd = "sops --version" }
    @{ name = "age";     wingetId = "FiloSottile.age";      versionCmd = "age --version" }
)

foreach ($t in $tools) {
    $name = $t.name
    if (Has-Cmd $name) {
        $ver = (Invoke-Expression $t.versionCmd 2>&1 | Select-Object -First 1)
        Write-OK "$name : $ver"
        # Try to upgrade via the package manager that owns it
        Write-Step "  checking $name for upgrades..."
        $cmdSource = (Get-Command $name).Source
        if ($cmdSource -like "*chocolatey*") {
            if ($hasChoco) {
                choco upgrade $name -y --no-progress 2>&1 | Select-String "is the latest version|upgraded|installed" | Select-Object -First 1 | ForEach-Object { Write-Host "          $_" -ForegroundColor DarkGray }
            }
        } else {
            winget upgrade -e --id $t.wingetId --silent --accept-source-agreements --accept-package-agreements 2>&1 | Select-String "No applicable upgrade|Successfully installed" | Select-Object -First 1 | ForEach-Object { Write-Host "          $_" -ForegroundColor DarkGray }
        }
    } else {
        Write-Warn "$name not installed - installing via winget ($($t.wingetId))..."
        winget install -e --id $t.wingetId --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        Refresh-Path
        if (Has-Cmd $name) {
            Write-OK "$name installed"
        } else {
            Write-Fail "winget install failed for $name. Manual download URL:"
            switch ($name) {
                "flux"    { Write-Info "  https://github.com/fluxcd/flux2/releases/latest" }
                "sops"    { Write-Info "  https://github.com/getsops/sops/releases/latest" }
                "age"     { Write-Info "  https://github.com/FiloSottile/age/releases/latest" }
                "kind"    { Write-Info "  https://kind.sigs.k8s.io/dl/latest/kind-windows-amd64" }
                "helm"    { Write-Info "  https://helm.sh/docs/intro/install/" }
                "kubectl" { Write-Info "  https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/" }
                default   { Write-Info "  https://winstall.app/apps/$($t.wingetId)" }
            }
        }
    }
}
Refresh-Path

# =============================================================================
# STEP 5: Hard version checks for kind and flux (the gotcha tools)
# =============================================================================
Write-Section "Step 5: Verify kind v0.30+ and flux v2.8+ (Flux requires K8s v1.32+)"

# kind version check
$kindVerStr = (kind version 2>$null) -replace 'kind v?', ''
$kindVerNum = $kindVerStr -split ' ' | Select-Object -First 1
$kindParts = $kindVerNum -split '\.'
if ([int]$kindParts[0] -gt 0 -or [int]$kindParts[1] -ge 30) {
    Write-OK "kind v$kindVerNum (sufficient for K8s v1.32 node images)"
} else {
    Write-Warn "kind v$kindVerNum is too old (need v$REQUIRED_KIND_MIN+). Force-upgrading via direct download..."
    $ToolsDir = "C:\Tools"
    New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
    try {
        Invoke-WebRequest -Uri "https://kind.sigs.k8s.io/dl/v0.30.0/kind-windows-amd64" -OutFile "$ToolsDir\kind.exe" -UseBasicParsing
        $oldKindPath = (Get-Command kind).Source
        Copy-Item "$ToolsDir\kind.exe" -Destination $oldKindPath -Force
        Write-OK "kind upgraded at $oldKindPath"
    } catch {
        Write-Fail "Direct kind download failed: $_"
    }
}

# flux version check
$fluxVerStr = (flux --version 2>$null) -replace 'flux version ', ''
$fluxParts = $fluxVerStr -split '\.'
if ([int]$fluxParts[0] -gt 2 -or ([int]$fluxParts[0] -eq 2 -and [int]$fluxParts[1] -ge 8)) {
    Write-OK "flux v$fluxVerStr (sufficient for K8s v1.32+ pre-check)"
} else {
    Write-Warn "flux v$fluxVerStr is too old (need v$REQUIRED_FLUX_MIN+). Force-upgrading via direct download..."
    $ToolsDir = "C:\Tools"
    New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
    try {
        $fluxZip = "$ToolsDir\flux_download.zip"
        Invoke-WebRequest -Uri "https://github.com/fluxcd/flux2/releases/download/v2.8.6/flux_2.8.6_windows_amd64.zip" -OutFile $fluxZip -UseBasicParsing
        $extractDir = "$ToolsDir\flux_extract"
        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
        Expand-Archive -Path $fluxZip -DestinationPath $extractDir -Force
        $oldFluxPath = (Get-Command flux).Source
        Copy-Item "$extractDir\flux.exe" -Destination $oldFluxPath -Force
        Remove-Item $fluxZip -Force
        Remove-Item $extractDir -Recurse -Force
        Write-OK "flux upgraded at $oldFluxPath"
    } catch {
        Write-Fail "Direct flux download failed: $_"
    }
}

# =============================================================================
# STEP 6: GitHub CLI auth
# =============================================================================
Write-Section "Step 6: GitHub CLI authentication"
if (Has-Cmd "gh") {
    gh auth status 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "GitHub CLI is authenticated"
        gh auth status 2>&1 | Select-Object -First 5 | ForEach-Object {
            $line = $_.ToString().Trim()
            if ($line) { Write-Host "          $line" -ForegroundColor DarkGray }
        }
    } else {
        Write-Warn "GitHub CLI not authenticated yet."
        $doAuth = Read-Host "Run 'gh auth login' now? Browser will open. [Y/n]"
        if ($doAuth -ne "n" -and $doAuth -ne "N") {
            gh auth login --web --scopes "repo,admin:public_key,workflow"
        } else {
            Write-Info "You can authenticate later with:"
            Write-Info "  gh auth login --web --scopes repo,admin:public_key,workflow"
        }
    }
}

# =============================================================================
# STEP 7: End-to-end smoke test (the real validation)
# =============================================================================
Write-Section "Step 7: End-to-end smoke test (creates and validates a real kind cluster)"
Write-Info "This is the critical test. ~2 minutes. Cleans up after itself."

$clusterName = "eduramp-smoketest"

# Clean any leftover from previous runs
Write-Step "Cleaning any previous smoke-test cluster..."
kind delete cluster --name $clusterName 2>$null | Out-Null

Write-Step "Creating kind cluster '$clusterName' on K8s $REQUIRED_K8S_VER..."
Write-Info "  (image: $KIND_NODE_IMAGE - first run downloads ~300 MB)"
kind create cluster --name $clusterName --image $KIND_NODE_IMAGE 2>&1 | ForEach-Object {
    Write-Host "          $_" -ForegroundColor DarkGray
}

if ($LASTEXITCODE -ne 0) {
    Write-Fail "kind cluster creation failed"
    Write-Info "Most likely cause: Docker Desktop ran out of memory."
    Write-Info "  Fix: Docker Desktop -> Settings -> Resources -> Memory -> 8 GB -> Apply & restart"
    exit 1
}
Write-OK "kind cluster created"

Write-Step "Waiting for cluster nodes to be Ready..."
$nodesReady = $false
for ($i = 1; $i -le 30; $i++) {
    $nodesOutput = kubectl get nodes --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $nodesOutput -match "Ready") {
        $nodesReady = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $nodesReady) {
    Write-Warn "Nodes did not reach Ready in 60s - continuing anyway"
} else {
    $nodeCount = ($nodesOutput | Measure-Object -Line).Lines
    Write-OK "Cluster has $nodeCount node(s) Ready"
}

Write-Step "Verifying K8s API version..."
$k8sVer = (kubectl version --output=json 2>$null | ConvertFrom-Json).serverVersion.gitVersion
Write-OK "Kubernetes server version: $k8sVer"

Write-Step "Running 'flux check --pre' against the cluster..."
$fluxOutput = flux check --pre 2>&1 | Out-String
Write-Host $fluxOutput -ForegroundColor DarkGray
if ($fluxOutput -match "prerequisites checks passed") {
    Write-OK "flux check --pre PASSED"
} elseif ($fluxOutput -match ([char]0x2717) -or $fluxOutput -match "x ") {
    Write-Fail "flux check --pre failed - see output above"
}

Write-Step "Cleaning up smoke-test cluster..."
kind delete cluster --name $clusterName 2>&1 | Out-Null
Write-OK "Smoke-test cluster deleted"

# =============================================================================
# STEP 8: Final summary
# =============================================================================
Write-Section "FINAL SUMMARY"

# Re-collect versions for the summary
Refresh-Path
$summary = @()
foreach ($n in @("docker", "kind", "kubectl", "helm", "flux", "gh", "git", "jq", "sops", "age")) {
    if (Has-Cmd $n) {
        $v = switch ($n) {
            "docker"  { (docker --version) 2>$null }
            "kind"    { (kind version) 2>$null }
            "kubectl" { (kubectl version --client 2>$null | Select-String "Client Version" | Select-Object -First 1).ToString().Trim() }
            "helm"    { (helm version --short) 2>$null }
            "flux"    { (flux --version) 2>$null }
            "gh"      { (gh --version 2>$null | Select-Object -First 1) }
            "git"     { (git --version) 2>$null }
            "jq"      { (jq --version) 2>$null }
            "sops"    { (sops --version 2>$null | Select-Object -First 1) }
            "age"     { (age --version) 2>$null }
        }
        Write-OK "$n : $v"
    } else {
        Write-Fail "$n : MISSING"
    }
}

Write-Host ""
Write-Host ("=" * 72) -ForegroundColor Green
Write-Host "  YOU ARE READY FOR DAY 1 OF THE TRAINING" -ForegroundColor Green
Write-Host ("=" * 72) -ForegroundColor Green
Write-Host ""
Write-Host "  REMEMBER for the labs:" -ForegroundColor Yellow
Write-Host "    Always create lab clusters with EXPLICIT K8s version:" -ForegroundColor Yellow
Write-Host "      kind create cluster --name flux-lab --image $KIND_NODE_IMAGE" -ForegroundColor White
Write-Host ""
Write-Host "    If 'flux bootstrap' fails with 'context deadline exceeded'," -ForegroundColor Yellow
Write-Host "    the most common cause is Docker memory < 6 GB. Bump it." -ForegroundColor Yellow
Write-Host ""
