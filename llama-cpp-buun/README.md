# Buun LLaMA.Cpp Router Docker Configuration

Compose `router.ini` file and run the Docker container to serve the Buun LLaMA.Cpp models.

## Why this builds from source

`spiritbuun/buun-llama-cpp` does **not** publish a runnable server image on
`ghcr.io` — only Docker `buildcache-*` layers used internally by its own CI.
Pulling `ghcr.io/ggml-org/llama.cpp:server-*` (the vanilla upstream image, as
this project used to do) gets you a binary that has never heard of `-ct vbr`,
`turbo*_tcq`, or `--mmproj-gpu-swap`; the server would reject those flags at
startup. So `docker-compose.yml` builds the fork locally from the
`buun-llama-cpp/` git clone via [buun-llama-cpp.cuda.Dockerfile](./buun-llama-cpp.cuda.Dockerfile),
which additionally sets `-DGGML_CUDA_FA_ALL_QUANTS=ON` (required to compile the
fused turbo/TCQ flash-attention KV-cache kernels — the stock `.devops/cuda.Dockerfile`
does not enable this) and pins `-DCMAKE_CUDA_ARCHITECTURES=86` for the RTX 3090
to keep build times reasonable.

## Quick Start

```bash
# one-time (or after `git -C buun-llama-cpp pull`):
git clone https://github.com/spiritbuun/buun-llama-cpp.git

./serve.sh
```

`serve.sh` runs `docker compose up -d --build`, so it rebuilds the image
whenever the `buun-llama-cpp/` source or the Dockerfile changed (cached
otherwise). The first build compiles llama.cpp from scratch and will take a
while.

For more details see the [llama-cpp README](../llama-cpp/README.md) and [Buun LLaMA.Cpp project at GitHub](https://github.com/spiritbuun/buun-llama-cpp).

## Helpers

```bash
docker run --rm docker.io/library/llama-cpp-buun-buun-llama-cpp --help
```

```bash
docker run --rm docker.io/library/llama-cpp-buun-buun-llama-cpp --help 2>&1 | grep -iE '\-\-cache-type|vbr|mmproj-gpu-swap|cache-type-k-draft'
```

## Refs

- <https://github.com/spiritbuun/buun-llama-cpp>
- <https://github.com/spiritbuun/buun-llama-cpp/blob/master/docs/docker.md>
- <https://github.com/spiritbuun/buun-llama-cpp/blob/master/README.md> (VBR / TCQ / mmproj-gpu-swap docs)
