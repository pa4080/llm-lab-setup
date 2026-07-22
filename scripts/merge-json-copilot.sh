#!/bin/bash
# Merge all individual JSON configs into a single 0-chatLanguageModels.json
# Usage: ./merge-json.sh [confs-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFS_DIR="${1:-$SCRIPT_DIR/confs}"

# ── Load env vars (safe parser — no `source` to avoid ${input:...} errors) ─
source "$SCRIPT_DIR/env-helper.sh"

LOCAL_SERVER_NAME="$(get_env LOCAL_SERVER_NAME)"
LOCAL_API_KEY="$(get_env LOCAL_API_KEY)"

: "${LOCAL_SERVER_NAME:?LOCAL_SERVER_NAME not set in .env}"
: "${LOCAL_API_KEY:?LOCAL_API_KEY not set in .env}"

OUT_FILE="$CONFS_DIR/0-chatLanguageModels.json"

# ── Slurp all individual JSONs, merge models[] and settings{} ────
# Each file is: { name, vendor, apiKey, models: [...], settings: {...} }
# We merge all models into one array, all settings into one object.
jq -s \
	--arg name "$LOCAL_SERVER_NAME" \
	--arg vendor "customendpoint" \
	--arg apiKey "$LOCAL_API_KEY" \
	'
	[
		{
			name: $name,
			vendor: $vendor,
			apiKey: $apiKey,
			models: [ .[].models[] ],
			settings: ( [ .[].settings | to_entries[] ] | from_entries )
		}
	]
	' "$CONFS_DIR"/*.json > "$OUT_FILE"

echo "✓  $OUT_FILE"
