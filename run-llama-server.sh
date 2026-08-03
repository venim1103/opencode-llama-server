#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMA_SRC_DIR="$WORKSPACE_ROOT/opencode-llama-server/llama.cpp"
LLAMA_BUILD_DIR="${LLAMA_BUILD_DIR:-$LLAMA_SRC_DIR/build-cuda}"
LLAMA_SERVER_BIN="$LLAMA_BUILD_DIR/bin/llama-server"

MODEL_PATH="${1:-${LLAMA_MODEL_PATH:-}}"
if [[ -n "${1:-}" ]]; then
    shift
fi

if [[ -z "$MODEL_PATH" ]]; then
    echo "Usage: $(basename "$0") /path/to/model.gguf [extra llama-server args]"
    echo "Or set LLAMA_MODEL_PATH and run without arguments."
    exit 1
fi

if [[ ! -x "$LLAMA_SERVER_BIN" ]]; then
    echo "ERROR: llama-server binary not found at $LLAMA_SERVER_BIN"
    echo "Run: bash .devcontainer/post-create.sh"
    exit 1
fi

HOST="${LLAMA_HOST:-0.0.0.0}"
PORT="${LLAMA_PORT:-1337}"
N_GPU_LAYERS="${LLAMA_N_GPU_LAYERS:-999}"
THREADS="${LLAMA_THREADS:-$(nproc)}"
MODEL_ALIAS="${LLAMA_MODEL_ALIAS:-coder-local}"
#CONTEXT_LEN="${CONTEXT_LEN:-196608}"
#CONTEXT_LEN="${CONTEXT_LEN:-163840}"
#CONTEXT_LEN="${CONTEXT_LEN:-131072}"
#CONTEXT_LEN="${CONTEXT_LEN:-102400}"
#CONTEXT_LEN="${CONTEXT_LEN:-98304}"
CONTEXT_LEN="${CONTEXT_LEN:-65536}"
#CONTEXT_LEN="${CONTEXT_LEN:-32768}"
#CONTEXT_LEN="${CONTEXT_LEN:-16384}"
#CONTEXT_LEN="${CONTEXT_LEN:-12288}"
#CONTEXT_LEN="${CONTEXT_LEN:-8192}"
#CONTEXT_LEN="${CONTEXT_LEN:-4096}"
#K_CACHE="${K_CACHE:-f16}"
# K/V types must match: CUDA flash attention has no kernel for mixed K/V quant types and falls back to CPU
KV_CACHE="${KV_CACHE:-q8_0}"
#BATCH_SIZE="${BATCH_SIZE:-2048}"
#UBATCH_SIZE="${UBATCH_SIZE:-2048}"
POLL_ENABLED="${POLL_ENABLED:-0}"
# server slots divide -c across themselves; pin to 1 so the full context is usable per conversation
N_PARALLEL="${N_PARALLEL:-1}"
API_KEY_FILE="${LLAMA_API_KEY_FILE:-$SCRIPT_DIR/.llama-api-key}"

# MTP (NextN) self-speculative decoding: set LLAMA_SPEC_TYPE=draft-mtp for GGUFs
# that embed nextn_predict_layers (e.g. Qwen3.5 MTP quants). Leave unset for models without it.
SPEC_TYPE="${LLAMA_SPEC_TYPE:-}"
SPEC_DRAFT_N_MAX="${LLAMA_SPEC_DRAFT_N_MAX:-3}"
SPEC_DRAFT_N_MIN="${LLAMA_SPEC_DRAFT_N_MIN:-1}"
SPEC_ARGS=()
if [[ -n "$SPEC_TYPE" ]]; then
    SPEC_ARGS=(--spec-type "$SPEC_TYPE" --spec-draft-n-max "$SPEC_DRAFT_N_MAX" --spec-draft-n-min "$SPEC_DRAFT_N_MIN")
fi

# Regenerate a fresh key every run (set LLAMA_API_KEY to pin one, or LLAMA_DISABLE_API_KEY=1 to skip)
if [[ "${LLAMA_DISABLE_API_KEY:-0}" == "1" ]]; then
    API_KEY=""
else
    API_KEY="${LLAMA_API_KEY:-$(openssl rand -hex 32 2>/dev/null || head -c32 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
    printf '%s' "$API_KEY" > "$API_KEY_FILE"
    chmod 600 "$API_KEY_FILE"
    echo "==> API key (re)generated: $API_KEY_FILE"
fi

if [[ -d /usr/lib/wsl/lib ]]; then
    export LD_LIBRARY_PATH="/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}"
fi

exec "$LLAMA_SERVER_BIN" \
    -m "$MODEL_PATH" \
    --alias "$MODEL_ALIAS" \
    --host "$HOST" \
    --port "$PORT" \
    -ngl "$N_GPU_LAYERS" \
    -t "$THREADS" \
    -c "$CONTEXT_LEN" \
    -ctk "$KV_CACHE" \
    -ctv "$KV_CACHE" \
    --poll "$POLL_ENABLED" \
    -np "$N_PARALLEL" \
    -fa on \
    "${SPEC_ARGS[@]}" \
    ${API_KEY:+--api-key "$API_KEY"} \
    "$@"
