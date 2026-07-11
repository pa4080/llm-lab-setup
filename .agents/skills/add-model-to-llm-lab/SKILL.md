---

name: add-model-to-llm-lab

# Add Model to LLM Home Lab

Automates the full pipeline of adding a new model to the LLM Home Lab setup: research best parameters, download the GGUF, create or update the model's **separate INI file** in `llama-cpp/router/`, add a benchmark row to `README.md`, and sync `chatLanguageModels.json` for VS Code Copilot.

## Scope & Limitations

- **Supported engine: llama-cpp ONLY** — all model configuration happens in `llama-cpp/router/*.ini` files and `llama-cpp/serve.sh`
- **DO NOT touch** `sglang/`, `sglang/`, `huggingface/docs/`, or any other project folders — these are reserved for future development
- Docker serves all models via `docker compose` (llama-cpp container)

## When to Use

- User wants to add a new model to their local LLM server
- User provides a model name/repo and asks to configure it
- User wants to research optimal parameters for a new model

## When NOT to Use

- Model requires >24 GB VRAM even at lowest quant (e.g., 30B+ at Q8_0)
- Model is not in GGUF format (safetensors, PyTorch, etc.)
- Model requires multi-GPU or distributed inference
- User wants to configure SGLang, Ollama, or LM Studio (out of scope)

## Prerequisites

- NVIDIA RTX 3090 24GB (single GPU)
- Docker with llama-cpp server (llama-cpp container)
- `nvidia-persistenced` active
- GPU power limit at 300W

## Workflow

### Step 1: Research Best Parameters

Search the internet for community recommendations on the target model:

1. Check **Hugging Face Discussions** for the model repo (look for parameter tuning threads)
2. Search for the model name + "llama.cpp router.ini" or "sampling params"
3. Check **Reddit** (r/LocalLLaMA) and **Discord** for community configs
4. Look for known issues: context loops, VRAM overflow, tool-call hangs

Key research targets:

- Optimal `temp`, `top-k`, `min-p`, `repeat-penalty`
- KV cache quantization (q4_0 vs q8_0 vs f16)
- MTP spec-decoding configs (draft model, n-max)
- Vision projector (`mmproj`) availability
- Context length limits (training vs inference)
- YaRN RoPE scaling needs

### Step 2: Download the Model

```bash
cd huggingface
hf download <org>/<repo> --local-dir <org>/<repo> --include "*.gguf"
```

Verify the download:

- Check that the `.gguf` file exists
- Note the quantization level from the filename (Q4_K_M, Q8_0, etc.)
- If a vision model, check for `mmproj-*.gguf` in the same repo

### Step 3: Create or Update Model's Separate INI File

**Path convention:**

- Local: `huggingface/<org>/<repo>/filename.gguf`
- router.ini: `/models/<org>/<repo>/filename.gguf`

**INI filename convention:** `<Series>-<Family>-<Size>[-<Variant>]-<Quant>[-<Feature>].ini`

| Series | Model Family           |
| ------ | ---------------------- |
| 1      | Qwen3.6 (27B, 35B-A3B) |
| 1      | Qwopus-27B-Coder       |
| 2      | Ornith-1.0 (9B, 35B)   |
| 3      | Gemma-4 (26B-A4B, 31B) |

**Choose the INI filename:** If a file for this model family already exists in `llama-cpp/router/`, update it. Otherwise create a new one following the naming convention above.

**Consolidated INI template** — include only the fields that apply:

```ini
[<ModelID>]
model = /models/<org>/<repo>/<filename>.gguf
; model-draft = /models/<org>/<repo>/<draft-gguf>          ; MTP only
; mmproj = /models/<org>/<repo>/<mmproj-file>.gguf          ; vision only
ctx-size = <ctx>
cache-type-k = <cache-k>
cache-type-v = <cache-v>
; cache-type-k-draft = <draft-cache-k>                      ; MTP only
; cache-type-v-draft = <draft-cache-v>                      ; MTP only
; spec-type = draft-mtp                                     ; MTP only
; spec-draft-n-max = <n-max>                                ; MTP only
temp = <temp>
top-k = <top-k>
; min-p = 0.0                                               ; Ornith-35B only
; presence-penalty = 0.0                                    ; Ornith-35B only
; image-min-tokens = -1                                     ; vision only
; rope-scaling = yarn                                       ; extended context only
; rope-scale = <scale>                                      ; YaRN only
; yarn-orig-ctx = <orig-ctx>                                ; YaRN only
; <used>Gi/<total>Gi
```

