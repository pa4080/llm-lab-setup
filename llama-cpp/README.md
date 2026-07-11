# LLaMA Router Docker Configuration

Compose `router.ini` file and run the Docker container to serve the LLaMA models.

## Quick Start

```bash
./serve.sh
```

This will:

1. Source `../.env` for environment variables.
2. Run `generate-config-json.sh` to generate JSON configs from all router INI files.
3. Copy the merged config to `../confs/chatLanguageModels.json`.
4. Generate `../confs/chatLanguageModels.public.json` with public endpoint values.
5. Stop any running Docker container, compose `router.ini` from all INI files, and start the server.
6. Stream Docker logs.

## Scripts

| Script                    | Description                                                                                      |
| ------------------------- | ------------------------------------------------------------------------------------------------ |
| `serve.sh`                | Main entry point — orchestrates config generation, public config creation, and Docker lifecycle. |
| `generate-config-json.sh` | Loops through all router INI files and generates individual JSON configs, then merges them.      |
| `generate-json.sh`        | Parses a single INI file and generates a JSON config for VS Code Chat Language Models.           |
| `merge-json.sh`           | Merges all individual JSON configs into a single `0-chatLanguageModels.json`.                    |

## Independent Usage

```bash
# Generate JSON for a single INI file
./generate-json.sh router/1-Qwen3.6-27B-AutoRound-Q4_K_M.ini ./confs

# Merge all JSON configs in a directory
./merge-json.sh ./confs

# Generate all configs without touching Docker
./generate-config-json.sh
```

## Helper commands

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

```bash
hf download  deepreinforce-ai/Ornith-1.0-9B-GGUF --local-dir deepreinforce-ai/Ornith-1.0-9B-GGUF  --include "**"
```

## Refs

- <https://github.com/ggml-org/llama.cpp/pull/13194#issuecomment-2868343055>
