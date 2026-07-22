#!/bin/bash

source ../.env

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/../scripts"
LLAMA_CPP_DIR="$(cd "$(dirname "$0")" && pwd)"

# Generate JSON configs from router INI files
# Pass paths relative to caller (llama-cpp/) so scripts don't use their own location
bash "$SCRIPT_DIR/generate-config-json.sh" "$LLAMA_CPP_DIR/router" "$LLAMA_CPP_DIR/confs"

# Copy generated config to project-level confs
cp "$LLAMA_CPP_DIR/confs/copilot/0-chatLanguageModels.json" "../confs/chatLanguageModels.json"
cp "$LLAMA_CPP_DIR/confs/pi/0-pi-models.json" "../confs/pi-models.json"

# Generate public config with PUBLIC env vars (only if PUBLIC_* are set)
if [[ -n "$PUBLIC_URL" && -n "$PUBLIC_SERVER_NAME" && -n "$PUBLIC_API_KEY" ]]; then
	cp ../confs/chatLanguageModels{,.public}.json
	sed -i \
	  -e "s|${LOCAL_URL}|${PUBLIC_URL}|g" \
	  -e "s|${LOCAL_SERVER_NAME}|${PUBLIC_SERVER_NAME}|g" \
	  -e "s|${LOCAL_API_KEY}|${PUBLIC_API_KEY}|g" \
	  ../confs/chatLanguageModels.public.json
fi

# Swap LOCAL config into VS Code settings
bash "$SCRIPT_DIR/config-swap.sh"

docker compose down
cat ./router/* > router.ini
docker compose up -d
docker logs -f llama-cpp
