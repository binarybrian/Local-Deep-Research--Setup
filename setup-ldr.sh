#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================"
echo "  Local Deep Research - Easy Setup (Linux)"
echo "============================================"
echo

# -----------------------------------------------
# SearXNG mode selection (local vs remote)
# -----------------------------------------------
echo "Where is your SearXNG instance running?"
echo "  1) Local  (default, start a Docker container on localhost:8080)"
echo "  2) Remote (you will provide host:port)"
echo
read -rp "Enter choice [1]: " SEARXNG_MODE
SEARXNG_MODE=${SEARXNG_MODE:-1}

SEARXNG_URL="http://localhost:8080"
USE_REMOTE_SEARXNG=false

if [[ "$SEARXNG_MODE" == "2" ]]; then
    read -rp "Enter remote SearXNG address (e.g. 192.168.2.1:8080): " REMOTE_SEARXNG
    if [[ -z "$REMOTE_SEARXNG" ]]; then
        echo -e "${RED}[ERROR] No address provided. Exiting.${NC}"
        exit 1
    fi
    if [[ "$REMOTE_SEARXNG" != http://* && "$REMOTE_SEARXNG" != https://* ]]; then
        REMOTE_SEARXNG="http://$REMOTE_SEARXNG"
    fi
    SEARXNG_URL="$REMOTE_SEARXNG"
    USE_REMOTE_SEARXNG=true
    echo
    echo -e "  Using remote SearXNG at ${GREEN}${SEARXNG_URL}${NC}"
fi
echo

# -----------------------------------------------
# Ollama mode selection (local vs remote)
# -----------------------------------------------
echo "Where is your Ollama instance running?"
echo "  1) Local  (default, localhost:11434)"
echo "  2) Remote (you will provide host:port)"
echo
read -rp "Enter choice [1]: " OLLAMA_MODE
OLLAMA_MODE=${OLLAMA_MODE:-1}

OLLAMA_URL="http://localhost:11434"
USE_REMOTE_OLLAMA=false

if [[ "$OLLAMA_MODE" == "2" ]]; then
    read -rp "Enter remote Ollama address (e.g. 192.168.2.1:30068): " REMOTE_ADDR
    if [[ -z "$REMOTE_ADDR" ]]; then
        echo -e "${RED}[ERROR] No address provided. Exiting.${NC}"
        exit 1
    fi
    # Ensure the address has a scheme
    if [[ "$REMOTE_ADDR" != http://* && "$REMOTE_ADDR" != https://* ]]; then
        REMOTE_ADDR="http://$REMOTE_ADDR"
    fi
    OLLAMA_URL="$REMOTE_ADDR"
    USE_REMOTE_OLLAMA=true
    echo
    echo -e "  Using remote Ollama at ${GREEN}${OLLAMA_URL}${NC}"
fi
echo

# Export endpoints so the ollama CLI and LDR use the right services
export OLLAMA_HOST="$OLLAMA_URL"
export SEARXNG_BASE_URL="$SEARXNG_URL"

# -----------------------------------------------
# Step 0: Check prerequisites
# -----------------------------------------------
echo "[1/7] Checking prerequisites..."
echo

# Check Python
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}[ERROR] Python not found!${NC}"
    echo "Please install Python 3.10+ using your package manager."
    echo "  e.g., sudo apt install python3 python3-pip"
    exit 1
fi
PYVER=$(python3 --version 2>&1)
echo "  [OK] $PYVER"

# Check pip
if ! python3 -m pip --version &>/dev/null; then
    echo -e "${RED}[ERROR] pip not found!${NC}"
    echo "Please install pip, e.g.: sudo apt install python3-pip"
    exit 1
fi
echo "  [OK] pip is available"

# Check python3-venv
if ! python3 -c 'import venv' &>/dev/null; then
    echo -e "${RED}[ERROR] python3-venv not found!${NC}"
    echo "Please install it, e.g.: sudo apt install python3-venv"
    exit 1
fi
echo "  [OK] python3-venv is available"

# Check Docker (only required when running SearXNG locally)
if [[ "$USE_REMOTE_SEARXNG" == "false" ]]; then
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}[ERROR] Docker not found!${NC}"
        echo "Please install Docker: https://docs.docker.com/engine/install/"
        exit 1
    fi
    DOCKERVER=$(docker --version 2>&1)
    echo "  [OK] $DOCKERVER"
else
    echo "  [--] Docker check skipped (using remote SearXNG)"
fi

# Check Ollama
if [[ "$USE_REMOTE_OLLAMA" == "true" ]]; then
    # Verify the remote instance is reachable
    if curl --silent --fail --max-time 5 "${OLLAMA_URL}/api/version" &>/dev/null; then
        echo "  [OK] Remote Ollama reachable at $OLLAMA_URL"
    else
        echo -e "${YELLOW}[WARNING] Could not reach remote Ollama at $OLLAMA_URL${NC}"
        echo "          Make sure the instance is running before starting LDR."
    fi
else
    if ! command -v ollama &>/dev/null; then
        echo -e "${RED}[ERROR] Ollama not found!${NC}"
        echo "Please install Ollama from https://ollama.ai"
        exit 1
    fi
    echo "  [OK] Ollama is available (local)"
fi

echo
echo "All prerequisites found!"
echo
read -rp "Press Enter to continue..."

# -----------------------------------------------
# Step 1: Create project folder
# -----------------------------------------------
echo
echo "[2/7] Creating project folder..."
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/local-deep-research"
mkdir -p "$PROJECT_DIR"
echo "  [OK] Project folder: $PROJECT_DIR"
echo

# -----------------------------------------------
# Step 2: Set up Python virtual environment
# -----------------------------------------------
echo "[3/7] Setting up Python virtual environment..."
echo

VENV_DIR="${PROJECT_DIR}/venv"
if [[ ! -d "$VENV_DIR" ]]; then
    python3 -m venv "$VENV_DIR"
    echo "  [OK] Virtual environment created at $VENV_DIR"
else
    echo "  [OK] Virtual environment already exists at $VENV_DIR"
fi

# Activate the venv for the rest of this script
source "${VENV_DIR}/bin/activate"
echo "  [OK] Virtual environment activated"
echo

# -----------------------------------------------
# Step 3: Install LDR
# -----------------------------------------------
echo "[4/7] Installing Local Deep Research..."
echo
if ! pip install local-deep-research; then
    echo -e "${RED}[ERROR] Failed to install LDR. Check your internet connection.${NC}"
    exit 1
fi
echo
echo "  [OK] LDR installed successfully!"
echo

# -----------------------------------------------
# Step 2: Run SearXNG
# -----------------------------------------------
echo "[5/7] Setting up SearXNG search engine..."
echo

if [[ "$USE_REMOTE_SEARXNG" == "true" ]]; then
    # Verify the remote instance is reachable
    if curl --silent --fail --max-time 5 "$SEARXNG_URL" &>/dev/null; then
        echo "  [OK] Remote SearXNG reachable at $SEARXNG_URL"
    else
        echo -e "${YELLOW}[WARNING] Could not reach remote SearXNG at $SEARXNG_URL${NC}"
        echo "          Make sure the instance is running before starting LDR."
    fi
else
    # Stop and remove existing container if any
    docker stop searxng &>/dev/null || true
    docker rm searxng &>/dev/null || true

    # Run new container
    if ! docker run -d -p 8080:8080 --name searxng searxng/searxng; then
        echo -e "${RED}[ERROR] Failed to start SearXNG. Is Docker running?${NC}"
        exit 1
    fi
    echo "  [OK] SearXNG is running on http://localhost:8080"
fi
echo

# -----------------------------------------------
# Step 3: Pull Ollama model
# -----------------------------------------------
echo "[6/7] Setting up Ollama model..."
echo

if [[ "$USE_REMOTE_OLLAMA" == "true" ]]; then
    echo "  Using remote Ollama at $OLLAMA_URL — skipping local model pull."
    echo "  Make sure the desired model is already available on the remote instance."
    echo
    echo "  Tip: To pull a model on the remote instance, run:"
    echo "    curl ${OLLAMA_URL}/api/pull -d '{\"name\": \"qwen3:8b\"}'"
else
    echo "Choose a model to download:"
    echo "  1) qwen3:8b         (Fast, ~5GB, good for most tasks)"
    echo "  2) qwen3:14b        (Balanced, ~9GB)"
    echo "  3) qwen3:32b        (Smart, ~20GB, needs 16GB+ RAM)"
    echo "  4) gemma3:12b       (Google, ~8GB)"
    echo "  5) llama3.1:8b      (Meta, ~5GB)"
    echo "  6) Skip - I already have a model"
    echo
    read -rp "Enter choice (1-6): " MODEL_CHOICE

    MODEL=""
    case "$MODEL_CHOICE" in
        1) MODEL="qwen3:8b" ;;
        2) MODEL="qwen3:14b" ;;
        3) MODEL="qwen3:32b" ;;
        4) MODEL="gemma3:12b" ;;
        5) MODEL="llama3.1:8b" ;;
        6) echo "  Skipping model download." ;;
        *) echo "  Invalid choice, skipping model download." ;;
    esac

    if [[ -n "$MODEL" ]]; then
        echo
        echo "Downloading $MODEL... This may take a few minutes."
        echo
        if ollama pull "$MODEL"; then
            echo "  [OK] $MODEL ready!"
        else
            echo -e "${YELLOW}[WARNING] Model download failed. You can pull it later with: ollama pull $MODEL${NC}"
        fi
    fi
