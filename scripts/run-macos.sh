#!/bin/bash
# Qwen3-TTS Native Run Script for macOS
# Supports: MPS (Apple Silicon) and CPU (Intel)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
VERBOSE=false
for arg in "$@"; do
    case $arg in
        --verbose|-v)
            VERBOSE=true
            ;;
    esac
done

# Logging helpers - only show output in verbose mode
log() {
    if [ "$VERBOSE" = true ]; then
        echo "$@"
    fi
}

log_color() {
    if [ "$VERBOSE" = true ]; then
        echo -e "$@"
    fi
}

# Error output always shows
error() {
    echo -e "${RED}$@${NC}" >&2
}

# Run command, suppress output unless verbose or error
run_quiet() {
    if [ "$VERBOSE" = true ]; then
        "$@"
    else
        "$@" > /dev/null 2>&1
    fi
}

# Run command, show only stderr
run_stderr_only() {
    if [ "$VERBOSE" = true ]; then
        "$@"
    else
        "$@" > /dev/null
    fi
}

if [ "$VERBOSE" = true ]; then
    echo "🎙️ Qwen3-TTS Studio - macOS Native Setup"
    echo "=========================================="
fi

# Check Python - try versioned installations first (Homebrew often installs as python3.X)
PYTHON_CMD=""
for version in python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v $version &> /dev/null; then
        PYTHON_CMD=$version
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    error "❌ Python 3 is required but not installed."
    echo "Install with: brew install python3"
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJOR=$($PYTHON_CMD -c 'import sys; print(sys.version_info.major)')
PYTHON_MINOR=$($PYTHON_CMD -c 'import sys; print(sys.version_info.minor)')

# Check if Python version is 3.10 or higher
if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]); then
    error "❌ Python 3.10+ is required, but Python $PYTHON_VERSION is installed."
    echo "Upgrade with: brew install python@3.11"
    echo "Or download from: https://www.python.org/downloads/"
    exit 1
fi

log_color "${GREEN}✓ Python $PYTHON_VERSION found (using $PYTHON_CMD)${NC}"

# Check Node.js
if ! command -v node &> /dev/null; then
    error "❌ Node.js is required but not installed."
    echo "Install with: brew install node"
    exit 1
fi

NODE_VERSION=$(node -v)
log_color "${GREEN}✓ Node.js $NODE_VERSION found${NC}"

# Detect Apple Silicon vs Intel
ARCH=$(uname -m)
if [ "$ARCH" == "arm64" ]; then
    log_color "${GREEN}✓ Apple Silicon detected - MPS acceleration available${NC}"
    GPU_TYPE="mps"
else
    log_color "${YELLOW}⚠ Intel Mac detected - CPU only (no GPU acceleration)${NC}"
    GPU_TYPE="cpu"
fi

# Setup backend virtual environment
log ""
log "📦 Setting up Python backend..."
cd "$PROJECT_DIR/backend"

if [ ! -d "venv" ]; then
    log "Creating virtual environment..."
    run_quiet $PYTHON_CMD -m venv venv
fi

source venv/bin/activate

# Install dependencies
log "Installing dependencies..."
run_quiet pip install --upgrade pip
run_quiet pip install torch torchvision torchaudio  # PyTorch auto-detects MPS on macOS
run_quiet pip install -r requirements.txt

# Setup frontend
log ""
log "📦 Setting up Node.js frontend..."
cd "$PROJECT_DIR/frontend"

if [ ! -d "node_modules" ]; then
    run_quiet npm install
fi

# Start services
log ""
log "🚀 Starting services..."

# Start backend in background
cd "$PROJECT_DIR/backend"
source venv/bin/activate
if [ "$VERBOSE" = true ]; then
    python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 2>&1 &
else
    python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /dev/null 2>&1 &
fi
BACKEND_PID=$!

# Start frontend in background
cd "$PROJECT_DIR/frontend"
if [ "$VERBOSE" = true ]; then
    npm run dev 2>&1 &
else
    npm run dev > /dev/null 2>&1 &
fi
FRONTEND_PID=$!

# Trap Ctrl+C to kill both processes
cleanup() {
    echo ""
    echo "Shutting down..."
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null
    # Kill any remaining child processes
    pkill -P $$ 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Wait for services to start
sleep 3

# Get local IP for LAN access
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "localhost")

# Print persistent status bar
print_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}🎙️  Qwen3-TTS Studio is running!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "   Local:   http://localhost:3000"
    echo "   LAN:     http://$LOCAL_IP:3000"
    echo "   API:     http://$LOCAL_IP:8000"
    echo ""
    if [ "$GPU_TYPE" == "mps" ]; then
        echo -e "   ${GREEN}🍎 MPS (Metal) acceleration enabled${NC}"
    else
        echo -e "   ${YELLOW}⚠ CPU mode (no GPU acceleration)${NC}"
    fi
    echo ""
    echo -e "   ${YELLOW}Press Ctrl+C to stop${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

print_status

# Wait for both processes
wait

