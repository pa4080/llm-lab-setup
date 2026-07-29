#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/../scripts"
source "$SCRIPT_DIR/serve-env-init.sh"
source "$SCRIPT_DIR/serve-generic.sh"

#  --------------------
#  RUN LLAMA-CPP SERVER
#  --------------------

# one-time (or after `git -C laguna-llama-cpp pull`):
if [ ! -d "./laguna-llama-cpp/.git" ]; then
  git clone --branch laguna https://github.com/poolsideai/llama.cpp ./laguna-llama-cpp
fi

docker compose down
docker compose up -d --build
docker logs -f laguna-llama-cpp