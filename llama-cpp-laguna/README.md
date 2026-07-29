# Laguna LLaMA.Cpp Router Docker Configuration

Compose `router.ini` file and run the Docker container to serve the Poolside
Laguna S 2.1 models with DFlash speculative decoding.

## Why this builds from source

`poolsideai/llama.cpp` (laguna branch) does **not** publish a runnable server
image on `ghcr.io` — only Docker `buildcache-*` layers used internally by its CI.
Pulling `ghcr.io/ggml-org/llama.cpp:server-*` (the vanilla upstream image) gets
you a binary that has never heard of `--spec-type draft-dflash`; the server
rejects that flag at startup and the model fails to load with
`unknown speculative type: dflash`. So `docker-compose.yml` builds the fork
locally from the `laguna-llama-cpp/` git clone via
[laguna-llama-cpp.cuda.Dockerfile](./laguna-llama-cpp.cuda.Dockerfile),
which additionally pins `-DCMAKE_CUDA_ARCHITECTURES=89` for the RTX 3090
to keep build times reasonable.

## Quick Start

```bash
# one-time (or after `git -C laguna-llama-cpp pull`):
git clone --branch laguna https://github.com/poolsideai/llama.cpp ./laguna-llama-cpp

./serve.sh
```

`serve.sh` runs `docker compose up -d --build`, so it rebuilds the image
whenever the `laguna-llama-cpp/` source or the Dockerfile changed (cached
otherwise). The first build compiles llama.cpp from scratch and will take a
while.

## Models

| Model                                  | Context | Spec Type               | KV Cache | Notes                   |
| -------------------------------------- | ------- | ----------------------- | -------- | ----------------------- |
| `LagunaS2.1_118B-A8B-Q4KM-256K-q4`     | 256K    | None                    | q4_0     | Standard Q4_K_M, ~68 GB |
| `LagunaS2.1_118B-A8B-Q4KM-256K-dflash` | 256K    | draft-dflash (n_max=14) | q4_0     | + 2.2 GB DFlash draft   |

## Refs

- <https://github.com/poolsideai/llama.cpp> (laguna branch)
- <https://huggingface.co/poolside/Laguna-S-2.1-GGUF>
- <https://github.com/poolsideai/llama.cpp/blob/laguna/README.md>
- <https://github.com/ggml-org/llama.cpp> (upstream; DFlash not yet merged)

## Helpers

```bash
docker run --rm docker.io/library/llama-cpp-laguna-laguna-llama-cpp --help
```

```bash
docker run --rm docker.io/library/llama-cpp-laguna-laguna-llama-cpp --help 2>&1 | grep -iE 'spec-type|dflash|draft'
```