**Model-specific overrides:**

| Model Family                  | Overrides                                                              |
| ----------------------------- | ---------------------------------------------------------------------- |
| **Gemma** (any Gemma variant) | `cache-type-k = f16`, `cache-type-v = f16` (q8_0 causes context loops) |
| **Ornith-1.0-35B**            | `min-p = 0.0`, `presence-penalty = 0.0`                                |
| **Qwopus-27B-Coder**          | `temp = 0.6`, `top-k = 20`                                             |

**YaRN RoPE scaling** (for context > training context):

| Target ctx | Training ctx | YaRN scale | yarn-orig-ctx |
| ---------- | ------------ | ---------- | ------------- |
| 256K       | 32K          | 8          | 32768         |
| 512K       | 32K          | 16         | 32768         |
| 1M         | 32K          | 32         | 32768         |

**Context size rules:**

- Must be a power of 2 (or close): 131072, 163840, 262144, 524288, 1048576
- For context sizes that are not exact powers of 2, round to nearest valid value

**Memory estimation** (rough guide, per-model-family can vary):

- Q4_K_M: ~4.5 GB per 1B params + ~1 GB KV cache
- Q8_0: ~9 GB per 1B params + ~2 GB KV cache
- f16 KV: ~2 GB per 1B params for cache
- Comment format: `; <used>Gi/<total>Gi`

**Edge cases:**

- **Model already exists in INI file** → update the existing entry, do not duplicate
- **VRAM estimation exceeds 24 GB** → warn user, suggest lower quant or smaller context
- **Download fails** → abort, do not proceed to config

### Step 3.5: Add Benchmark Row to README.md

Append a row to the benchmark table in `README.md`:

```markdown
| <N> | `<SectionName>` | ~<stable-context> |
```

- Column 1: next sequential number (or find gap)
- Column 2: exact router.ini section name, backticked
- Column 3: achieved stable context (e.g., `~156K`, `~256K`)
- **No notes column** — keep it simple

### Step 4: Add Entry to `chatLanguageModels.json`

**URL:** `http://172.16.1.110:10005/v1/chat/completions`

**Token limits mapping:**

| router.ini ctx-size | maxInputTokens | maxOutputTokens |
| ------------------- | -------------- | --------------- |
| 108K–128K           | 82944–98304    | 27648–32768     |
| 122K–160K           | 92160–122880   | 30720–40960     |
| 256K                | 196608         | 65536           |
| 512K                | 393216         | 131072          |
| 1M                  | 393216         | 131072          |

**Required fields for every model:**

```json
{
  "id": "<ModelID>",
  "name": "<ModelID>",
  "url": "http://172.16.1.110:10005/v1/chat/completions",
  "toolCalling": true,
  "streaming": true,
  "thinking": true,
  "reasoningEffortFormat": "chat-completions",
  "supportsReasoningEffort": ["low", "medium", "high"],
  "maxInputTokens": <ctx-size>,
  "maxOutputTokens": <output-tokens>,
  "editTools": ["apply-patch", "code-rewrite", "find-replace", "multi-find-replace"]
}
```

**Vision models:** Add `"vision": true`

**MTP models:** Add `"reasoningEffort": "high"` to the `"settings"` object in `chatLanguageModels.json`:

```json
"<ModelID>": {
  "reasoningEffort": "high"
}
```

### Step 5: Complete

Verify all artifacts:

- [ ] INI file created or updated in `llama-cpp/router/`
- [ ] `chatLanguageModels.json` entry synced (id, name, token limits, vision flag, settings)
- [ ] Benchmark row added to `README.md`
- [ ] All file changes committed

## Conventions

### Naming

- Match the router.ini entry name exactly in `chatLanguageModels.json`
- Use descriptive IDs: `<Family>-<Size>-<Quant>-<Variant>`
- Examples: `Ornith-1.0-9B-256K-Q80-Q4-MTP`, `Gemma-4-26B-A4B-it-qat-256K-Q8-MTP4-Vision`

