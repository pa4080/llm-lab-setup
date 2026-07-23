#!/bin/bash
# Generate public copilot config by replacing LOCAL vars with PUBLIC vars.
# Usage: ./config-public-copilot.sh (expects ../confs and ../.env)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/env-helper.sh"

LOCAL_URL="$(get_env LOCAL_URL)"
LOCAL_SERVER_NAME="$(get_env LOCAL_SERVER_NAME)"
LOCAL_API_KEY="$(get_env LOCAL_API_KEY)"
PUBLIC_URL="$(get_env PUBLIC_URL)"
PUBLIC_SERVER_NAME="$(get_env PUBLIC_SERVER_NAME)"
PUBLIC_API_KEY="$(get_env PUBLIC_API_KEY)"

SRC="../confs/copilot/chatLanguageModels.json"
DST="../confs/copilot/chatLanguageModels.public.json"

cp "$SRC" "$DST"
sed -i \
  -e "s|${LOCAL_URL}|${PUBLIC_URL}|g" \
  -e "s|${LOCAL_SERVER_NAME}|${PUBLIC_SERVER_NAME}|g" \
  -e "s|${LOCAL_API_KEY}|${PUBLIC_API_KEY}|g" \
  "$DST"

echo "✓  $DST"
