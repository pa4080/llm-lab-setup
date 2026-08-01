# llama.cpp Checkpoint Cache Invalidation — PR #22929 Analysis

**Source:** [ggml-org/llama.cpp#22929](https://github.com/ggml-org/llama.cpp/pull/22929) — *server: fix checkpoints creation* (Merged May 25)

---

## Quick-Start: Params to Test

### Reference Example Command

From [Mykola Aleksandrov's blog](https://www.mykolaaleksandrov.dev/posts/2026/06/claude-code-llamacpp-prompt-cache-fix/) — a working configuration for Claude Code with Qwen3.6-27B:

```bash
..\bin\llama-server.exe ^
  -m ..\models\Qwen3.6-27B-UD-Q4_K_XL.gguf ^
  --host 0.0.0.0 ^
  --port 8080 ^
  -c 170000 ^
  -ngl 99 ^
  -t 8 ^
  -b 512 ^
  --flash-attn on ^
  -np 1 ^
  -ctk q4_0 ^
  -ctv q4_0 ^
  --spec-type draft-mtp ^
  --spec-draft-n-max 2 ^
  --temp 0.6 ^
  --top-p 0.95 ^
  --top-k 20 ^
  --min-p 0 ^
  --jinja ^
  --reasoning-format deepseek ^
  -n 50000 ^
  --reasoning-budget 8192 ^
  --cache-ram 15000 ^
  --ctx-checkpoints 128 ^
  --checkpoint-min-step 128
```

### Parameter Reference Table

| Parameter                | Value                          | Why                                                                                         |
| ------------------------ | ------------------------------ | ------------------------------------------------------------------------------------------- |
| `-m`                     | `Qwen3.6-27B-UD-Q4_K_XL.gguf`  | Model — Qwen3.6-27B with AutoRound quantization (Q4_K_XL).                                  |
| `--host`                 | `0.0.0.0`                      | Binds to all interfaces for network access.                                                 |
| `--port`                 | `8080`                         | HTTP port for the server.                                                                   |
| `-c` (context-size)      | `170000`–`200000`              | Context size in tokens — aligns with checkpoint strategy; too small = premature eviction.   |
| `-ngl` (n-gpu-layers)    | `99`                           | GPU layers — offloads all layers to GPU.                                                    |
| `-t` (threads)           | `8`                            | CPU threads for batch/prompt processing.                                                    |
| `-b` (batch-size)        | `512`–`8192`                   | Larger batch = faster prompt processing, less timeout risk.                                 |
| `--flash-attn`           | `on`                           | Enables Flash Attention for efficient large-context computation.                            |
| `-np` (parallel)         | `1`                            | Prevents parallel conversations from slowing prompt processing and missing turn boundaries. |
| `-ctk` (cache-type-k)    | `q4_0`                         | KV cache K quantization — saves VRAM.                                                       |
| `-ctv` (cache-type-v)    | `q4_0`                         | KV cache V quantization — saves VRAM.                                                       |
| `--cache-ram`            | `15000` (or higher)            | Reserves more RAM for prompt cache. Default 8GB often insufficient for long sessions.       |
| `--ctx-checkpoints`      | `128`                          | More checkpoints = better granularity for cache reuse. Default 32 is too sparse.            |
| `--checkpoint-min-step`  | `128`                          | Creates checkpoints every 128 tokens instead of 8192. Far more cache reuse opportunities.   |
| `--cache-reuse`          | `256`–`1024`                   | Partial cache reuse threshold. Higher = more aggressive reuse.                              |
| `--spec-type`            | `draft-mtp`                    | Speculative decoding — Mixture of Tokens Prediction for draft generation.                   |
| `--spec-draft-n-max`     | `2`                            | Max draft tokens per speculative step.                                                      |
| `--temp`                 | `0.6`                          | Lower temperature for more focused/deterministic output.                                    |
| `--top-p`                | `0.95`                         | Top-p nucleus sampling — limits token selection.                                            |
| `--top-k`                | `20`                           | Top-k sampling — limits to 20 most probable tokens.                                         |
| `--min-p`                | `0`                            | Min-p sampling disabled — lets top-p=0.95 work fully.                                       |
| `--jinja`                | *(flag)*                       | Required for proper chat-template parsing and `message_spans` extraction.                   |
| `--chat-template-kwargs` | `'{"preserve_thinking":true}'` | Prevents thinking tags from changing between turns → stabilizes prompt prefix.              |
| `--reasoning-format`     | `deepseek`                     | Extracts `<think>` tags into `message.reasoning_content`.                                   |
| `--reasoning-budget`     | `8192`                         | Token budget for thinking — caps internal reasoning.                                        |
| `-n` (n-predict)         | `50000`                        | Max output tokens — limits generation.                                                      |
| `--keep`                 | `4096`                         | Preserves last N tokens in KV cache, reducing re-processing on idle→active transitions.     |
| `--swa-checkpoints`      | `0`                            | Disable SWA checkpoints for Qwen models with Gated DeltaNet.                                |
| `-no-kvu`                | *(flag)*                       | Disable K/V unified for Gemma 3/4 models (improves cache stability).                        |
| `--no-context-shift`     | *(flag)*                       | Correct for cache stability — manual conversation drop at context limit.                    |

### Hidden Prompt Cache Killer

The `CLAUDE_CODE_ATTRIBUTION_HEADER` environment variable is the **hidden prompt cache killer**. When set to `"0"`, it stops Claude Code from prepending a changing attribution block to the system prompt. This stabilizes the token prefix, allowing llama.cpp to reuse context checkpoints instead of full prompt re-processing.

Without this fix, even with high `--cache-ram` and `--ctx-checkpoints`, the cache would be invalidated every time Claude Code's attribution block changed.

---

## Discussion 1: PR Author — Original Fix & Testing

**Contributor:** [@jacekpoplawski](https://github.com/jacekpoplawski)
**Date:** May 11–16, 2026

### What Changed

The PR rewrote checkpoint creation logic:

- **Before:** Periodic checkpoints every N tokens throughout the prompt.
- **After:** Checkpoints are created at **user message boundaries** (extracted from `message_spans` in chat templates). Mid-prompt periodic checkpoints are skipped when the boundary position is known.

### Key Insight

The goal was to fix `forcing full prompt re-processing due to lack of cache data` — the most common cause of cache invalidation.

### Testing Results

- **Qwen3.6-27B, 200K ctx, 24 checkpoints:** Works stable for hours without `forcing full prompt re-processing`.
- **With 8 checkpoints:** Reproduced the issue — cache misses returned.
- **Multimodal:** Initially broke after the first image. Fixed with fallback to old mechanism and iterating over full token sequence skipping `LLAMA_TOKEN_NULL`.

### Proposed Flags (Not Yet Merged)

- `--min_checkpoint_tokens` — to control minimum checkpoint token count.
- Flag to enable/disable the `message_spans` mechanism entirely.

### Quote from Author

> "I understand that the impact of this change is significant, but the benefits are also significant: agentic coding is much more responsive now."

---

## Discussion 2: corrm — Validation & Edge Case Discovery

**Contributor:** [@corrm](https://github.com/corrm)
**Date:** May 13, 2026

### What They Found

Tested with Qwen3.6-27B UD-Q4_K_XL on RTX 3090:

```bash
-c 136000 --n-gpu-layers 64 --threads 9 --parallel 1 --flash-attn on
--cache-type-k q8_0 --cache-type-v q8_0 --temp 0.6 --top-k 20 --top-p 0.95
--repeat-penalty 1 --presence-penalty 0 --no-webui --mlock --context-shift
```

### Results

- `forcing full prompt re-processing` **never shows up** in logs.
- Almost all requests get a cache hit.
- **One unreproducible cache miss** occurred.

### Edge Case Discovered

Cache miss happens when **"all slots are idle"** — a single idle-then-active transition can invalidate checkpoints if the prompt structure shifted.

### Verdict

> "Great work! You saved my time and my electricity bill."

---

## Discussion 3: pwilkin — Autoparser Limitation

**Contributor:** [@pwilkin](https://github.com/pwilkin) (Member)
**Date:** May 11, 2026

### Issue

The PR assumes all autoparser models use ChatML markers (`</think>` etc.), which is **incorrect** for non-ChatML templates.

### Proposed Fix

Dedicated support for split-marker detection in the autoparser.

### Status

> "I'll try to submit the marker detection code ASAP."

---

## Discussion 4: Arii02 — Still Getting Cache Misses on Mac

**Contributor:** [@Arii02](https://github.com/Arii02)
**Date:** May 15–16, 2026

### Problem

Using Pi or OpenCode, still getting `forcing full prompt re-processing due to lack of cache data` on Mac.

### Author's Response

- Tested for many hours with Qwen3.6 27B — `forcing full` only appeared at the **beginning** (no cache yet) or during **long tasks with 30+ reads/edits**.
- Asked for logs and model details.

### User's Model

Qwen3.5 122B — too large for Mac's memory, likely causing different behavior.

---

## Discussion 5: ggerganov — Core Design Decision

**Contributor:** [@ggerganov](https://github.com/ggerganov) (Member)
**Date:** May 16, 2026

### Question

> "Is the `message_spans` argument needed? I think if the approach works correctly, it would never be better to disable it, so we can keep it always on."

### Implication

The team considers the new mechanism universally superior — no toggle needed.

---

## Discussion 6: ashirviskas — Regression After Merge (Critical)

**Contributor:** [@ashirviskas](https://github.com/ashirviskas)
**Date:** May 28, 2026

### Problem

After the PR merged (b9105 → b9396), cache numbers **dropped significantly** for Qwen3.6-35B-A3B.

### Root Cause

The new logic creates checkpoints **only near the end** of the prompt at user message boundaries. For prompts with:
- A **stable prefix** (system prompt, conversation history)
- A **dynamic tail** (changing data per request)

All checkpoints are in the dynamic region → **every checkpoint is invalidated on every turn**.

### User's Scenario

RAG with depth=4 — information included in each message changes between turns.

### Suggested Fix

> "One solution would be to set the number of user checkpoints so that you can simply save the last 5 or so."

### Verdict

> "As it stands now, Llama Server only creates two checkpoints, and those are always discarded."

---

## Discussion 7: wollastonzhu — Deep Dive & Workaround

**Contributor:** [@wollastonzhu](https://github.com/wollastonzhu)
**Date:** May 29–June 18, 2026

### Strategy Adopted

1. **Frontend:** OpenClaw
2. **Context window:** Reduced to 2/3 of previous size to reduce prompt processing load.
3. **`--parallel 1`:** Prevents parallel conversations from slowing prompt processing and missing turn boundaries.
4. **`--cache-reuse 1024`:** Added for better cache reuse.

### Key Observation

> "The potential negative impacts of this functional change are still gradually coming to light."

### Long-Term Concern

> "Could we please revert to the original, more mechanical KV cache method as soon as possible? In the future, the special optimization functions should be implemented as separate branches for different scenarios."

### Final Verdict (June 16)

After extensive investigation, concluded:
> "Given that reverting is no longer feasible, provided the GPU performance is sufficient, the mainline logic works quite well."

---

## Discussion 8: vikaskumarsingh123 — Large Model Impact

**Contributor:** [@vikaskumarsingh123](https://github.com/vikaskumarsingh123)
**Date:** June 2, 2026

### Problem

Huge negative impact on **big models** (Qwen3.5 122B, Qwen3.5 397B) for codebase refactoring.

### Evidence

- Previously could process large prompts with Zoo Code.
- Now falls short by a few thousand tokens.
- Even Qwen3.5 397B at 4 t/s TG can't process the initial prompt anymore.

### Request

> "I strongly second bringing back the `--checkpoint-every-n-tokens` CLI flag."

---

## Discussion 9: ElDavoo — System Prompt Mutation

**Contributor:** [@ElDavoo](https://github.com/ElDavoo)
**Date:** June 20, 2026

### Problem

Using OpenClaw + Qwen3.6 — constantly gets `forcing full prompt re-processing` during agentic work.

### Root Cause

The PR changes checkpoints to be **message boundary-based**. When API consumers (like OpenClaw) **change the system prompt** that's supposed to be static, the whole cache is trashed.

### Workaround

> "I have to pin to b9294 now." (pre-merge baseline)

---

## Discussion 10: GianniDPC — Debugging with Log Prompts

**Contributor:** [@GianniDPC](https://github.com/GianniDPC)
**Date:** June 11, 2026

### Setup

```bash
-m Qwen3.6-27B-IQ4_NL.gguf
-c 131072 --parallel 1 --batch-size 1024 --ubatch-size 512
--n-gpu-layers 99 --threads 6 --threads-batch 12
--jinja --cont-batching --temp 0.6 --top-p 0.95 --top-k 20
--reasoning-budget 8192 --reasoning on
--spec-type draft-mtp --spec-draft-n-max 2
```

### Author's Debug Tip

> "Please run llama-server with `-log-prompts-dir` argument, try to reproduce the issue, then look at two latest files in the directory. By comparing them you can see the source of the problem (probably opencode changed something in the middle of the old prompt)."

---

## Summary Table: Cache Invalidation Causes

| Cause                                   | Impact                                                  | Mitigation                                       |
| --------------------------------------- | ------------------------------------------------------- | ------------------------------------------------ |
| Changing system prompt between turns    | **High** — invalidates all checkpoints                  | Use `preserve_thinking`, stabilize prompt prefix |
| Long agentic tasks (30+ reads/edits)    | **Medium** — exceeds checkpoint granularity             | Increase `--ctx-checkpoints` to 128+             |
| All slots idle → active transition      | **Low** — single miss, then recovers                    | Use `--keep 4096` to preserve tail               |
| Multimodal prompts                      | **Medium** — breaks image boundary detection            | Use latest build with multimodal fix             |
| API consumers mutating middle of prompt | **High** — checkpoint at boundary becomes invalid       | Use `-log-prompts-dir` to diagnose               |
| RAG data changing per turn              | **High** — dynamic tail invalidates all checkpoints     | Pin to pre-merge or increase checkpoints         |
| Large models on limited RAM             | **High** — can't hold enough checkpoints                | Reduce context size, increase `--cache-ram`      |
| Parallel conversations                  | **Medium** — slows prompt processing, misses boundaries | Use `--parallel 1`                               |

---

## Discussion 11: Reddit r/LocalLLaMA — Community Debugging

**Source:** [Reddit: llama.cpp constantly reprocessing huge prompts](https://www.reddit.com/r/LocalLLaMA/comments/1td9stc/llamacpp_constantly_reprocessing_huge_prompts/)
**Date:** May 14, 2026

### Problem Statement

User running llama-swap + llama.cpp with OpenCode + pi.dev observing:
- Context grows to 50k+ tokens
- LCP similarity often shows 0.99+
- But `n_past` suddenly falls back to ~4-5k
- Then llama.cpp reprocesses 40k+ tokens again
- TTFT jumps to multiple minutes

### Key Findings

#### 1. Cache RAM Exhaustion

**Symptom:**
```
cache state: 1 prompts, 4676 MiB
(limits: 2500 MiB)
```

**Diagnosis:** Cache is sitting at almost double its allocated budget. llama.cpp is churning through evictions trying to stay under the limit. The system found a near-perfect prefix match, but the bigger checkpoints had already been evicted to free up room.

**Solution:**
> "The first thing I'd try is just bumping `--cache-ram` way up. 2500 MiB is fine for short chat but you're running 150k context with coding agents that produce huge prefixes, and you've got ctx-checkpoints set to 32 on top of that. There's no way 2.5 gigs is enough headroom. Try 16000 or higher if your RAM allows. That alone should stop the eviction churn you're seeing."

#### 2. Opencode Prunes Tool Call Outputs

**Issue:** Opencode prunes tool call outputs which invalidate cache for models that use **Gated DeltaNet (Recurrent Memory)**. Forces full prompt reprocessing.

**Impact:** Long tool call outputs and/or multiple chained tool calls fill up context to the point where on the next user turn, LCP similarity calculation drops below 0.500 and forces prompt-reprocessing.

#### 3. SWA (Sliding Window Attention) Cache Issues

**Problem:** Qwen models have sliding window attention whose cache cannot be recovered by llama.cpp.

**Solution:**
```bash
--swa-checkpoints 0
```

Or alternatively:
```bash
--ctx-checkpoints 0
```

This turns off SWA checkpoints entirely, preventing the cache invalidation from SWA layers.

#### 4. Prompt Mutation Detection

**Technique:** Use llama-swap's web UI to inspect prompts between turns:
1. Navigate to the same address as the API (without `/v1`)
2. Click **Activity** tab (upper right)
3. View last requests with token counts
4. Save two requests to a file and diff them

**Finding:** Kilo Code was changing the previous user message to not include the environment, forcing reprocessing of what comes after.

#### 5. Pi vs Opencode Behavior

- **Pi:** Doesn't rewrite history (core value), better cache stability
- **Opencode:** Modifies tool call outputs, more aggressive pruning

#### 6. Thinking Token Preservation

**Qwen 3.5:** Template did not preserve thinking tokens, causing cache to invalidate
**Qwen 3.6:** Fixed with `preserve_thinking` parameter — thinking tokens are saved in cache AND preserved when the next prompt hits

**Earlier solution:** GLM introduced `clear_thinking` chat template kwargs (since v4.7)

#### 7. Prompt Ordering Best Practice

> "Put immutable stuff at the very top (system instructions, tool definitions, persona) and volatile stuff at the end of the prompt, ideally inside the latest user turn."

**Example:** Moving dynamic sensor readings from system block to current user turn dropped cached TTFT from multiple seconds to ~200ms.

#### 8. Additional Tuning Tips

- **`--cache-reuse 256`** is reasonable, can push to 512 or 1024 for more aggressive partial reuse
- **`-no-kvu`** — disable K/V unified for Gemma 3/4 models (costs some KV efficiency but improves cache stability)
- **`--no-context-shift`** — correct for cache stability, but means manual conversation drop at context limit
- **`--ctx-checkpoints 8`** vs `16` — higher values reduce cache misses but use more RAM

### Verdict from Community

> "Yeah, Qwen3.5 122B at that context is going to be brutal no matter what you do. 4 extra gigs will probably help the eviction churn but you're right it's a band-aid. Agreed on the llama.cpp side, prompt caching has gotten better release-to-release but coding agents push it harder than chat workflows and it shows."

---

## Recommendations for Our Setup

Based on this analysis (PR #22929 + community discussions), for **stable agentic coding** with llama.cpp:

1. **`--ctx-checkpoints 128`** or higher — more checkpoints = more cache reuse opportunities
2. **`--checkpoint-min-step 128`** — finer granularity than default 8192
3. **`--cache-ram 15000`** or higher — more RAM for cache (critical for 50k+ token contexts)
4. **`--chat-template-kwargs '{"preserve_thinking":true}'`** — stabilizes thinking tags
5. **`--parallel 1`** — prevents parallel conversation interference
6. **`--keep 4096`** — preserves tail tokens across idle transitions
7. **`-b 8192`** — larger batch for faster processing, less timeout risk
8. **`--jinja`** — required for proper `message_spans` extraction
9. **`--swa-checkpoints 0`** — disable SWA checkpoints if using Qwen models with Gated DeltaNet
10. **Prompt ordering** — stable prefix at top, volatile data at end (inside latest user turn)
11. **`CLAUDE_CODE_ATTRIBUTION_HEADER=0`** — disable attribution block to prevent prefix mutation

## Source

- **PR:** [ggml-org/llama.cpp#22929](https://github.com/ggml-org/llama.cpp/pull/22929) — *server: fix checkpoints creation* (Merged May 25)
- **Blog:** [Claude Code llama.cpp Prompt Cache Fix](https://www.mykolaaleksandrov.dev/posts/2026/06/claude-code-llamacpp-prompt-cache-fix/) by Mykola Aleksandrov (June 2026)
- **Reddit:** [r/LocalLLaMA: llama.cpp constantly reprocessing huge prompts](https://www.reddit.com/r/LocalLLaMA/comments/1td9stc/llamacpp_constantly_reprocessing_huge_prompts/) (May 14, 2026)
