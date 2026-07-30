# LLM Server Workspace

Local LLM inference server powered by **llama.cpp** and running the **DeltaCoder-9B** model.

## Overview

This workspace provides a local, OpenAI-compatible API server for running large language models on your machine without sending data to external services.

## Components

- **llama.cpp** (`/llama.cpp`) - C/C++ LLM inference library with multi-GPU support
- **DeltaCoder-9B** (`/models/DeltaCoder-9B-v1.1-DPO-Q6_K.gguf`) - 9B parameter code generation model, Q6_K quantized (~7.4GB)
- **llama-server** - REST API server for model inference
- **opencode.json** - Configuration for AI agent tool integration

## Quick Start

```bash
# Start the server with the included model
./run-llama-server.sh models/DeltaCoder-9B-v1.1-DPO-Q6_K.gguf

# Or set environment variable and run without arguments
export LLAMA_MODEL_PATH=/path/to/model.gguf
./run-llama-server.sh
```

Server will be available at `http://localhost:1337/v1`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LLAMA_MODEL_PATH` | - | Path to model file |
| `LLAMA_HOST` | `0.0.0.0` | Host to bind to |
| `LLAMA_PORT` | `1337` | Port to listen on |
| `LLAMA_N_GPU_LAYERS` | `99` | Number of layers offload to GPU |
| `LLAMA_THREADS` | `$(nproc)` | Number of CPU threads |
| `CONTEXT_LEN` | `131072` | Context window size |

## API Usage

```bash
# Chat completion
curl http://localhost:1337/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "deltacoder-local", "messages": [{"role": "user", "content": "Write a Python function to reverse a string"}]}'
```

## Configuration

See `/opencode.json` for AI agent configuration with the local model.

## License

This workspace uses llama.cpp which is licensed under MIT.