fi

# -----------------------------------------------
# Step 6: Generate quick-start script
# -----------------------------------------------
echo
echo "[7/7] Generating quick-start script..."
echo

START_SCRIPT="${PROJECT_DIR}/start-ldr.sh"
cat > "$START_SCRIPT" <<STARTEOF
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

# Activate virtual environment
source "\${SCRIPT_DIR}/venv/bin/activate"

# Skip encryption for simplicity
export LDR_BOOTSTRAP_ALLOW_UNENCRYPTED=true

# Service endpoints
export OLLAMA_HOST="${OLLAMA_URL}"
export SEARXNG_BASE_URL="${SEARXNG_URL}"

STARTEOF

# Add SearXNG startup for local mode
if [[ "$USE_REMOTE_SEARXNG" == "false" ]]; then
    cat >> "$START_SCRIPT" <<'STARTEOF'
# Start SearXNG if not already running
if ! docker ps --format '{{.Names}}' | grep -q '^searxng$'; then
    echo "Starting SearXNG..."
    docker start searxng 2>/dev/null || docker run -d -p 8080:8080 --name searxng searxng/searxng
fi

STARTEOF
fi

cat >> "$START_SCRIPT" <<STARTEOF
echo "============================================"
echo "  Starting LDR Web UI..."
echo "  Open http://localhost:5000 in your browser"
echo "============================================"
echo
echo "  SearXNG:   ${SEARXNG_URL}"
echo "  Ollama:    ${OLLAMA_URL}"
echo "  LDR Web:   http://localhost:5000"
echo
echo "  Press Ctrl+C to stop"
echo

ldr-web
STARTEOF

chmod +x "$START_SCRIPT"
echo "  [OK] Quick-start script generated: $START_SCRIPT"
echo "       Run it anytime with: $START_SCRIPT"
echo

# -----------------------------------------------
# Launch LDR Web UI
# -----------------------------------------------
export LDR_BOOTSTRAP_ALLOW_UNENCRYPTED=true
export SEARXNG_BASE_URL="$SEARXNG_URL"

echo "============================================"
echo "  Starting LDR Web UI..."
echo "  Open http://localhost:5000 in your browser"
echo "============================================"
echo
echo "  SearXNG:   $SEARXNG_URL"
echo "  Ollama:    $OLLAMA_URL"
echo "  LDR Web:   http://localhost:5000"
echo
echo "  Press Ctrl+C to stop"
echo

ldr-web
