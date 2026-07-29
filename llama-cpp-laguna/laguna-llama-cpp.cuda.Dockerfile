# Custom build file for poolsideai/llama.cpp (laguna branch).
#
# This is a trimmed/patched copy of the fork's own .devops/cuda.Dockerfile.
# Kept outside the laguna-llama-cpp/ clone so `git pull` there stays clean.
#
# Deltas vs. upstream .devops/cuda.Dockerfile:
#   - LAGUNA_CUDA_DOCKER_ARCH defaults to 89 (RTX 3090 / sm_89) instead of "default"
#     (building all archs is a lot slower and we only run on one GPU model).
#   - Builds only the `server` target (drops "full" and "light" stages).
#   - Uses LLAMA_CUDA=1 to enable the CUDA backend.

ARG UBUNTU_VERSION=24.04
# This needs to generally match the container host's environment.
ARG LAGUNA_CUDA_VERSION=12.8
ARG GCC_VERSION=14
ARG BASE_CUDA_DEV_CONTAINER=docker.io/nvidia/cuda:${LAGUNA_CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}
ARG BASE_CUDA_RUN_CONTAINER=docker.io/nvidia/cuda:${LAGUNA_CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

ARG BUILD_DATE=N/A
ARG APP_VERSION=N/A
ARG APP_REVISION=N/A

ARG NODE_VERSION=24

FROM docker.io/node:$NODE_VERSION AS web

ARG APP_VERSION

WORKDIR /app/tools/ui

COPY tools/ui/package.json tools/ui/package-lock.json ./
RUN npm ci

COPY tools/ui/ ./
RUN LLAMA_BUILD_NUMBER="$APP_VERSION" npm run build

FROM ${BASE_CUDA_DEV_CONTAINER} AS build

ARG GCC_VERSION
# CUDA architecture to build for. Pinned to sm_89 (RTX 3090/4090) by default for fast
# builds; override with --build-arg LAGUNA_CUDA_DOCKER_ARCH=default to build all archs.
ARG LAGUNA_CUDA_DOCKER_ARCH=89

RUN apt-get update && \
	apt-get install -y gcc-${GCC_VERSION} g++-${GCC_VERSION} build-essential cmake python3 python3-pip git libssl-dev libgomp1

ENV CC=gcc-${GCC_VERSION} CXX=g++-${GCC_VERSION} CUDAHOSTCXX=g++-${GCC_VERSION}

WORKDIR /app

COPY . .

COPY --from=web /app/tools/ui/dist tools/ui/dist

# poolsideai/llama.cpp (laguna branch): enables CUDA support for DFlash speculative
# decoding and standard Laguna model loading. The DFlash draft model
# (laguna-s-2.1-DFlash-BF16.gguf) requires this fork — standard llama.cpp
# upstream fails with "unknown speculative type: dflash".
RUN if [ "${LAGUNA_CUDA_DOCKER_ARCH}" != "default" ]; then \
		CMAKE_CUDA_ARCH="${LAGUNA_CUDA_DOCKER_ARCH}"; \
	else \
		CMAKE_CUDA_ARCH=""; \
	fi && \
	cmake -B build \
		-DGGML_CUDA=ON \
		-DLLAMA_CUDA=ON \
		-DCMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCH}" \
		-DCMAKE_BUILD_TYPE=Release \
		. && \
	cmake --build build -j$(nproc) --target llama-server

FROM ${BASE_CUDA_RUN_CONTAINER} AS server

RUN apt-get update && \
	apt-get install -y libgomp1 libstdc++6 git && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/build/bin/llama-server /app/llama-server
COPY --from=build /app/build/bin/llama-cli /app/llama-cli
COPY --from=build /app/build/bin/llama-grammar-eval /app/llama-grammar-eval
COPY --from=build /app/build/bin/llama-cli /app/llama-cli
COPY --from=web /app/tools/ui/dist /app/tools/ui/dist
COPY --from=build /app/examples /app/examples
COPY --from=build /app/grammars /app/grammars
COPY --from=build /app/models /app/models

# Create a non-root user for security
RUN useradd -u 1000 -m appuser && \
	chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

ENTRYPOINT ["/app/llama-server"]
