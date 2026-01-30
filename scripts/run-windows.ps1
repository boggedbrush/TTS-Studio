# Qwen3-TTS Native Run Script for Windows (PowerShell)
# Supports: CUDA (NVIDIA), DirectML (AMD/Intel), and CPU

param(
    [switch]$Verbose,
    [Alias("v")]
    [switch]$VerboseShort
)

$ErrorActionPreference = "Stop"
$IsVerbose = $Verbose -or $VerboseShort

# Helper functions
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    if ($IsVerbose) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Write-Error-Always {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Invoke-Quiet {
    param([scriptblock]$Command)
    if ($IsVerbose) {
        & $Command
    } else {
        & $Command *> $null
    }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

if ($IsVerbose) {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  Qwen3-TTS Studio - Windows Native Setup" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Check Python
try {
    $pythonVersion = python --version 2>&1
    Write-Log "[OK] $pythonVersion found" -Color Green
} catch {
    Write-Error-Always "[ERROR] Python 3 is required but not installed."
    Write-Host "Download from: https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "Make sure to check 'Add Python to PATH' during installation." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check Node.js
try {
    $nodeVersion = node --version 2>&1
    Write-Log "[OK] Node.js $nodeVersion found" -Color Green
} catch {
    Write-Error-Always "[ERROR] Node.js is required but not installed."
    Write-Host "Download from: https://nodejs.org/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Detect GPU
$gpuType = "cpu"

# Check for NVIDIA GPU first
try {
    nvidia-smi 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $gpuType = "cuda"
        Write-Log "[OK] NVIDIA GPU detected - CUDA acceleration available" -Color Green
    }
} catch {
    # NVIDIA not found, continue checking
}

# If no NVIDIA, check for AMD or Intel GPU (use DirectML)
if ($gpuType -eq "cpu") {
    $gpus = Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name
    foreach ($gpu in $gpus) {
        if ($gpu -match "AMD|Radeon") {
            $gpuType = "directml"
            Write-Log "[OK] AMD GPU detected: $gpu - DirectML acceleration available" -Color Green
            break
        }
        if ($gpu -match "Intel") {
            $gpuType = "directml"
            Write-Log "[OK] Intel GPU detected: $gpu - DirectML acceleration available" -Color Green
            break
        }
    }
}

if ($gpuType -eq "cpu") {
    Write-Log "[WARN] No supported GPU detected, using CPU (will be slower)" -Color Yellow
}

# Setup backend virtual environment
Write-Log "" 
Write-Log "Setting up Python backend..." -Color Cyan
Set-Location "$ProjectDir\backend"

if (-not (Test-Path "venv")) {
    Write-Log "Creating virtual environment..."
    Invoke-Quiet { python -m venv venv }
}

& ".\venv\Scripts\Activate.ps1"

# Install PyTorch with appropriate backend
Write-Log "Installing dependencies..."
Invoke-Quiet { python -m pip install --upgrade pip }

if ($gpuType -eq "cuda") {
    Write-Log "Installing PyTorch with CUDA support..." -Color Cyan
    Invoke-Quiet { pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 }
} elseif ($gpuType -eq "directml") {
    Write-Log "Installing PyTorch with DirectML support..." -Color Cyan
    Invoke-Quiet { pip install torch torchvision torchaudio }
    Invoke-Quiet { pip install torch-directml }
} else {
    Write-Log "Installing PyTorch CPU version..." -Color Cyan
    Invoke-Quiet { pip install torch torchvision torchaudio }
}

Invoke-Quiet { pip install -r requirements.txt }

# Setup frontend
Write-Log ""
Write-Log "Setting up Node.js frontend..." -Color Cyan
Set-Location "$ProjectDir\frontend"

if (-not (Test-Path "node_modules")) {
    Invoke-Quiet { npm install }
}

# Start services - status bar always shown
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Qwen3-TTS Studio is running!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Frontend: http://localhost:3000" -ForegroundColor White
Write-Host "  Backend:  http://localhost:8000" -ForegroundColor White
Write-Host ""
if ($gpuType -eq "cuda") {
    Write-Host "  NVIDIA GPU acceleration enabled" -ForegroundColor Green
} elseif ($gpuType -eq "directml") {
    Write-Host "  DirectML acceleration enabled (AMD/Intel)" -ForegroundColor Magenta
} else {
    Write-Host "  CPU mode (no GPU acceleration)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Press Ctrl+C to stop both services" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Start backend in a new PowerShell window (quiet mode)
Set-Location "$ProjectDir\backend"
if ($IsVerbose) {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "& { Set-Location '$ProjectDir\backend'; & '.\venv\Scripts\Activate.ps1'; python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 }"
} else {
    Start-Process powershell -ArgumentList "-WindowStyle", "Hidden", "-Command", "& { Set-Location '$ProjectDir\backend'; & '.\venv\Scripts\Activate.ps1'; python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 }" -WindowStyle Hidden
}

# Start frontend in current window
Set-Location "$ProjectDir\frontend"
if ($IsVerbose) {
    npm run dev
} else {
    npm run dev *> $null
}
