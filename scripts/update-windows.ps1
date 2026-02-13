# Qwen3-TTS Update Script for Windows (PowerShell)
# Updates git checkout (if clean), backend dependencies, and frontend dependencies.
# Usage: .\scripts\update-windows.ps1 [-Verbose|-v] [-Dev|-d] [-SkipGit]

param(
    [switch]$Verbose,
    [Alias("v")]
    [switch]$VerboseShort,
    [switch]$Dev,
    [Alias("d")]
    [switch]$DevShort,
    [switch]$SkipGit
)

$ErrorActionPreference = "Stop"
$IsVerbose = $Verbose -or $VerboseShort
$IsDev = $Dev -or $DevShort

function Write-Log {
    param([string]$Message)
    if ($IsVerbose) {
        Write-Host $Message
    }
}

function Write-Warn-Always {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Invoke-Quiet {
    param([scriptblock]$Command)
    if ($IsVerbose) {
        & $Command
    } else {
        & $Command *> $null
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed."
    }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

try {
    python --version | Out-Null
    node --version | Out-Null
} catch {
    Write-Host "Python and Node.js are required." -ForegroundColor Red
    exit 1
}

Write-Host "Updating Qwen3-TTS..."
Write-Host "Project: $ProjectDir"
if ($IsDev) {
    Write-Host "Mode: development (skip frontend build)"
} else {
    Write-Host "Mode: production (includes frontend build)"
}

if (-not $SkipGit -and (Test-Path "$ProjectDir\.git")) {
    try {
        $gitStatus = git -C "$ProjectDir" status --porcelain 2>$null
        if (-not [string]::IsNullOrWhiteSpace($gitStatus)) {
            Write-Warn-Always "Local changes detected; skipping git pull."
        } else {
            Write-Host "Pulling latest changes..."
            Invoke-Quiet { git -C "$ProjectDir" pull --ff-only }
        }
    } catch {
        Write-Warn-Always "Git update skipped."
    }
}

Write-Host "Updating backend dependencies..."
Set-Location "$ProjectDir\backend"

if (-not (Test-Path "venv")) {
    Write-Log "Creating Python virtual environment..."
    Invoke-Quiet { python -m venv venv }
}

. ".\venv\Scripts\Activate.ps1"
Invoke-Quiet { python -m pip install --upgrade pip }
Invoke-Quiet { pip install -r requirements.txt }

Write-Host "Updating frontend dependencies..."
Set-Location "$ProjectDir\frontend"
Invoke-Quiet { npm install }

if (-not $IsDev) {
    Write-Host "Building frontend..."
    Invoke-Quiet { npm run build }
}

Write-Host "Update complete." -ForegroundColor Green
