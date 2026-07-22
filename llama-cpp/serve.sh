#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/../scripts"
source "$SCRIPT_DIR/serve-env-init.sh"
source "$SCRIPT_DIR/serve-generic.sh"

#  --------------------
#  RUN LLAMA-CPP SERVER
#  --------------------

docker compose down
docker compose up -d
docker logs -f llama-cpp
