#!/bin/bash
# Swap the LOCAL config entry in pi's models.json with our generated config.
# Usage: ./config-swap-pi.sh [confs-dir]
#
# Pi reads ~/.pi/agent/models.json (with { providers: {...} } wrapper)
# for provider discovery. If target doesn't exist → create it.
# If target exists → merge/replace our provider entry.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFS_DIR="${1:-$SCRIPT_DIR/../confs/pi}"
source "$SCRIPT_DIR/env-helper.sh"

LOCAL_SERVER_NAME="$(get_env LOCAL_SERVER_NAME)"
TARGET_MODELS="$(get_env LOCAL_ACTUAL_CONFIG_FILE_PI)"

: "${LOCAL_SERVER_NAME:?LOCAL_SERVER_NAME not set in .env}"
: "${TARGET_MODELS:?LOCAL_ACTUAL_CONFIG_FILE_PI not set in .env}"

SRC_CONFIG="$CONFS_DIR/models.json"
[[ -f "$SRC_CONFIG" ]] || { echo "ERROR: $SRC_CONFIG not found" >&2; exit 1; }

# ── Slugify provider key — must match models.json key ──
# 'LLaMA.cpp Local' → 'llama-cpp-local'
PROVIDER_KEY="$(echo "$LOCAL_SERVER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[. ]/-/g')"

if [[ -f "$TARGET_MODELS" ]]; then
	# Replace the provider entry inside .providers with our newly generated config.
	# --slurpfile wraps the file in an extra array, so use $src[0] to unwrap.
	jq --arg name "$PROVIDER_KEY" \
	   --slurpfile src "$SRC_CONFIG" \
	   '.providers[$name] = $src[0].providers[$name]' \
	   "$TARGET_MODELS" > "${TARGET_MODELS}.tmp" \
	   && mv "${TARGET_MODELS}.tmp" "$TARGET_MODELS"
	echo "✓  Swapped config for \"$PROVIDER_KEY\" in $TARGET_MODELS"
else
	cp "$SRC_CONFIG" "$TARGET_MODELS"
	echo "✓  Created $TARGET_MODELS from $SRC_CONFIG"
fi
