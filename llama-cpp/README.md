# LLaMA.Cpp Router Docker Configuration

Compose `router.ini` file and run the Docker container to serve the LLaMA.Cpp models.

## Quick Start

```bash
# ln -s ../.env .env
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

| Script                     | Description                                                                                      |
| -------------------------- | ------------------------------------------------------------------------------------------------ |
| `serve.sh`                 | Main entry point — orchestrates config generation, public config creation, and Docker lifecycle. |
| `generate-config-json.sh`  | Loops through all router INI files and generates individual JSON configs, then merges them.      |
| `generate-json-copilot.sh` | Parses a single INI file and generates a JSON config for VS Code Chat Language Models.           |
| `generate-json-pi.sh`      | Parses a single INI file and generates a JSON config for pi.dev (`~/.pi/agent/models.json`).     |
| `merge-json-copilot.sh`    | Merges all individual VS Code JSON configs into a single `0-chatLanguageModels.json`.            |
| `merge-json-pi.sh`         | Merges all individual pi.dev JSON configs into a single `0-pi-models.json`.                      |

```bash
# Generate JSON for a single INI file
./generate-json-copilot.sh router/1-Qwen3.6-27B-AutoRound-Q4_K_M.ini ./confs/copilot
./generate-json-pi.sh router/1-Qwen3.6-27B-AutoRound-Q4_K_M.ini ./confs/pi

# Merge all JSON configs in a directory
./merge-json-copilot.sh ./confs/copilot
./merge-json-pi.sh ./confs/pi

# Generate all configs without touching Docker
./generate-config-json.sh
```

## Refs

- <https://github.com/ggml-org/llama.cpp/pull/13194#issuecomment-2868343055>
- <https://pi.dev/docs/latest/providers#custom-providers>
