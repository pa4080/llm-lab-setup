# LLM Home Lab

_My home lab for LLMs, running on a single Nvidia RTX 3090 24GB GPU._

Folder structure:

```bash
llm-lab/
├── llama-cpp/             # LLaMA.cpp Docker-compose Setup
│   ├── serve.sh           # Entrypoint script for LLaMA.cpp Docker-compose setup
│   ├── docker-compose.yml # Docker-compose file for LLaMA.cpp
│   ├── router.ini         # **auto-generated Configuration files for LLaMA.cpp router
│   ├── router/            # The configuration files for different models
│   ├── confs/             # **auto-generated Configuration files for VSCode Copilot Chat
├── scripts/               # Scripts that process `llama-cpp/router` and auto generate some stuff
├── models/                # Link to the models directory (huggingface, etc.)
├── confs/                 # **auto-generated Configuration files for VSCode Copilot Chat
├── .env                   # Environment variables for Docker-compose and "serve.sh"
│
├── llama-cpp-prism/       # Prism.LLaMA.cpp Systemd Setup playground
│   ├── serve.sh           # Entrypoint script for LLaMA.cpp Systemd setup
│   ├── bin/               # Executables for Prism.LLaMA.cpp
│   ├── systemd/           # Systemd service files for Prism.LLaMA.cpp
│   ├── router.ini         # **auto-generated Configuration files for LLaMA.cpp router
│   ├── router/            # The configuration files for different models
│   ├── confs/             # **auto-generated Configuration files for VSCode Copilot Chat
│
├── docs/                  # Some notes
├── llama-cpp-bull/        # Buun.LLaMA.cpp  Docker-compose Setup playground
├── sglang/                # SGLang playground
```

## Hardware

- GPU: Nvidia RTX 3090 24GB
- CPU: AMD Ryzen 9 5900
- RAM: 64GB DDR4
- ProxMox VM with Ubuntu 24.04

## 📊 Benchmarks

Context limits measured on **RTX 3090 (24 GB)** with llama.cpp, `n-gpu-layers=99`, `flash-attn=on`, `fit=on`.

...

## 📋 Helper commands

### Docker

```bash
docker compose down && docker compose up -d && docker logs -f llama-cpp
```

```bash
docker compose down
docker compose up -d
docker logs -f llama-cpp
```

```bash
docker run --rm ghcr.io/ggml-org/llama.cpp:server-cuda --help
```

### Power limit

```bash
sudo nvidia-smi -i 0 -pl 300
```

### Monitoring

```bash
watch nvidia-smi -i 0
```

```bash
nvtop
```

### Hugging Face

Download model:

```bash
hf download deepreinforce-ai/Ornith-1.0-9B-GGUF --local-dir deepreinforce-ai/Ornith-1.0-9B-GGUF  --include "**"
```

Download dataset:

```bash
hf download --repo-type dataset spiritbuun/turboquant-tcq-kv-cache --local-dir spiritbuun/turboquant-tcq-kv-cache
```

## Custom INI Hints

The `parse_ini()` in `scripts/generate-json-copilot.sh` and `scripts/generate-json-pi.sh` understands a few **commented** pseudo-parameters per model section. They are never passed to `llama-server` (they stay commented in `router.ini`) and only affect the generated Copilot/pi JSON:

| Hint                              | Example                                                 | Effect                                                                                                                                                                                       |
| --------------------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dummy-ctx-size`                  | `; dummy-ctx-size = 65536`                              | Fallback ctx-size for `maxInputTokens`/`contextWindow` when the preset has no real `ctx-size` (e.g. `--fit` presets).                                                                        |
| `client-ctx-size`                 | `; client-ctx-size = 128000`                            | Overrides the reported client context size (e.g. `fit = on` with a capped window).                                                                                                           |
| `client-reasoning-efforts`        | `; client-reasoning-efforts = xhigh, medium, low, none` | Supported `reasoning_effort` values advertised in the generated JSON (Copilot `supportsReasoningEffort`, pi `thinkingLevelMap`; `none` maps to pi `off`). Falls back to `low, medium, high`. |
| `client-reasoning-effort-default` | `; client-reasoning-effort-default = xhigh`             | Default `reasoningEffort` (Copilot `settings`). Must be one of the listed efforts; otherwise the first listed effort (or `high`) is used.                                                    |

Example (from `llama-cpp/router/1-Qwen3.8-27B.ini`):

```ini
[Qwen3.8_27B-Q4KM-128K-MTP_Vision]
ctx-size = 131072
; client-ctx-size = 128000
; client-reasoning-efforts = xhigh, medium, low, none
; client-reasoning-effort-default = xhigh
```

Regenerate the JSON with `serve.sh` (or `scripts/generate-config-json.sh`) after editing a `router/*.ini`.

## Test Command

```bash
curl -s -X POST "http://localhost:10005/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LLAMA_API_KEY" \
  -d '{
    "model": "Qwen3.6_27B-AR-Q4KM-128K-MTP_Vision",
    "messages": [{"role": "user", "content": "Write a haiku!"}]
  }' | jq
```

```bash
curl -s -X GET "http://localhost:10005/v1/models" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LLAMA_API_KEY" | jq
```
