#!/bin/bash

source ../.env

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Generate JSON config for every router INI file into confs/
# Skip files that are shared defaults (start with 0, or contain default/common)
rm -rf "$SCRIPT_DIR/confs"
mkdir -p "$SCRIPT_DIR/confs"

for ini in "$SCRIPT_DIR/router"/*.ini; do
	[[ -f "$ini" ]] || continue
	bname="$(basename "$ini")"
	# Skip 0-prefixed files
	[[ "$bname" == 0-* ]] && continue
	# Skip files with "default" or "common" in the name (case-insensitive)
	[[ "${bname,,}" == *default* ]] && continue
	[[ "${bname,,}" == *common* ]] && continue
	bash "$SCRIPT_DIR/generate-json.sh" "$ini" "$SCRIPT_DIR/confs"
done
# Merge all individual JSONs into a single 0-chatLanguageModels.json
bash "$SCRIPT_DIR/merge-json.sh" "$SCRIPT_DIR/confs"