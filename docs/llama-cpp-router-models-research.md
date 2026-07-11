# llama-cpp Router Models Research

Research summary of all models configured in the llama-cpp router (`/mnt/data/llm-lab/llama-cpp/router/`).

---

## 1. Qwen3.6-27B (Dense)

**Source:** [Qwen/Qwen3.6-27B](https://huggingface.co/Qwen/Qwen3.6-27B) | [unsloth/Qwen3.6-27B-MTP-GGUF](https://huggingface.co/unsloth/Qwen3.6-27B-MTP-GGUF)

**Developer:** Alibaba Cloud (Qwen Team) | Released April 2026

### Architecture
| Property | Value |
|---|---|
| **Type** | Dense Causal Language Model with Vision Encoder |
| **Parameters** | 27B |
| **Hidden Dimension** | 5120 |
| **Layers** | 64 |
| **Hidden Layout** | 16 × (3 × (Gated DeltaNet → FFN) → 1 × (Gated Attention → FFN)) |
| **Gated DeltaNet** | 48 linear attention heads (V), 16 (QK), head dim 128 |
| **Gated Attention** | 24 heads (Q), 4 (KV), head dim 256, RoPE dim 64 |
| **FFN Intermediate** | 17408 |
| **Context Length** | 262,144 native; extensible to ~1,010,000 via YaRN |
| **MTP** | Multi-step trained (speculative decoding) |
| **Vision** | Image + Video support (vision encoder included) |

### Key Features
- **Hybrid Architecture:** Combines Gated DeltaNet (linear attention) with Gated Attention (full attention) for efficient long-context processing
- **Thinking Mode:** Default reasoning mode with `<think>...</think>` tags; can be disabled for direct responses
- **Preserve Thinking:** New feature to retain reasoning context from historical messages, reducing redundant reasoning in agent scenarios
- **Tool Calling:** Strong agentic capabilities with `qwen3_coder` parser

### Benchmarks (Highlights)
| Benchmark | Score |
|---|---|
| SWE-bench Verified | 77.2% |
| SWE-bench Pro | 53.5% |
| SWE-bench Multilingual | 71.3% |
| Terminal-Bench 2.0 | 59.3% |
| MMLU-Pro | 86.2% |
| GPQA Diamond | 87.8% |
| LiveCodeBench v6 | 83.9% |
| AIME26 | 94.1% |
| MMMU (Vision) | 82.9% |

### Recommended Sampling Params
- **Thinking (general):** temp=1.0, top_p=0.95, top_k=20
- **Thinking (coding):** temp=0.6, top_p=0.95, top_k=20
- **Instruct (no-thinking):** temp=0.7, top_p=0.80, top_k=20, presence_penalty=1.5

### Router Configs
- `1-Qwen3.6-27B-AutoRound-Q4_K_M.ini` - AutoRound quantization
- `1-Qwen3.6-27B-MTP-Q4_K_M.ini` - MTP variant, Q4_K_M (~17GB)
- `1-Qwen3.6-27B-MTP-Q4_K_XL.ini` - MTP variant, Q4_K_XL (~18GB, higher quality)

---

## 2. Qwen3.6-35B-A3B (MoE)

**Source:** [Qwen/Qwen3.6-35B-A3B](https://huggingface.co/Qwen/Qwen3.6-35B-A3B) | [unsloth/Qwen3.6-35B-A3B-MTP-GGUF](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF)

**Developer:** Alibaba Cloud (Qwen Team) | Released April 2026

### Architecture
| Property | Value |
|---|---|
| **Type** | MoE Causal Language Model with Vision Encoder |
| **Parameters** | 35B total, **3B activated** per token |
| **Hidden Dimension** | 2048 |
| **Layers** | 40 |
| **Hidden Layout** | 10 × (3 × (Gated DeltaNet → MoE) → 1 × (Gated Attention → MoE)) |
| **Gated DeltaNet** | 32 linear attention heads (V), 16 (QK), head dim 128 |
| **Gated Attention** | 16 heads (Q), 2 (KV), head dim 256, RoPE dim 64 |
| **MoE** | 256 experts, 8 routed + 1 shared active, intermediate dim 512 |
| **Context Length** | 262,144 native; extensible to ~1,010,000 via YaRN |
| **MTP** | Multi-step trained |
| **Vision** | Image + Video support |

### Key Features
- **MoE Efficiency:** Only 3B active parameters despite 35B total → fast inference with large knowledge base
- **Same hybrid architecture** as 27B but with MoE routing for efficiency
- **Agentic Coding Power:** Tagline is "Agentic Coding Power, Now Open to All"

### Benchmarks (Highlights)
| Benchmark | Score |
|---|---|
| SWE-bench Verified | 73.4% |
| SWE-bench Pro | 49.5% |
| Terminal-Bench 2.0 | 51.5% |
| MMLU-Pro | 85.2% |
| GPQA | 86.0% |
| LiveCodeBench v6 | 80.4% |
| AIME26 | 92.7% |

### Router Configs
- `1-Qwen3.6-35B-A3B-MTP.ini` - MTP variant with IQ4_NL quantization, 122K-256K contexts, vision variants with mmproj

---

## 3. Qwopus3.6-27B-Coder

**Source:** [Jackrong/Qwopus3.6-27B-Coder-Compat-MTP-GGUF](https://huggingface.co/Jackrong/Qwopus3.6-27B-Coder-Compat-MTP-GGUF)

**Developer:** Jackrong (community) | Collaboration with Kyle Hessling

### Architecture
| Property | Value |
|---|---|
| **Type** | Dense 27B, fine-tuned from Qwopus3.6-27B-v2 |
| **Base Model** | Qwopus3.6-27B-v2 → Qwen3.6-27B |
| **Parameters** | 27B Dense |
| **Context** | 32K native (fine-tuning target); compatible with longer via YaRN |
| **MTP** | Auxiliary prediction heads (draft=2), ~1.66x speedup |

### Training Pipeline
- **Trace Inversion:** Reconstructs compressed Claude Opus reasoning "bubbles" into full step-by-step CoT chains using a Trace-Inverter-4B surrogate model
- **Training Data:**
  - 9,000 Claude Opus 4.6 trace-inverted samples
  - 5,000 Claude Opus 4.7 trace-inverted samples
  - ~10,000 Hermes agent reasoning traces (multi-turn tool calling)
- **Three-Stage Curriculum:**
  1. Format Inception (< 4K tokens) - stable reasoning templates
  2. Complexity Expansion (4K-8K tokens) - tool traces + coding tasks
  3. Long-Context SFT (8K-32K tokens) - multi-turn + replay

### Key Features
- **Specialization:** Repository-level coding, debugging, patch generation, structured tool calling
- **Compat Template:** Expanded chat-template interoperability for tool-using runtimes and OpenAI-compatible agent histories
- **No-Thinking Mode:** Designed for fast local agentic coding without long visible reasoning traces

### Benchmarks
| Benchmark | Score |
|---|---|
| SWE-bench Verified (no-thinking, Q5_K_M) | **67.0%** (335/500) |
| MMLU-Pro (base v2) | 87.43% |
| SWE-bench Verified (base v2) | 75.25% |

### Performance
- ~100 tokens/sec on RTX 5090 with MTP enabled
- MTP acceptance rate: ~76.8%

### Router Configs
- `1-Qwopus-27B-Coder.ini` - Coding specialist, temp=0.6 for deterministic code, temp=1.0 variant for exploration
- **Warning in config:** Tool-call loop bug at 77K–111K context

---

## 4. Ornith-1.0-9B (Dense)

**Source:** [deepreinforce-ai/Ornith-1.0-9B](https://huggingface.co/deepreinforce-ai/Ornith-1.0-9B) | [protoLabsAI/Ornith-1.0-9B-MTP-GGUF](https://huggingface.co/protoLabsAI/Ornith-1.0-9B-MTP-GGUF)

**Developer:** DeepReinforce AI | MIT License

### Architecture
| Property | Value |
|---|---|
| **Type** | Dense Causal Language Model |
| **Parameters** | ~9B (~19 GB in BF16) |
| **Base** | Qwen3.5-9B hybrid (linear + full attention) |
| **Context** | 262,144 tokens |
| **MTP** | KL-distilled draft head (1 nextn layer) |

### Key Features
- **Self-Improving Training:** Uses RL to jointly optimize scaffold generation and solution rollouts
- **Lightweight:** Designed for efficient single-GPU deployment (fits in 80GB GPU; quantized fits in much less)
- **MIT Licensed:** Globally accessible, no regional limitations
- **Agentic Coding:** Optimized for terminal-based coding agents

### Benchmarks (Highlights)
| Benchmark | Score |
|---|---|
| Terminal-Bench 2.1 (Terminus-2) | 43.1% |
| SWE-bench Verified | 69.4% |
| SWE-bench Pro | 42.9% |
| Claw-eval Avg | 63.1% |
| NL2Repo | 27.2% |

### MTP Performance (protoLabsAI benchmarks on RTX A6000)
| Config | tok/s | Acceptance | Speedup |
|---|---|---|---|
| Base (no MTP) | 71.0 | — | 1.00× |
| MTP n-max 2 | 118.3 | 0.766 | 1.67× |
| MTP n-max 3 | 122.6 | 0.651 | 1.73× |
| MTP n-max 4 | 120.8 | 0.565 | 1.70× |

### Router Configs
- `2-Ornith-1.0-9B.ini` - Standard variants (Q4_K_M, Q8_0), 256K-1M contexts with YaRN scaling
- `2-Ornith-1.0-9B-MTP.ini` - MTP variant, spec-draft-n-max=3, 256K-512K contexts, YaRN for 1M

---

## 5. Ornith-1.0-35B (MoE)

**Source:** [deepreinforce-ai/Ornith-1.0-35B](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B) | [SC117/Ornith-1.0-35B-MTP-APEX-GGUF](https://huggingface.co/SC117/Ornith-1.0-35B-MTP-APEX-GGUF)

**Developer:** DeepReinforce AI | MIT License

### Architecture
| Property | Value |
|---|---|
| **Type** | MoE Causal Language Model |
| **Parameters** | 35B total, **3B activated** per token |
| **Base** | Qwen3.5-35B-A3B (MoE) |
| **Experts** | 256 routed, 8 active per token |
| **Layers** | 40 transformer layers + 1 MTP layer |
| **Context** | 262,144 tokens |
| **MTP** | 1 MTP layer (785 tensors) from Qwen3.5-35B-A3B |

### Key Features
- **APEX Quantization:** MoE-aware mixed-precision quantization that classifies tensors by role (routed/shared expert, attention) and applies layer-wise precision gradient
- **APEX beats Q8_0 perplexity at half the size** — and even beats F16
- **Vision Support:** Includes mmproj-F16.gguf for multimodal capabilities with llama.cpp

### APEX Quantization Tiers
| Variant | Size | Description |
|---|---|---|
| APEX-I-Quality | 21.90 GB | Highest quality, best accuracy |
| APEX-I-Balanced | 24.18 GB | Best all-rounder, recommended |
| APEX-I-Compact | 15.85 GB | Best quality/size ratio |
| APEX-I-Mini | 13.35 GB | Most compact, fits 16GB VRAM |

### Benchmarks (Highlights)
| Benchmark | Score |
|---|---|
| Terminal-Bench 2.1 (Terminus-2) | 64.2% |
| SWE-bench Verified | 75.6% |
| SWE-bench Pro | 50.4% |
| SWE-bench Multilingual | 69.3% |
| Claw-eval Avg | 69.8% |
| NL2Repo | 34.6% |

### Router Configs
- `2-Ornith-1.0-35B.ini` - Standard (no MTP)
- `2-Ornith-1.0-35B-APEX-MTP.ini` - APEX MTP variant (~15.85GB weights), spec-draft-n-max=2 (APEX has only 1 layer), vision support, preserve_thinking chat template

---

## 6. Gemma-4-26B-A4B and Gemma-4-31B

**Source:** Google (HuggingFace access restricted at time of research)

**Developer:** Google

### Known Information
Based on the router configuration files:

| Property | Gemma-4-26B-A4B | Gemma-4-31B |
|---|---|---|
| **Type** | MoE (Mixture of Experts) | Dense |
| **Architecture** | A4B = 26B total, ~4B activated | 31B Dense |
| **Training** | QAT (Quantization-Aware Training) | QAT |
| **Context** | Configured for long context | Configured for long context |

### Router Configs
- `3-Gemma-4-26B-A4B-it-qat.ini` - Gemma 4 26B with 4B auxiliary, QAT variant
- `3-Gemma-4-31B-it-qat.ini` - Gemma 4 31B dense, QAT variant

### Note
Gemma 4 is Google's latest generation of open models. The "it" suffix indicates instruction-tuned variants. QAT (Quantization-Aware Training) means the model was trained with quantization in mind, producing better quality at lower bit widths compared to post-training quantization.

---

## Comparison Summary

| Model | Params | Active | Type | Base | Specialization | SWE-bench Verified |
|---|---|---|---|---|---|---|
| **Qwen3.6-27B** | 27B | 27B | Dense | Qwen3.6 | General + Vision | 77.2% |
| **Qwen3.6-35B-A3B** | 35B | 3B | MoE | Qwen3.6 | General + Vision | 73.4% |
| **Qwopus3.6-27B-Coder** | 27B | 27B | Dense | Qwen3.6 | Coding Agent | 67.0% (no-thinking) |
| **Ornith-1.0-9B** | 9B | 9B | Dense | Qwen3.5 | Coding Agent | 69.4% |
| **Ornith-1.0-35B** | 35B | 3B | MoE | Qwen3.5 | Coding Agent | 75.6% |
| **Gemma-4-26B-A4B** | 26B | ~4B | MoE | Gemma 4 | General | N/A |
| **Gemma-4-31B** | 31B | 31B | Dense | Gemma 4 | General | N/A |

---

## Technology Notes

### MTP (Multi-Token Prediction)
- **What:** Speculative decoding where the model predicts multiple tokens simultaneously using auxiliary heads
- **Benefit:** ~1.5-2× faster inference with no accuracy loss (verified tokens are distribution-lossless)
- **Implementation:** `--spec-type draft-mtp --spec-draft-n-max 2-3` in llama.cpp
- **Qwen3.6:** Uses NEXTN algorithm with 3 speculative steps
- **Ornith 9B:** KL-distilled MTP head by protoLabsAI
- **Ornith 35B APEX:** MTP layers sourced from Qwen3.5-35B-A3B (compatible architecture)

### YaRN (Yet another RoPE scaling)
- Extends native 262K context up to ~1M tokens
- Static scaling factor — may impact shorter text performance
- Used for 512K and 1M context configurations in router

### APEX Quantization
- MoE-aware mixed-precision quantization
- Classifies tensors by role and applies layer-wise precision gradient
- Beats Q8_0 perplexity at half the size
- Available tiers: Quality (22GB), Balanced (24GB), Compact (16GB), Mini (13GB)

### KV Cache Types
- **q4_0:** 4-bit quantized KV cache (lower memory, slight quality loss)
- **q8_0:** 8-bit quantized KV cache (higher quality, more memory)
- Router configs use q4_0 for larger contexts and q8_0 for smaller/higher-quality needs

---

## Router File Mapping

| File | Model | Key Characteristics |
|---|---|---|
| `0-Defaults.ini` | Default params | Base sampling parameters |
| `1-Qwen3.6-27B-AutoRound-Q4_K_M.ini` | Qwen3.6-27B | AutoRound quant |
| `1-Qwen3.6-27B-MTP-Q4_K_M.ini` | Qwen3.6-27B | MTP, Q4_K_M, 32K-256K |
| `1-Qwen3.6-27B-MTP-Q4_K_XL.ini` | Qwen3.6-27B | MTP, Q4_K_XL (~17GB) |
| `1-Qwen3.6-35B-A3B-MTP.ini` | Qwen3.6-35B-A3B | MoE MTP, IQ4_NL, vision |
| `1-Qwopus-27B-Coder.ini` | Qwopus3.6-27B-Coder | Coding specialist |
| `2-Ornith-1.0-9B.ini` | Ornith-1.0-9B | Standard, 256K-1M |
| `2-Ornith-1.0-9B-MTP.ini` | Ornith-1.0-9B | MTP, 256K-512K |
| `2-Ornith-1.0-35B.ini` | Ornith-1.0-35B | Standard MoE |
| `2-Ornith-1.0-35B-APEX-MTP.ini` | Ornith-1.0-35B | APEX MTP, vision |
| `3-Gemma-4-26B-A4B-it-qat.ini` | Gemma-4-26B-A4B | MoE QAT |
| `3-Gemma-4-31B-it-qat.ini` | Gemma-4-31B | Dense QAT |

---

*Research compiled from HuggingFace model cards and official documentation.*
