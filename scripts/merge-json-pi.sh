#!/bin/bash
# Merge all individual pi.dev JSON configs into a single 0-pi-models.json
# Usage: ./merge-json-pi.sh [confs-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFS_DIR="${1:-$SCRIPT_DIR/confs}"

OUT_FILE="$CONFS_DIR/0-pi-models.json"

# ── Slurp all individual JSONs, merge providers objects ────────────
# Each file is: { "providers": { "<name>": { baseUrl, api, apiKey, models: [...] } } }
# We merge all providers into one object, deduplicating by provider name,
# and concatenating models arrays for providers that appear in multiple files.
jq -s \
	'
	{
		providers: (
			[ .[].providers | to_entries[] ] |
			group_by(.key) |
			map(
				.[0].key as $k |
				.[0].value as $base |
				[ .[].value.models[] ] as $merged_models |
				{ key: $k, value: ($base | .models = $merged_models) }
			) |
			from_entries
		)
	}
	' "$CONFS_DIR"/*.json > "$OUT_FILE"

echo "✓  $OUT_FILE"