### File Organization

- Models directory: `/models/<org>/<repo>/`
- HuggingFace cache: `huggingface/<org>/<repo>/`
- Vision projectors co-located with their models
- One INI file per model family in `llama-cpp/router/`

### Docker Compose

- llama-cpp already serves all models via `--models-preset /app/router.ini`
- No changes needed to `docker-compose.yml` for new models
- `--cache-ram 10240` (10GB RAM for KV cache) is the fixed allocation

### Anti-patterns

- **Don't batch-config without VRAM math** — verify model + KV cache fits in 24 GB before writing config
- **Don't create multiple INI sections without testing** — one tested config per model is better than ten untested ones
- **Don't skip the benchmark row** — every new model must be tracked in README.md
- **Don't guess context sizes** — use the power-of-2 rule, don't pick arbitrary values

### Common Pitfalls

- **Gemma + q8_0 KV cache** = guaranteed context loop. Always use f16.
- **Ornith-1.0-35B without min-p = 0.0** = premature response termination at ~3 turns.
- **Ornith-1.0-35B with mmap** = tool-call hangs at high GPU utilization.
- **Jinja template `enable_thinking | default(false)`** = forces thought channel close, causing token repetition. Remove forced bypass for Copilot.
- **Context > training context without YaRN** = possible training context overflow.
- **MTP draft model missing** = speculative decoding fails silently.

## Example: Adding a New Model

Given: `unsloth/gemma-4-26B-A4B-it-qat-GGUF` (26B params, vision, MTP4)

1. **Research**: Check HF discussions for Gemma 4 parameter tuning
2. **Download**: `hf download unsloth/gemma-4-26B-A4B-it-qat-GGUF --local-dir unsloth/gemma-4-26B-A4B-it-qat-GGUF --include "**"`
3. **Create INI file** `llama-cpp/router/3-Gemma-4-26B-A4B-it-qat.ini`:
   ```ini
   [Gemma-4-26B-A4B-it-qat-256K-Q8-MTP4-Vision]
   model = /models/unsloth/gemma-4-26B-A4B-it-qat-GGUF/gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf
   model-draft = /models/unsloth/gemma-4-26B-A4B-it-qat-GGUF/mtp-gemma-4-26B-A4B-it.gguf
   mmproj = /models/unsloth/gemma-4-26B-A4B-it-qat-GGUF/mmproj-BF16.gguf
   ctx-size = 262144
   cache-type-k = q8_0
   cache-type-v = q8_0
   cache-type-k-draft = q8_0
   cache-type-v-draft = q8_0
   spec-type = draft-mtp
   spec-draft-n-max = 4
   temp = 0.6
   top-k = 64
   image-min-tokens = -1
   ; 17.680Gi/24Gi
   ```
4. **Add benchmark row** to `README.md`: `| 2 | \`Gemma-4-26B-A4B-it-qat-256K-Q8-MTP4-Vision\` | ~256K |`
5. **Add to `chatLanguageModels.json`**: matching entry with `maxInputTokens: 196608`, `maxOutputTokens: 65536`, `"vision": true`, and `"reasoningEffort": "high"` in settings
6. **Verify**: all four artifacts checked (INI file, JSON entry, benchmark row, committed)

# Add Model to LLM Home Lab

Automates the full pipeline of adding a new model to the LLM Home Lab setup: research best parameters, download the GGUF, create or update the model's **separate INI file** in `llama-cpp/router/`, add a benchmark row to `README.md`, and sync `chatLanguageModels.json` for VS Code Copilot.

## Scope & Limitations

- **Supported engine: llama-cpp ONLY** — all model configuration happens in `llama-cpp/router/*.ini` files and `llama-cpp/serve.sh`
- **DO NOT touch** `sglang/`, `sglang/`, `huggingface/docs/`, or any other project folders — these are reserved for future development
- Docker serves all models via `docker compose` (llama-cpp container)

## When to Use

- User wants to add a new model to their local LLM server
- User provides a model name/repo and asks to configure it
- User wants to research optimal parameters for a new model

## Prerequisites

- NVIDIA RTX 3090 24GB (single GPU)
- Docker with llama-cpp server running on `172.16.1.110:10005`
- `nvidia-persistenced` active
- GPU power limit at 300W

