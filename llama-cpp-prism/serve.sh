#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/../scripts"
source "$SCRIPT_DIR/serve-env-init.sh"

# Copy router INI files from llama-cpp to llama-cpp-prism and
# swap the paths from absolute (for docker) to relative (for local) so the scripts can find them
bash "$SCRIPT_DIR/config-copy-docker-local-mod" "$LLAMA_CPP_DIR/router" "$LLAMA_CPP_DIR/../llama-cpp/router"

source "$SCRIPT_DIR/serve-generic.sh"

#  --------------------
#  RUN LLAMA-CPP SERVER
#  --------------------

# Explicitly use CUDA 12.8 libraries (binary is compiled against CUDA 12.8)
# This ensures the runtime finds the correct CUDA 12.8 libraries even if /usr/local/cuda points to CUDA 13 via alternatives
export LD_LIBRARY_PATH=/usr/local/cuda-12/targets/x86_64-linux/lib:/usr/local/cuda-12/lib64:/usr/local/cuda-12/lib:$LD_LIBRARY_PATH
export CUDA_VISIBLE_DEVICES=0
export LLAMA_CPP_SERVER_LOG_LEVEL=info

./bin/llama-server \
  --host 0.0.0.0 \
  --port ${LLAMA_PORT} \
  --models-preset ./router.ini \
  --models-max 1 \
  --threads 16 \
  --no-warmup \
  --context-shift \
  --cache-ram 16384 \
  --cache-reuse 4096
