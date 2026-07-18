#!/bin/bash

source ../.env

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/../scripts"
LLAMA_CPP_DIR="$(cd "$(dirname "$0")" && pwd)"

# Generate JSON configs from router INI files
# Pass paths relative to caller (llama-cpp/) so scripts don't use their own location
bash "$SCRIPT_DIR/config-copy.sh" "$LLAMA_CPP_DIR/router" "$LLAMA_CPP_DIR/../llama-cpp/router"
bash "$SCRIPT_DIR/generate-config-json.sh" "$LLAMA_CPP_DIR/router" "$LLAMA_CPP_DIR/confs"

# Copy generated config to project-level confs
cp "$LLAMA_CPP_DIR/confs/0-chatLanguageModels.json" "../confs/chatLanguageModels.json"

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

cat ./router/* > router.ini

export CUDA_VISIBLE_DEVICES=0

./bin/llama-server \
	--host 0.0.0.0 \
	--port 10005 \
	--models-preset ./router.ini \
	--models-max 1 \
	--threads 16 \
	--no-warmup \
	--context-shift \
	--cache-ram 16384 \
	--cache-reuse 4096