## Workflow

### Step 1: Research Best Parameters

Search the internet for community recommendations on the target model:

1. Check **Hugging Face Discussions** for the model repo (look for parameter tuning threads)
2. Search for the model name + "llama.cpp router.ini" or "sampling params"
3. Check **Reddit** (r/LocalLLaMA) and **Discord** for community configs
4. Look for known issues: context loops, VRAM overflow, tool-call hangs

Key research targets:

- Optimal `temp`, `top-k`, `min-p`, `repeat-penalty`
- KV cache quantization (q4_0 vs q8_0 vs f16)
- MTP spec-decoding configs (draft model, n-max)
- Vision projector (`mmproj`) availability
- Context length limits (training vs inference)
- YaRN RoPE scaling needs

### Step 2: Download the Model

```bash
cd huggingface
hf download <org>/<repo> --local-dir <org>/<repo> --include "*.gguf"
```

Verify the download:

- Check that the `.gguf` file exists
- Note the quantization level from the filename (Q4_K_M, Q8_0, etc.)
- If a vision model, check for `mmproj-*.gguf` in the same repo

### Step 3: Add Entry to `router.ini`

**Path convention:**

- Local: `huggingface/<org>/<repo>/filename.gguf`
- router.ini: `/models/<org>/<repo>/filename.gguf`

**Template for non-MTP model:**

```ini
[<ModelID>]
model = /models/<org>/<repo>/<filename>.gguf
ctx-size = <ctx>
cache-type-k = <cache-k>
cache-type-v = <cache-v>
temp = <temp>
top-k = <top-k>
; <used>Gi/<total>Gi
```

**Template for MTP (speculative decoding) model:**

```ini
[<ModelID>]
model = /models/<org>/<repo>/<filename>.gguf
model-draft = /models/<org>/<repo>/<draft-gguf>
ctx-size = <ctx>
cache-type-k = <cache-k>
cache-type-v = <cache-v>
cache-type-k-draft = <draft-cache-k>
cache-type-v-draft = <draft-cache-v>
spec-type = draft-mtp
spec-draft-n-max = <n-max>
temp = <temp>
top-k = <top-k>
; <used>Gi/<total>Gi
```

**Template for vision model:**

```ini
[<ModelID>]
model = /models/<org>/<repo>/<filename>.gguf
mmproj = /models/<org>/<repo>/<mmproj-file>.gguf
ctx-size = <ctx>
cache-type-k = <cache-k>
cache-type-v = <cache-v>
temp = <temp>
top-k = <top-k>
image-min-tokens = -1
; <used>Gi/<total>Gi
```

**Apply model-specific overrides:**

| Model Family                        | Overrides                                                                  |
| ----------------------------------- | -------------------------------------------------------------------------- |
| **Gemma** (any Gemma variant)       | `cache-type-k = f16`, `cache-type-v = f16` (q8_0 causes context loops)     |
| **Ornith-1.0-35B**                  | `min-p = 0.0`, `presence-penalty = 0.0`                                    |
| **Qwopus-27B-Coder**                | `temp = 0.6`, `top-k = 20`                                                 |
| **256K+ ctx, model trained on 32K** | Add YaRN: `rope-scaling = yarn`, `rope-scale = 8`, `yarn-orig-ctx = 32768` |
| **512K/1M ctx**                     | `rope-scaling = yarn`, `rope-scale = 2` or `4`, `yarn-orig-ctx = 262144`   |

**Context size rules:**

- Must be a power of 2 (or close): 131072, 163840, 262144, 524288, 1048576
- 256K with 32K training → YaRN scale 8 (262144 / 32768 = 8)
- 512K with 32K training → YaRN scale 16 (524288 / 32768 = 16)
- 1M with 32K training → YaRN scale 32 (1048576 / 32768 = 32)

**Memory estimation:**

- Q4_K_M: ~4.5GB per 1B params + ~1GB KV cache
- Q8_0: ~9GB per 1B params + ~2GB KV cache
- f16 KV: ~2GB per 1B params for cache
- Comment format: `; <used>Gi/<total>Gi`

### Step 4: Add Entry to `chatLanguageModels.json`

**URL:** `http://172.16.1.110:10005/v1/chat/completions`

