# LLM Home Lab with

## Engine/Services Comparison table

| Feature               | LM Studio               | Ollama                 | **llama.cpp**       | **buun llama.cpp**                             | SGLang                                | vLLM                                   |
| :-------------------- | :---------------------- | :--------------------- | :------------------ | :--------------------------------------------- | :------------------------------------ | :------------------------------------- |
| **Primary Interface** | Desktop GUI             | CLI + Daemon           | CLI + Library       | CLI + OpenAI-compatible Server                 | Python API + Server                   | Python API + OpenAI-compatible API     |
| **Best For**          | Beginners, Desktop Chat | Developers, Automation | Experts, Embedded   | Researchers, Long Context, KV Innovation       | Production, Agents, Structured Output | Batch Processing, High-Throughput APIs |
| **Concurrency**       | Low (Single User)       | Low/Medium             | Low                 | Low                                            | Very High (Continuous Batching)       | High (PagedAttention)                  |
| **Model Format**      | GGUF                    | GGUF                   | GGUF                | GGUF                                           | Safetensors (Primary), GGUF (Limited) | Safetensors (HuggingFace native)       |
| **OS Support**        | Win/Mac/Linux           | Win/Mac/Linux          | Everywhere (C++)    | Everywhere (C++, CUDA/ROCm for VBR)            | Linux (CUDA, ROCm)                    | Linux (CUDA, ROCm, TPU, Trainium)      |
| **Key Advantage**     | Ease of Use             | Ecosystem/API          | Portability/Control | VBR KV Cache, TCQ Codecs, Dynamic Quantization | Throughput & Structured Generation    | Memory Efficiency & Hardware Breadth   |

## Hardware

- GPU: Nvidia RTX 3090 24GB
- CPU: AMD Ryzen 9 5900
- RAM: 64GB DDR4
- ProxMox VM with Ubuntu 24.04

## 📊 Benchmarks

Context limits measured on **RTX 3090 (24 GB)** with llama.cpp, `n-gpu-layers=99`, `flash-attn=on`, `fit=on`.

| Model (router.ini section)                        | Stable Context | MEM      |
| ------------------------------------------------- | -------------- | -------- |
| `*Qwen3.6-35B-A3B-156K-Q8-MTP2`                   | ~156K          | 21.506Gi |
| `*Qwen3.6-35B-A3B-156K-Q8-MTP2-Vision`            | ~156K          | 22.522Gi |
| `*Qwen3.6-35B-A3B-256K-Q8-Vision`                 | ~156K          | 22.385Gi |
| `*Ornith-1.0-35B-156K-Q8-MTP2-Vision-Compact-all` | ~156K          | 21.335Gi |
| ------------------------------------------------- | -------------- | -------- |
| `*Qwen3.6-27B-AR-Q4KM-128K-Q4-MTP3`               | ~128K          | 21.331Gi |
| `Qwen3.6-27B-AR-Q4KM-126K-Q8-MTP2`                | ~126K          | 23.774Gi |

## 📋 Helper commands

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

