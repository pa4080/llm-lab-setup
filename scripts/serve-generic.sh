#!/bin/bash
# Shared generic processing for serve.sh scripts.
# Source this file (do NOT execute directly) to run the common config
# generation, copying, and setup steps shared by all serve.sh orchestrators.
#
# Expects caller to have set:
#   SCRIPT_DIR      — path to scripts/ folder
#   LLAMA_CPP_DIR   — path to the serve directory (e.g. llama-cpp-prism/)
#   .env vars        — LOCAL_URL, LOCAL_SERVER_NAME, LOCAL_API_KEY, PUBLIC_*

# Generate JSON configs from router INI files
# Pass paths relative to caller so scripts don't use their own location
bash "$SCRIPT_DIR/generate-config-json.sh" "$LLAMA_CPP_DIR/router" "$LLAMA_CPP_DIR/confs"

# Copy generated config to project-level confs
mkdir -p ../confs/copilot
mkdir -p ../confs/pi
cp "$LLAMA_CPP_DIR/confs/copilot/0-chatLanguageModels.json" "../confs/copilot/chatLanguageModels.json"
cp "$LLAMA_CPP_DIR/confs/pi/0-pi-models.json" "../confs/pi/models.json"

# Generate public configs (only if PUBLIC_* are set)
if [[ -n "$PUBLIC_URL" && -n "$PUBLIC_SERVER_NAME" && -n "$PUBLIC_API_KEY" ]]; then
  bash "$SCRIPT_DIR/config-public-copilot.sh"
  bash "$SCRIPT_DIR/config-public-pi.sh"
fi

# Swap LOCAL configs into user settings
bash "$SCRIPT_DIR/config-swap-copilot.sh"
bash "$SCRIPT_DIR/config-swap-pi.sh"

# Generate router.ini by concatenating all INI files
cat ./router/* > router.ini
