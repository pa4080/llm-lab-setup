# SGLang Router Docker Configuration

Compose `router.ini` file and run the Docker container to serve the LLaMA models.

```bash
./serve
```

## Helper commands

### Docker

```bash
docker compose down && docker compose up -d && docker logs -f llama-cpp
```

```bash
docker compose down
docker compose up -d
docker logs -f llama-cpp
```

```bash
docker run --rm ghcr.io/ggml-org/llama.cpp:server-cuda --help
```

### Power limit

```bash
sudo nvidia-smi -i 0 -pl 300
```

### Monitoring

```bash
watch nvidia-smi -i 0
```

```bash
nvtop
```

### Hugging Face

```bash
hf download  deepreinforce-ai/Ornith-1.0-9B-GGUF --local-dir deepreinforce-ai/Ornith-1.0-9B-GGUF  --include "**"
```

## Refs

- <https://github.com/ggml-org/llama.cpp/pull/13194#issuecomment-2868343055>
