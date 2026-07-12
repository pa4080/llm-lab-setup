#!/bin/bash
# Serve using buun-llama-cpp fork with VBR/TCQ optimizations
# Usage: ./serve-buun.sh [config-file]
#   config-file: router INI file in buun-router/ (default: 1-Qwen3.6-27B-AR-Q4KM-buun.ini)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${1:-1-Qwen3.6-27B-AR-Q4KM-buun.ini}"
ROUTER_DIR="$SCRIPT_DIR/buun-router"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.buun.yml"

# ── Validate ──
[[ -f "$ROUTER_DIR/$CONFIG_FILE" ]] || {
  echo "ERROR: $ROUTER_DIR/$CONFIG_FILE not found" >&2
  echo "Available configs:" >&2
  ls -1 "$ROUTER_DIR/" >&2
  exit 1
}

echo "🚀 Starting buun-llama-cpp with: $CONFIG_FILE"
echo "   Port: 10006 | Image: ghcr.io/spiritbuun/buun-llama-cpp:buildcache-cuda12-amd64"
echo ""

# Copy config to router.ini (docker-compose expects it at ./router.ini)
cp "$ROUTER_DIR/$CONFIG_FILE" "$SCRIPT_DIR/router.ini"

docker compose -f "$COMPOSE_FILE" down
docker compose -f "$COMPOSE_FILE" up -d
docker logs -f buun-llama-cpp
