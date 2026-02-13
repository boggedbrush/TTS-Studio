@echo off
REM Qwen3-TTS Native Run Script for Windows
REM Supports: CUDA (NVIDIA), DirectML (AMD/Intel), and CPU
REM Usage: run-windows.bat [--verbose | -v] [--dev | -d]

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%.."
set "VERBOSE=0"
set "DEV_MODE=0"

REM Parse arguments
:parse_args
if "%~1"=="" goto :end_parse
if "%~1"=="--verbose" set "VERBOSE=1"
if "%~1"=="-v" set "VERBOSE=1"
if "%~1"=="--dev" set "DEV_MODE=1"
if "%~1"=="-d" set "DEV_MODE=1"
shift
goto :parse_args
:end_parse

if %VERBOSE%==1 (
    echo.
    echo =========================================
    echo   Qwen3-TTS Studio - Windows Native Setup
    echo =========================================
    echo.
)

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python 3 is required but not installed.
    echo Download from: https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during installation.
    pause
    exit /b 1
)

if %VERBOSE%==1 (
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
    echo [OK] Python %PYTHON_VERSION% found
)

REM Check Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is required but not installed.
    echo Download from: https://nodejs.org/
    pause
    exit /b 1
)

if %VERBOSE%==1 (
    for /f "tokens=1" %%i in ('node --version') do set NODE_VERSION=%%i
    echo [OK] Node.js %NODE_VERSION% found
)

REM Detect GPU
set GPU_TYPE=cpu

REM Check for NVIDIA GPU first
nvidia-smi >nul 2>&1
if not errorlevel 1 (
    if %VERBOSE%==1 echo [OK] NVIDIA GPU detected - CUDA acceleration available
    set GPU_TYPE=cuda
    goto :gpu_done
)

REM Check for AMD GPU using wmic
for /f "tokens=*" %%a in ('wmic path win32_videocontroller get name ^| findstr /i "AMD Radeon"') do (
    if %VERBOSE%==1 echo [OK] AMD GPU detected - DirectML acceleration available
    set GPU_TYPE=directml
    goto :gpu_done
)

REM Check for Intel GPU
for /f "tokens=*" %%a in ('wmic path win32_videocontroller get name ^| findstr /i "Intel"') do (
    if %VERBOSE%==1 echo [OK] Intel GPU detected - DirectML acceleration available
    set GPU_TYPE=directml
    goto :gpu_done
)

if %VERBOSE%==1 echo [WARN] No supported GPU detected, using CPU (will be slower)

:gpu_done

REM Setup backend virtual environment
if %VERBOSE%==1 (
    echo.
    echo Setting up Python backend...
)
cd /d "%PROJECT_DIR%\backend"

if not exist "venv" (
    if %VERBOSE%==1 echo Creating virtual environment...
    if %VERBOSE%==1 (
        python -m venv venv
    ) else (
        python -m venv venv >nul 2>&1
    )
)

call venv\Scripts\activate.bat

REM Install PyTorch with appropriate backend
if %VERBOSE%==1 echo Installing dependencies...

if %VERBOSE%==1 (
    python -m pip install --upgrade pip
) else (
    python -m pip install --upgrade pip >nul 2>&1
)

if "%GPU_TYPE%"=="cuda" (
    if %VERBOSE%==1 echo Installing PyTorch with CUDA support...
    if %VERBOSE%==1 (
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    ) else (
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 >nul 2>&1
    )
) else if "%GPU_TYPE%"=="directml" (
    if %VERBOSE%==1 echo Installing PyTorch with DirectML support...
    if %VERBOSE%==1 (
        pip install torch torchvision torchaudio
        pip install torch-directml
    ) else (
        pip install torch torchvision torchaudio >nul 2>&1
        pip install torch-directml >nul 2>&1
    )
) else (
    if %VERBOSE%==1 echo Installing PyTorch CPU version...
    if %VERBOSE%==1 (
        pip install torch torchvision torchaudio
    ) else (
        pip install torch torchvision torchaudio >nul 2>&1
    )
)

if %VERBOSE%==1 (
    pip install -r requirements.txt
) else (
    pip install -r requirements.txt >nul 2>&1
)

REM Setup frontend
if %VERBOSE%==1 (
    echo.
    echo Setting up Node.js frontend...
)
cd /d "%PROJECT_DIR%\frontend"

if not exist "node_modules" (
    if %VERBOSE%==1 (
        call npm install
    ) else (
        call npm install >nul 2>&1
    )
)

if %DEV_MODE%==0 (
    if %VERBOSE%==1 (
        echo Building frontend for production...
        call npm run build
    ) else (
        call npm run build >nul 2>&1
    )
    if errorlevel 1 (
        echo [ERROR] Frontend production build failed.
        exit /b 1
    )
)

REM Print status bar (always shown)
echo.
echo =========================================
echo   Qwen3-TTS Studio is running!
echo =========================================
echo.
echo   Frontend: http://localhost:3000
echo   Backend:  http://localhost:8000
if %DEV_MODE%==1 (
    echo   Mode:     development (--dev)
) else (
    echo   Mode:     production (default)
)
echo.
if "%GPU_TYPE%"=="cuda" (
    echo   NVIDIA GPU acceleration enabled
) else if "%GPU_TYPE%"=="directml" (
    echo   DirectML acceleration enabled
) else (
    echo   CPU mode (no GPU acceleration)
)
echo.
echo Press Ctrl+C to stop both services
echo =========================================
echo.

REM Start backend in a new window
cd /d "%PROJECT_DIR%\backend"
if %VERBOSE%==1 (
    start "Qwen3-TTS Backend" cmd /c "call venv\Scripts\activate.bat && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"
) else (
    start /min "Qwen3-TTS Backend" cmd /c "call venv\Scripts\activate.bat && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 >nul 2>&1"
)

REM Start frontend in current window
cd /d "%PROJECT_DIR%\frontend"
if %DEV_MODE%==1 (
    if %VERBOSE%==1 (
        call npm run dev
    ) else (
        call npm run dev >nul 2>&1
    )
) else (
    if %VERBOSE%==1 (
        call npm run start
    ) else (
        call npm run start >nul 2>&1
    )
)

pause
