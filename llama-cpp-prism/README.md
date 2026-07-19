# llama.cpp Prism (Systemd Service)

The PrismML fork of llama.cpp adds the Q2_0 2-bit quantization used by the Bonsai models. Ternary Q2_0 quantization is also supported.
Run the multi-model LLM inference server (`llama-cpp-prism`) as a persistent systemd service on your Linux host.

## Prerequisites

- **systemd** (standard on most modern distros)
- **NVIDIA GPU** (RTX 3090 on GPU 0 — the server uses CUDA)
- `.env` file at `/mnt/data/llm-lab/.env` containing `LLAMA_API_KEY` and other server variables
- `llama-cpp-prism/bin/` [binaries](https://github.com/PrismML-Eng/llama.cpp/releases) already built and in place

## Installation

### Simple service

Copy the service unit to systemd and reload the daemon:

```bash
sudo cp systemd.simple/llama-cpp-prism.service /etc/systemd/system/llama-cpp-prism.service
sudo systemctl daemon-reload
```

Or run the helper script (requires root):

```bash
sudo systemd.simple/install.sh
```

## Management

| Action      | Command                                  |
| ----------- | ---------------------------------------- |
| Enable      | `sudo systemctl enable llama-cpp-prism`  |
| Start       | `sudo systemctl start llama-cpp-prism`   |
| Stop        | `sudo systemctl stop llama-cpp-prism`    |
| Disable     | `sudo systemctl disable llama-cpp-prism` |
| Status      | `sudo systemctl status llama-cpp-prism`  |
| Logs (live) | `sudo journalctl -u llama-cpp-prism -f`  |

## Upstream References

- **<https://github.com/PrismML-Eng/llama.cpp>** — The reference C++ implementation of the llama.cpp inference engine powering this server, optimized for CPU/GPU acceleration and multi-model routing.
- **<https://github.com/ArmanJR/PrismML-Bonsai-vs-Qwen3.5-Benchmark>** — A benchmark comparison of Bonsai and Qwen3.5 models, providing insights into performance and capabilities.
- **<https://huggingface.co/prism-ml/Ternary-Bonsai-27B-gguf>** — A 27B parameter open-weight model quantized to GGUF format, fine-tuned for coding and conversational tasks, available for local inference via this server.
- **<https://huggingface.co/prism-ml/Bonsai-27B-gguf>** — A 27B parameter open-weight model in GGUF format from the Bonsai family, optimized for efficient local deployment with strong performance across reasoning and generation tasks.
