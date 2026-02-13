# Qwen3-TTS Native Run Script for Windows (PowerShell)
# Supports: CUDA (NVIDIA), DirectML (AMD/Intel), and CPU
# Usage: ./run-windows.ps1 [-Verbose|-v] [-Dev|-d]

param(
    [switch]$Verbose,
    [Alias("v")]
    [switch]$VerboseShort,
    [switch]$Dev,
    [Alias("d")]
    [switch]$DevShort
)

$ErrorActionPreference = "Stop"
$IsVerbose = $Verbose -or $VerboseShort
$IsDev = $Dev -or $DevShort

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

    # Check for Python 3.13+ or 32-bit (common issues with PyTorch)
    $pyInfo = python -c "import sys, struct; print(sys.version_info.major, sys.version_info.minor, struct.calcsize('P') * 8)" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $major, $minor, $bits = $pyInfo -split " "
        if ([int]$major -eq 3 -and [int]$minor -ge 13) {
            Write-Log "[WARN] You are using Python $major.$minor. PyTorch may not support this version yet." -Color Yellow
            Write-Log "       If installation fails, try installing Python 3.10, 3.11 or 3.12." -Color Yellow
        }
        if ([int]$bits -eq 32) {
            Write-Log "[WARN] You are using 32-bit Python. PyTorch requires 64-bit Python." -Color Yellow
            Write-Log "       Please install 64-bit Python." -Color Yellow
        }
    }
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

. ".\venv\Scripts\Activate.ps1"

# Install PyTorch with appropriate backend
Write-Log "Installing dependencies..."
Invoke-Quiet { python -m pip install --upgrade pip }

if ($gpuType -eq "cuda") {
    Write-Log "Installing PyTorch with CUDA support..." -Color Cyan
    Invoke-Quiet { pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 }
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Always "[ERROR] Failed to install PyTorch."
        Write-Host "Possible causes:" -ForegroundColor Yellow
        Write-Host "1. Python version too new (use 3.10-3.12)" -ForegroundColor Yellow
        Write-Host "2. 32-bit Python (use 64-bit)" -ForegroundColor Yellow
        Write-Host "3. Network issues" -ForegroundColor Yellow
        exit 1
    }
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

if (-not $IsDev) {
    Write-Log "Building frontend for production..." -Color Cyan
    Invoke-Quiet { npm run build }
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Always "[ERROR] Frontend production build failed."
        exit 1
    }
}

# Start services - status bar always shown
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Qwen3-TTS Studio is running!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Frontend: http://localhost:3000" -ForegroundColor White
Write-Host "  Backend:  http://localhost:8000" -ForegroundColor White
if ($IsDev) {
    Write-Host "  Mode:     development (--dev)" -ForegroundColor Yellow
} else {
    Write-Host "  Mode:     production (default)" -ForegroundColor Green
}
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
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "& { Set-Location '$ProjectDir\backend'; . '.\venv\Scripts\Activate.ps1'; python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 }"
} else {
    Start-Process powershell -ArgumentList "-WindowStyle", "Hidden", "-Command", "& { Set-Location '$ProjectDir\backend'; . '.\venv\Scripts\Activate.ps1'; python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 }" -WindowStyle Hidden
}

# Start frontend in current window
Set-Location "$ProjectDir\frontend"
if ($IsDev) {
    if ($IsVerbose) {
        npm run dev
    } else {
        npm run dev *> $null
    }
} else {
    if ($IsVerbose) {
        npm run start
    } else {
        npm run start *> $null
    }
}
