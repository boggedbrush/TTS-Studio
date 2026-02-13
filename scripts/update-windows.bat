@echo off
REM Qwen3-TTS Update Script for Windows (CMD)
REM Updates git checkout (if clean), backend dependencies, and frontend dependencies.
REM Usage: scripts\update-windows.bat [--verbose|-v] [--dev|-d] [--skip-git]

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%.."
set "VERBOSE=0"
set "DEV_MODE=0"
set "SKIP_GIT=0"

:parse_args
if "%~1"=="" goto :end_parse
if "%~1"=="--verbose" set "VERBOSE=1"
if "%~1"=="-v" set "VERBOSE=1"
if "%~1"=="--dev" set "DEV_MODE=1"
if "%~1"=="-d" set "DEV_MODE=1"
if "%~1"=="--skip-git" set "SKIP_GIT=1"
shift
goto :parse_args
:end_parse

python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is required.
    exit /b 1
)

node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is required.
    exit /b 1
)

echo Updating Qwen3-TTS...
echo Project: %PROJECT_DIR%
if %DEV_MODE%==1 (
    echo Mode: development (skip frontend build)
) else (
    echo Mode: production (includes frontend build)
)

if %SKIP_GIT%==0 (
    if exist "%PROJECT_DIR%\.git" (
        set "DIRTY=0"
        for /f %%i in ('git -C "%PROJECT_DIR%" status --porcelain 2^>nul') do set "DIRTY=1"
        if "%DIRTY%"=="1" (
            echo [WARN] Local changes detected; skipping git pull.
        ) else (
            echo Pulling latest changes...
            if %VERBOSE%==1 (
                git -C "%PROJECT_DIR%" pull --ff-only
            ) else (
                git -C "%PROJECT_DIR%" pull --ff-only >nul 2>&1
            )
            if errorlevel 1 (
                echo [WARN] Git update skipped.
            )
        )
    )
)

echo Updating backend dependencies...
cd /d "%PROJECT_DIR%\backend"
if not exist "venv" (
    if %VERBOSE%==1 (
        python -m venv venv
    ) else (
        python -m venv venv >nul 2>&1
    )
    if errorlevel 1 exit /b 1
)

call venv\Scripts\activate.bat

if %VERBOSE%==1 (
    python -m pip install --upgrade pip
) else (
    python -m pip install --upgrade pip >nul 2>&1
)
if errorlevel 1 exit /b 1

if %VERBOSE%==1 (
    pip install -r requirements.txt
) else (
    pip install -r requirements.txt >nul 2>&1
)
if errorlevel 1 exit /b 1

echo Updating frontend dependencies...
cd /d "%PROJECT_DIR%\frontend"
if %VERBOSE%==1 (
    call npm install
) else (
    call npm install >nul 2>&1
)
if errorlevel 1 exit /b 1

if %DEV_MODE%==0 (
    echo Building frontend...
    if %VERBOSE%==1 (
        call npm run build
    ) else (
        call npm run build >nul 2>&1
    )
    if errorlevel 1 exit /b 1
)

echo Update complete.
