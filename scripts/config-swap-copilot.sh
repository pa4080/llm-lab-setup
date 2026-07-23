#!/bin/bash
# Swap the LOCAL config entry in the VS Code settings file with our generated config.
# Usage: ./config-swap-copilot.sh [confs-dir] [env-file]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFS_DIR="${1:-$SCRIPT_DIR/../confs/copilot}"
ENV_FILE="${2:-$SCRIPT_DIR/../.env}"

# ── Safe env parser ──
source "$SCRIPT_DIR/env-helper.sh"

LOCAL_SERVER_NAME="$(get_env LOCAL_SERVER_NAME)"
TARGET_MODELS="$(get_env LOCAL_ACTUAL_CONFIG_FILE_VSCODE)"

: "${LOCAL_SERVER_NAME:?LOCAL_SERVER_NAME not set in .env}"
: "${TARGET_MODELS:?LOCAL_ACTUAL_CONFIG_FILE_VSCODE not set in .env}"

SRC_CONFIG="$CONFS_DIR/chatLanguageModels.json"
[[ -f "$SRC_CONFIG" ]] || { echo "ERROR: $SRC_CONFIG not found" >&2; exit 1; }

if [[ -f "$TARGET_MODELS" ]]; then
	# Replace the entry matching LOCAL_SERVER_NAME with the newly generated config.
	# The VS Code settings file may contain non-object entries (e.g. arrays),
	# so we only filter objects that have a .name field.
	# --slurpfile wraps the file in an extra array, so use $new[0] to unwrap.
	jq --arg name "$LOCAL_SERVER_NAME" \
	   --slurpfile new "$SRC_CONFIG" \
	   '
	   [ .[] | select(type != "object" or .name != $name) ] + $new[0]
	   ' "$TARGET_MODELS" > "${TARGET_MODELS}.tmp" \
	   && mv "${TARGET_MODELS}.tmp" "$TARGET_MODELS"
	echo "✓  Swapped config for \"$LOCAL_SERVER_NAME\" in $TARGET_MODELS"
else
	cp "$SRC_CONFIG" "$TARGET_MODELS"
	echo "✓  Created $TARGET_MODELS from $SRC_CONFIG"
fi
