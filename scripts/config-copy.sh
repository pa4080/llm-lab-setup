#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROUTER_DIR_TARGET="${1:-router}"
ROUTER_DIR_SOURCE="${2:-../llama-cpp/router}"

cp "$ROUTER_DIR_SOURCE"/*.ini "$ROUTER_DIR_TARGET"/
sed -Ei 's#^(\w*\s*=\s*)/models#\1../models#g' "$ROUTER_DIR_TARGET"/*.ini


