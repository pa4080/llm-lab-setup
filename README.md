# LLM Home Lab with

##  Engine/Services Comparison table

| Feature               | LM Studio               | Ollama                 | llama.cpp           | **SGLang**                            |
| :-------------------- | :---------------------- | :--------------------- | :------------------ | :------------------------------------ |
| **Primary Interface** | Desktop GUI             | CLI + Daemon           | CLI + Library       | Python API + Server                   |
| **Best For**          | Beginners, Desktop Chat | Developers, Automation | Experts, Embedded   | Production, Agents, Structured Output |
| **Concurrency**       | Low (Single User)       | Low/Medium             | Low                 | Very High (Continuous Batching)       |
| **Model Format**      | GGUF                    | GGUF                   | GGUF                | Safetensors (Primary), GGUF (Limited) |
| **OS Support**        | Win/Mac/Linux           | Win/Mac/Linux          | Everywhere (C++)    | Linux (CUDA/ROCm)                     |
| **Key Advantage**     | Ease of Use             | Ecosystem/API          | Portability/Control | Throughput & Structured Generation    |

## Hardware

- GPU: Nvidia RTX 3090 24GB
- CPU: AMD Ryzen 9 5900
- RAM: 64GB DDR4

## 📋 Agent Skill [`/add-model-to-llm-lab`](.agents/skills/add-model-to-llm-lab/SKILL.md)

Full pipeline for adding new models to your LLM Home Lab

| Step                           | What it does                                                     |
| ------------------------------ | ---------------------------------------------------------------- |
| **1. Research**                | Searches HF discussions, Reddit, Discord for optimal params      |
| **2. Download**                | `hf download` to `huggingface/<org>/<repo>/`                     |
| **3. router.ini**              | Adds model entry with correct paths, KV cache, MTP, vision, YaRN |
| **4. chatLanguageModels.json** | Syncs model ID, token limits, vision flag, reasoning effort      |
| **5. Verify**                  | Restart Docker and test                                          |

### 🔑 Key Conventions Encoded

- **Path mapping**: `huggingface/org/repo/file.gguf` → `/models/org/repo/file.gguf`
- **Gemma = f16 KV cache** (q8_0 causes loops)
- **Ornith-35B = min-p 0.0** (prevents truncation)
- **MTP = spec-draft-n-max 2/3/4**
- **YaRN scaling** for extending context beyond training
- **Token limits** mapped from ctx-size to maxInputTokens/maxOutputTokens

### 🚀 Try It

You can now say things like:

- "Add `unsloth/gemma-4-31B-it-qat-GGUF` to my lab"
- "Research and add the latest Ornith-1.0-35B fine-tune"
- "What's the best config for a 7B model on my 3090?"

The skill will guide me through the full setup automatically!
