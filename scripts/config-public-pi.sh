#!/bin/bash
# Generate public pi config by replacing LOCAL vars with PUBLIC vars.
# Strips /chat/completions from URLs since pi expects base URLs only.
# Usage: ./config-public-pi.sh (expects ../confs and ../.env)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/env-helper.sh"

LOCAL_URL="$(get_env LOCAL_URL)"
LOCAL_SERVER_NAME="$(get_env LOCAL_SERVER_NAME)"
LOCAL_API_KEY="$(get_env LOCAL_API_KEY)"
PUBLIC_URL="$(get_env PUBLIC_URL)"
PUBLIC_SERVER_NAME="$(get_env PUBLIC_SERVER_NAME)"
PUBLIC_API_KEY="$(get_env PUBLIC_API_KEY)"

# Pi expects base URLs without /chat/completions (it appends based on api type)
PI_LOCAL_BASE_URL="${LOCAL_URL%/chat/completions}"
PI_PUBLIC_BASE_URL="${PUBLIC_URL%/chat/completions}"

# Slugify provider keys — must match models-store.json keys
# 'LLaMA.cpp Local' → 'llama-cpp-local'
LOCAL_PROVIDER_KEY="$(echo "$LOCAL_SERVER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[. ]/-/g')"
PUBLIC_PROVIDER_KEY="$(echo "$PUBLIC_SERVER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[. ]/-/g')"

# Note: source already has { providers: {...} } wrapper, so sed preserves structure
SRC="../confs/pi/models.json"
DST="../confs/pi/models.public.json"

cp "$SRC" "$DST"
sed -i \
  -e "s|${PI_LOCAL_BASE_URL}|${PI_PUBLIC_BASE_URL}|g" \
  -e "s|${LOCAL_PROVIDER_KEY}|${PUBLIC_PROVIDER_KEY}|g" \
  -e "s|${LOCAL_API_KEY}|${PUBLIC_API_KEY}|g" \
  "$DST"

echo "✓  $DST"