**Token limits mapping:**

| router.ini ctx-size | maxInputTokens | maxOutputTokens |
| ------------------- | -------------- | --------------- |
| 108K–128K           | 82944–98304    | 27648–32768     |
| 122K–160K           | 92160–122880   | 30720–40960     |
| 256K                | 196608         | 65536           |
| 512K                | 393216         | 131072          |
| 1M                  | 393216         | 131072          |

**Required fields for every model:**

```json
{
  "id": "<ModelID>",
  "name": "<ModelID>",
  "url": "http://172.16.1.110:10005/v1/chat/completions",
  "toolCalling": true,
  "streaming": true,
  "thinking": true,
  "reasoningEffortFormat": "chat-completions",
  "supportsReasoningEffort": ["low", "medium", "high"],
  "maxInputTokens": <ctx-size>,
  "maxOutputTokens": <output-tokens>
}
```

**Vision models:** Add `"vision": true`

**MTP models:** Add `"reasoningEffort": "high"` to the settings block

**Edit tools (all models):**

```json
"editTools": ["apply-patch", "code-rewrite", "find-replace", "multi-find-replace"]
```

**Settings block:**
Add to `"settings"` object:

```json
"<ModelID>": {
  "reasoningEffort": "high"
}
```

### Step 5: Verify & Restart

```bash
docker compose down && docker compose up -d
docker logs -f llama-cpp
```

Check that the model loads without errors. Verify with a test prompt.

## Conventions

### Naming

- Match the router.ini entry name exactly in chatLanguageModels.json
- Use descriptive IDs: `<Family>-<Size>-<Quant>-<Variant>`
- Examples: `Ornith-1.0-9B-256K-Q80-Q4-MTP`, `Gemma-4-26B-A4B-it-qat-256K-Q8-MTP4-Vision`

### File Organization

- Models directory: `/models/<org>/<repo>/`
- HuggingFace cache: `huggingface/<org>/<repo>/`
- Vision projectors co-located with their models

### Docker Compose

- llama-cpp already serves all models via `--models-preset /app/router.ini`
- No changes needed to `docker-compose.yml` for new models
- `--cache-ram 10240` (10GB RAM for KV cache) is the fixed allocation

### Common Pitfalls

- **Gemma + q8_0 KV cache** = guaranteed context loop. Always use f16.
- **Ornith-1.0-35B without min-p = 0.0** = premature response termination at ~3 turns.
- **Ornith-1.0-35B with mmap** = tool-call hangs at high GPU utilization.
- **Jinja template `enable_thinking | default(false)`** = forces thought channel close, causing token repetition. Remove forced bypass for Copilot.
- **Context > training context without YaRN** = possible training context overflow.
- **MTP draft model missing** = speculative decoding fails silently.

## Example: Adding a New Model

Given: `unsloth/gemma-4-26B-A4B-it-qat-GGUF` (26B params, vision, MTP4)

1. **Research**: Check HF discussions for Gemma 4 parameter tuning
2. **Download**: `hf download unsloth/gemma-4-26B-A4B-it-qat-GGUF --local-dir unsloth/gemma-4-26B-A4B-it-qat-GGUF --include "**"`
3. **router.ini**:
   ```ini
   [Gemma-4-26B-A4B-it-qat-256K-Q8-MTP4-Vision]
   model = /models/unsloth/gemma-4-26B-A4B-it-qat-GGUF/gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf
   model-draft = /models/unsloth/gemma-4-26B-A4B-it-qat-GGUF/mtp-gemma-4-26B-A4B-it.gguf
   mmproj = /models/unsloth/gemma-4-26B-A4B-it-qat-GGUF/mmproj-BF16.gguf
   ctx-size = 262144
   cache-type-k = q8_0
   cache-type-v = q8_0
   cache-type-k-draft = q8_0
   cache-type-v-draft = q8_0
   spec-type = draft-mtp
   spec-draft-n-max = 4
   temp = 0.6
   top-k = 64
   image-min-tokens = -1
   ; 17.680Gi/24Gi
   ```
4. **chatLanguageModels.json**: Add matching entry with `maxInputTokens: 196608`, `maxOutputTokens: 65536`, `"vision": true`
5. **Restart**: `docker compose up -d`
