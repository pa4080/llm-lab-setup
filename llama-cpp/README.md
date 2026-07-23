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

| Script                     | Description                                                                                                                                                                       |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `serve.sh`                 | Main entry point — thin wrapper: env init → optional pre-processing → `serve-generic.sh` → server-specific startup.                                                               |
| `serve-env-init.sh`        | Shared environment initialization: sources `.env`, validates required vars, sets defaults, defines `SCRIPT_DIR`/`LLAMA_CPP_DIR`.                                                  |
| `serve-generic.sh`         | Shared generic processing: JSON generation, config copying, public config generation, config swapping, and router.ini composition.                                                |
| `generate-config-json.sh`  | Loops through all router INI files and generates individual JSON configs, then merges them.                                                                                       |
| `generate-json-copilot.sh` | Parses a single INI file and generates a JSON config for VS Code Chat Language Models.                                                                                            |
| `generate-json-pi.sh`      | Parses a single INI file and generates a JSON config for pi.dev (`~/.pi/agent/models.json`). Uses `{ providers: {...} }` wrapper and stripped base URLs (no `/chat/completions`). |
| `merge-json-copilot.sh`    | Merges all individual VS Code JSON configs into a single `0-chatLanguageModels.json`.                                                                                             |
| `merge-json-pi.sh`         | Merges all individual pi.dev JSON configs into a single `0-pi-models.json`.                                                                                                       |
| `config-public-copilot.sh` | Generate public copilot config (`chatLanguageModels.public.json`) by replacing LOCAL vars with PUBLIC vars.                                                                       |
| `config-public-pi.sh`      | Generate public pi config (`models.public.json`) by replacing LOCAL vars with PUBLIC vars, stripping `/chat/completions` from URLs.                                               |
| `config-swap-copilot.sh`   | Swap our generated copilot config into the VS Code user settings file (creates target if missing).                                                                                |
| `config-swap-pi.sh`        | Copy our generated pi config to `~/.pi/agent/models.json` (overwrite mode, creates directory if missing).                                                                         |

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
