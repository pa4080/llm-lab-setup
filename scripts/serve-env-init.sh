#!/bin/bash
# Shared environment initialization for serve.sh scripts.
# Expects SCRIPT_DIR to be defined by the caller.
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/../scripts"
#   source "$SCRIPT_DIR/serve-env-init.sh"
#
# Sets: LLAMA_CPP_DIR, LLAMA_API_KEY, LLAMA_PORT

#  --------------------
#  INITIALIZE ENV VARS
#  --------------------

if [[ -f ../.env ]]; then
  source ../.env
fi

# Just to be sure the .env file is loaded
if [[ -z "$LLAMA_API_KEY" ]]; then
  echo "Error: Missing required LOCAL_* environment variables."
  exit 1
fi

: "${LLAMA_PORT:=10005}"

export LLAMA_API_KEY=${LLAMA_API_KEY}
export LLAMA_PORT=${LLAMA_PORT}

LLAMA_CPP_DIR="$(cd "$(dirname "$0")" && pwd)"
