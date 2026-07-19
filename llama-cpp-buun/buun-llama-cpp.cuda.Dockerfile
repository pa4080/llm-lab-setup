# Custom build file for spiritbuun/buun-llama-cpp (server target only).
#
# This is a trimmed/patched copy of the fork's own .devops/cuda.Dockerfile.
# Kept outside the buun-llama-cpp/ clone so `git pull` there stays clean.
#
# Deltas vs. upstream .devops/cuda.Dockerfile:
#   - BUUN_CUDA_DOCKER_ARCH defaults to 86 (RTX 3090 / sm_86) instead of "default"
#     (building all archs is a lot slower and we only run on one GPU model).
#   - Adds -DGGML_CUDA_FA_ALL_QUANTS=ON, required to compile the fused
#     turbo/TCQ flash-attention KV-cache decode kernels (VBR, turbo*, turbo*_tcq).
#     See CLAUDE.md "Build" section in the fork's repo root for reference.
#   - Drops the "full" and "light" stages: we only ever build target=server.

ARG UBUNTU_VERSION=24.04
# This needs to generally match the container host's environment.
ARG BUUN_CUDA_VERSION=13.0.1
ARG GCC_VERSION=14
ARG BASE_CUDA_DEV_CONTAINER=docker.io/nvidia/cuda:${BUUN_CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}
ARG BASE_CUDA_RUN_CONTAINER=docker.io/nvidia/cuda:${BUUN_CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

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
# CUDA architecture to build for. Pinned to sm_86 (RTX 3090) by default for fast
# builds; override with --build-arg BUUN_CUDA_DOCKER_ARCH=default to build all archs.
ARG BUUN_CUDA_DOCKER_ARCH=86

RUN apt-get update && \
	apt-get install -y gcc-${GCC_VERSION} g++-${GCC_VERSION} build-essential cmake python3 python3-pip git libssl-dev libgomp1

ENV CC=gcc-${GCC_VERSION} CXX=g++-${GCC_VERSION} CUDAHOSTCXX=g++-${GCC_VERSION}

WORKDIR /app

COPY . .

COPY --from=web /app/tools/ui/dist tools/ui/dist

# buun-llama-cpp fork: GGML_CUDA_FA_ALL_QUANTS=ON is required to build the fused
# turbo/TCQ flash-attention KV-cache decode kernels (VBR, turbo*, turbo*_tcq).
# Without it the server still runs, but -ct vbr / -ctk turbo*_tcq will error out.
RUN if [ "${BUUN_CUDA_DOCKER_ARCH}" != "default" ]; then \
	export CMAKE_ARGS="-DCMAKE_CUDA_ARCHITECTURES=${BUUN_CUDA_DOCKER_ARCH}"; \
	fi && \
	cmake -B build -DGGML_NATIVE=OFF -DGGML_CUDA=ON -DGGML_BACKEND_DL=ON \
	-DGGML_CPU_ALL_VARIANTS=ON -DGGML_CUDA_FA=ON -DGGML_CUDA_FA_ALL_QUANTS=ON \
	-DLLAMA_BUILD_TESTS=OFF ${CMAKE_ARGS} \
	-DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined -DCMAKE_BUILD_TYPE=Release . && \
	cmake --build build --config Release -j$(nproc)

RUN mkdir -p /app/lib && \
	find build -name "*.so*" -exec cp -P {} /app/lib \;

RUN mkdir -p /app/full \
	&& cp build/bin/* /app/full \
	&& cp *.py /app/full \
	&& cp -r conversion /app/full \
	&& cp -r gguf-py /app/full \
	&& cp -r requirements /app/full \
	&& cp requirements.txt /app/full \
	&& cp .devops/tools.sh /app/full/tools.sh

## Base image
FROM ${BASE_CUDA_RUN_CONTAINER} AS base

ARG BUILD_DATE=N/A
ARG APP_VERSION=N/A
ARG APP_REVISION=N/A
ARG IMAGE_URL=https://github.com/spiritbuun/buun-llama-cpp
ARG IMAGE_SOURCE=https://github.com/spiritbuun/buun-llama-cpp
LABEL org.opencontainers.image.created=$BUILD_DATE \
	org.opencontainers.image.version=$APP_VERSION \
	org.opencontainers.image.revision=$APP_REVISION \
	org.opencontainers.image.title="buun-llama-cpp" \
	org.opencontainers.image.description="LLM inference in C/C++ (spiritbuun fork: VBR/TCQ KV cache, mmproj-gpu-swap)" \
	org.opencontainers.image.url=$IMAGE_URL \
	org.opencontainers.image.source=$IMAGE_SOURCE

RUN apt-get update \
	&& apt-get install -y libgomp1 curl ffmpeg \
	&& apt autoremove -y \
	&& apt clean -y \
	&& rm -rf /tmp/* /var/tmp/* \
	&& find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete \
	&& find /var/cache -type f -delete

COPY --from=build /app/lib/ /app

### Server, Server only
FROM base AS server

ENV LLAMA_ARG_HOST=0.0.0.0

COPY --from=build /app/full/llama /app/full/llama-server /app/

WORKDIR /app

HEALTHCHECK CMD [ "curl", "-f", "http://localhost:8080/health" ]

ENTRYPOINT [ "/app/llama-server" ]
