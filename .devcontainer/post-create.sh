#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure user-local tools are discoverable during setup.
export PATH="$HOME/.local/bin:$PATH"

# WSL2 + Podman: NVML lives under /usr/lib/wsl/lib.
if [[ -d /usr/lib/wsl/lib ]]; then
    export LD_LIBRARY_PATH="/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}"
fi

# Update CA certificates if a real Zscaler cert is mounted (not an empty placeholder)
if [ -s /usr/local/share/ca-certificates/ZscalerRootCertificate-2048-SHA256.crt ]; then
    echo "==> Updating CA certificates (Zscaler)..."
    sudo update-ca-certificates
    if command -v update-ca-certificates-java >/dev/null 2>&1; then
        sudo update-ca-certificates-java || true
    fi
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
fi

echo "==> Checking required build tools and libraries..."
need_install=false

if ! command -v gcc >/dev/null 2>&1 || ! command -v g++ >/dev/null 2>&1; then
    need_install=true
fi
if ! command -v cmake >/dev/null 2>&1; then
    need_install=true
fi
if ! command -v ld >/dev/null 2>&1; then
    need_install=true
fi
if ! command -v python3 >/dev/null 2>&1 || ! command -v pip3 >/dev/null 2>&1; then
    need_install=true
fi
if ! command -v rg >/dev/null 2>&1; then
    need_install=true
fi
if ! ldconfig -p | grep -q "libxml2.so.2"; then
    need_install=true
fi

if [[ "$need_install" == true ]]; then
    echo "==> Installing missing dependencies..."
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
        binutils \
        build-essential \
        cmake \
        git \
        libgomp1 \
        libssl-dev \
        libxml2 \
        libxml2-dev \
        ninja-build \
        pkg-config \
        python3 \
        python3-pip \
        ripgrep
fi

if ! command -v opencode >/dev/null 2>&1; then
    echo "==> Installing OpenCode CLI..."
    curl -fsSL https://opencode.ai/install | bash
fi

echo "==> Toolchain check"
echo "    gcc: $(command -v gcc || echo missing)"
echo "    g++: $(command -v g++ || echo missing)"
echo "    cmake: $(command -v cmake || echo missing)"
echo "    ld: $(command -v ld || echo missing)"
echo "    python3: $(command -v python3 || echo missing)"
echo "    pip3: $(command -v pip3 || echo missing)"
echo "    rg: $(command -v rg || echo missing)"

if [[ -f "$WORKSPACE_ROOT/llama.cpp/requirements.txt" ]]; then
    echo "==> Installing Python requirements for llama.cpp tooling..."
    python3 -m pip install --user --break-system-packages -r "$WORKSPACE_ROOT/llama.cpp/requirements.txt"
fi

LLAMA_SRC_DIR="$WORKSPACE_ROOT/llama.cpp"
LLAMA_BUILD_DIR="${LLAMA_BUILD_DIR:-$LLAMA_SRC_DIR/build-cuda}"

if [[ ! -d "$LLAMA_SRC_DIR" ]]; then
    echo "ERROR: llama.cpp source directory not found at $LLAMA_SRC_DIR"
    exit 1
fi

if [[ "${LLAMA_SKIP_BUILD:-0}" == "1" ]]; then
    echo "==> Skipping llama.cpp build (LLAMA_SKIP_BUILD=1)."
else
    if [[ -f "$LLAMA_BUILD_DIR/CMakeCache.txt" ]] && ! grep -q "^CMAKE_GENERATOR:INTERNAL=Ninja$" "$LLAMA_BUILD_DIR/CMakeCache.txt"; then
        echo "==> Removing stale CMake cache (generator mismatch)..."
        rm -rf "$LLAMA_BUILD_DIR"
    fi

    echo "==> Configuring llama.cpp for CUDA build..."
    cmake -S "$LLAMA_SRC_DIR" -B "$LLAMA_BUILD_DIR" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_CUDA=ON \
        -DGGML_NATIVE=OFF \
        -DLLAMA_BUILD_TESTS=OFF

    echo "==> Building llama.cpp tools (llama-server, llama-cli, llama-quantize, llama-bench)..."
    cmake --build "$LLAMA_BUILD_DIR" -j"$(nproc)" \
        --target llama-server llama-cli llama-quantize llama-bench

    mkdir -p "$HOME/.local/bin"
    ln -sf "$LLAMA_BUILD_DIR/bin/llama-server" "$HOME/.local/bin/llama-server"
    ln -sf "$LLAMA_BUILD_DIR/bin/llama-cli" "$HOME/.local/bin/llama-cli"
    ln -sf "$LLAMA_BUILD_DIR/bin/llama-quantize" "$HOME/.local/bin/llama-quantize"
    ln -sf "$LLAMA_BUILD_DIR/bin/llama-bench" "$HOME/.local/bin/llama-bench"
fi

if [[ -f "$WORKSPACE_ROOT/.devcontainer/run-llama-server.sh" ]]; then
    chmod +x "$WORKSPACE_ROOT/.devcontainer/run-llama-server.sh"
    ln -sf "$WORKSPACE_ROOT/.devcontainer/run-llama-server.sh" "$HOME/.local/bin/start-llama-server"
fi

echo "==> Checking in-container GPU visibility..."
if [[ -e /dev/nvidia0 || -e /dev/dxg ]]; then
    echo "==> GPU device node visible in container."
else
    echo "WARNING: No GPU device nodes found (/dev/nvidia* or /dev/dxg)."
fi

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    echo "==> GPU check passed (nvidia-smi works inside devcontainer)."
elif [[ -x /usr/lib/wsl/lib/nvidia-smi ]] && /usr/lib/wsl/lib/nvidia-smi >/dev/null 2>&1; then
    echo "==> GPU check passed (WSL nvidia-smi works inside devcontainer)."
elif compgen -G "/usr/lib/wsl/drivers/*/nvidia-smi" >/dev/null 2>&1; then
    wsl_smi="$(ls -1 /usr/lib/wsl/drivers/*/nvidia-smi 2>/dev/null | head -n 1)"
    if [[ -n "$wsl_smi" ]] && "$wsl_smi" >/dev/null 2>&1; then
        echo "==> GPU check passed (WSL driver-store nvidia-smi works inside devcontainer)."
    else
        echo "WARNING: Found WSL driver-store nvidia-smi but invocation failed."
    fi
else
    echo "WARNING: nvidia-smi check failed in this devcontainer session."
    echo "WARNING: Rebuild/reopen may be needed so the runtime GPU device mapping is applied."
fi

if [[ -x "$LLAMA_BUILD_DIR/bin/llama-server" ]]; then
    echo "==> llama-server ready: $LLAMA_BUILD_DIR/bin/llama-server"
fi

echo "==> Local access notes"
echo "    - Runtime tuned for Podman rootless on WSL2 (CDI device: nvidia.com/gpu=all)."
echo "    - llama-server is published to WSL localhost on port 1337."
echo "    - Start server: start-llama-server /path/to/model.gguf"
echo "    - From WSL host shell: curl http://127.0.0.1:1337/health"

echo "==> Devcontainer setup complete."

