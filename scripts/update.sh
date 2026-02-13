#!/bin/bash
# Qwen3-TTS Update Script for macOS/Linux
# Updates git checkout (if clean), backend dependencies, and frontend dependencies.
# Usage: ./scripts/update.sh [--verbose|-v] [--dev] [--skip-git]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERBOSE=false
DEV_MODE=false
SKIP_GIT=false

for arg in "$@"; do
    case $arg in
        --verbose|-v)
            VERBOSE=true
            ;;
        --dev)
            DEV_MODE=true
            ;;
        --skip-git)
            SKIP_GIT=true
            ;;
    esac
done

log() {
    if [ "$VERBOSE" = true ]; then
        echo "$@"
    fi
}

warn() {
    echo -e "${YELLOW}$@${NC}"
}

error() {
    echo -e "${RED}$@${NC}" >&2
}

run_quiet() {
    if [ "$VERBOSE" = true ]; then
        "$@"
    else
        "$@" > /dev/null 2>&1
    fi
}

run_stderr_only() {
    if [ "$VERBOSE" = true ]; then
        "$@"
    else
        "$@" > /dev/null
    fi
}

detect_python() {
    for version in python3.13 python3.12 python3.11 python3.10 python3; do
        if command -v "$version" > /dev/null 2>&1; then
            echo "$version"
            return 0
        fi
    done
    return 1
}

PYTHON_CMD="$(detect_python || true)"
if [ -z "$PYTHON_CMD" ]; then
    error "Python 3.10+ is required but not installed."
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJOR=$($PYTHON_CMD -c 'import sys; print(sys.version_info.major)')
PYTHON_MINOR=$($PYTHON_CMD -c 'import sys; print(sys.version_info.minor)')
if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]); then
    error "Python 3.10+ is required, found $PYTHON_VERSION."
    exit 1
fi

if ! command -v node > /dev/null 2>&1; then
    error "Node.js is required but not installed."
    exit 1
fi

echo "Updating Qwen3-TTS..."
echo "Project: $PROJECT_DIR"
if [ "$DEV_MODE" = true ]; then
    echo "Mode: development (skip frontend build)"
else
    echo "Mode: production (includes frontend build)"
fi

if [ "$SKIP_GIT" = false ] && command -v git > /dev/null 2>&1 && [ -d "$PROJECT_DIR/.git" ]; then
    log "Checking git status before pull..."
    if [ -n "$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)" ]; then
        warn "Local changes detected; skipping git pull."
    else
        echo "Pulling latest changes..."
        run_stderr_only git -C "$PROJECT_DIR" pull --ff-only
    fi
fi

echo "Updating backend dependencies..."
cd "$PROJECT_DIR/backend"

if [ ! -d "venv" ]; then
    log "Creating Python virtual environment..."
    run_quiet "$PYTHON_CMD" -m venv venv
fi

source venv/bin/activate
run_quiet python -m pip install --upgrade pip
run_stderr_only pip install -r requirements.txt

echo "Updating frontend dependencies..."
cd "$PROJECT_DIR/frontend"
run_stderr_only npm install

if [ "$DEV_MODE" = false ]; then
    echo "Building frontend..."
    run_stderr_only npm run build
fi

echo -e "${GREEN}Update complete.${NC}"
