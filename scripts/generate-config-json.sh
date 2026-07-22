#!/bin/bash
# Generate JSON configs from router INI files.
# Usage: ./generate-config-json.sh [router-dir] [confs-dir]
#
# Both paths are resolved from the caller's working directory (not from this script's location).
# Defaults: ./router  ./confs

set -euo pipefail

source ../.env

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROUTER_DIR="${1:-router}"
CONFS_PARTS_DIR="${2:-confs}"

# Generate JSON config for every router INI file into confs/
# Skip files that are shared defaults (start with 0, or contain default/common)
rm -rf "$CONFS_PARTS_DIR"
mkdir -p "$CONFS_PARTS_DIR/copilot"
mkdir -p "$CONFS_PARTS_DIR/pi"

# Loop through all INI files in router/ and generate JSON for each
for ini in "$ROUTER_DIR"/*.ini; do
	[[ -f "$ini" ]] || continue
	bname="$(basename "$ini")"
	# Skip 0-prefixed files
	[[ "$bname" == 0-* ]] && continue
	# Skip files with "default" or "common" in the name (case-insensitive)
	[[ "${bname,,}" == *default* ]] && continue
	[[ "${bname,,}" == *common* ]] && continue
	bash "$SCRIPT_DIR/generate-json-copilot.sh" "$ini" "$CONFS_PARTS_DIR/copilot"
	bash "$SCRIPT_DIR/generate-json-pi.sh" "$ini" "$CONFS_PARTS_DIR/pi"
done

# Merge all individual JSONs into single merged configs
bash "$SCRIPT_DIR/merge-json-copilot.sh" "$CONFS_PARTS_DIR/copilot"
bash "$SCRIPT_DIR/merge-json-pi.sh" "$CONFS_PARTS_DIR/pi"
