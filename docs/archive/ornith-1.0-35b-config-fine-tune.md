# Ornith-1.0-35B Configuration Fine-Tune

**Date:** 2026-06-28
**Source:** HF Discussions on `deepreinforce-ai/Ornith-1.0-35B-GGUF`

## Issues Identified

| #   | Issue                                                             | Source                                                                                       |
| --- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| 1   | Infinite tool-call loops                                          | [Discussion #13](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B-GGUF/discussions/13) |
| 2   | Premature response termination (truncated at ~3 turns)            | [Discussion #10](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B-GGUF/discussions/10) |
| 3   | Agentic coding failures — tool calls hang at high GPU utilization | [Discussion #9](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B-GGUF/discussions/9)   |
| 4   | Jinja chat-template errors; context >100K breaks tool calls       | [Discussion #6](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B-GGUF/discussions/6)   |

## Changes Applied to `router.ini`

All Ornith-1.0-35B entries (base, MTP2 Compact, MTP2 Vision, Quality variants) were updated with:

| Parameter              | Value                        | Rationale                                        |
| ---------------------- | ---------------------------- | ------------------------------------------------ |
| `min-p`                | `0.0`                        | Community consensus; prevents early termination  |
| `repeat-penalty`       | `1.0`                        | Community consensus; prevents repetition loop    |
| `no-mmap`              | `true`                       | Stability fix for tool-call hangs (Disc #9, #13) |
| `chat-template-kwargs` | `{"preserve_thinking":true}` | Fixes infinite loops (Disc #13, #9)              |
| `presence-penalty`     | removed                      | No community recommendation for `1.5` value      |

### Entries Updated (13 total)

- `Ornith-1.0-35B-Q4-256K`
- `Ornith-1.0-35B-Q4-256K-temp-1`
- `Ornith-1.0-35B-Q8-256K`
- `Ornith-1.0-35B-MTP2-Compact-262K-Q4`
- `Ornith-1.0-35B-MTP2-Vision-Compact-262K-Q4`
- `Ornith-1.0-35B-MTP2-Vision-Compact-262K-Q8`
- `Ornith-1.0-35B-MTP-Compact-262K-Q8`
- `Ornith-1.0-35B-Vision-Compact-262K-Q8`
- `Ornith-1.0-35B-MTP2-Quality-128K-Q4`
- `Ornith-1.0-35B-MTP2-Vision-Quality-128K-Q4`
- `Ornith-1.0-35B-MTP2-Vision-Quality-128K-Q8`
- `Ornith-1.0-35B-MTP-Quality-128K-Q8`
- `Ornith-1.0-35B-Vision-Quality-128K-Q8`

### Not Applied (deferred)

| Flag             | Reason                                                                                     |
| ---------------- | ------------------------------------------------------------------------------------------ |
| `reasoning = on` | Conflicting recommendations — some users enable, others disable for agent setups           |
| `jinja = true`   | Might help chat template issues but could trigger Jinja errors if template is incompatible |

## Parameter Reference

### `min-p = 0.0`

Sets minimum-p sampling threshold to zero, effectively disabling min-p filtering.

**Why:** Discussion #10 reports that Ornith-1.0-35B terminates responses prematurely (truncated at ~3 tool-call turns) when min-p is left at the default `0.05`. Setting `min-p = 0.0` disables this filter entirely, allowing the model to continue generating through multi-turn agentic workflows without early stop.

**Source:** [Discussion #10](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B-GGUF/discussions/10) — `--presence-penalty 0.0 --repeat-penalty 1.0 --temp 0.6` was cited as the fix for premature termination.

---

### `repeat-penalty = 1.0`

Sets repeat-penalty to the neutral/default value of 1.0 (no penalty applied).

**Why:** Discussion #10 confirms that `repeat-penalty = 1.0` is part of the recommended working configuration. The previous entries used `presence-penalty = 1.5`, which is too aggressive and contributes to premature termination. Setting repeat-penalty to 1.0 (neutral) avoids penalizing repeated tokens while not introducing additional termination pressure.

**Source:** [Discussion #10](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B-GGUF/discussions/10) — `--repeat-penalty 1.0` explicitly listed in working config.

---

### `no-mmap = true`

Disables memory-mapped model loading.

**Why:** Discussions #9 and #13 report that memory-mapping causes tool-call hangs at high GPU utilization. Discussion #9 specifically notes that agentic coding tasks fail and hang when `mmap` is enabled. Discussion #13 confirms that `--no-mmap` helps resolve infinite tool-call loops. Disabling mmap trades slower load time for runtime stability during multi-turn agent sessions.

**Source:** [Discussion #9](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B-GGUF/discussions/9) — `--no-mmap` recommended for agentic stability. [Discussion #13](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B-GGUF/discussions/13) — `--no-mmap` helps with infinite loop resolution.

---

### `chat-template-kwargs = {"preserve_thinking":true}`

Passes `preserve_thinking: true` to the Jinja chat-template parser.

**Why:** Discussion #13 identifies this as the key fix for infinite tool-call loops. When `preserve_thinking` is enabled, the template parser preserves the model's thinking/reasoning tokens in the output rather than stripping them, preventing the parser from entering a loop where it keeps re-requesting tool calls. Discussion #9 also recommends this for agentic coding tasks.

**Source:** [Discussion #13](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B-GGUF/discussions/13) — `--chat-template-kwargs '{"preserve_thinking":true}'` fixes infinite loops. [Discussion #9](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B-GGUF/discussions/9) — recommended for agentic coding.

---

### `presence-penalty` — removed

**Why:** No community discussion recommends `presence-penalty = 1.5` for Ornith-1.0-35B. Discussion #10 explicitly sets `--presence-penalty 0.0` in the working config. The `1.5` value was overly aggressive and likely contributed to premature response termination (Discussion #10 symptom). Removing it eliminates an unnecessary termination pressure.

**Source:** [Discussion #10](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B-GGUF/discussions/10) — working config uses `--presence-penalty 0.0`.

## Verification Checklist

- [ ] Test each entry with multi-turn tool-call tasks
- [ ] Monitor for infinite loops (Disc #13 symptom)
- [ ] Check responses complete beyond 3 turns (Disc #10 symptom)
- [ ] Verify tool calls don't hang at high GPU utilization (Disc #9 symptom)
- [ ] Test context >100K for tool-call reliability (Disc #6 symptom)

## Fallbacks

- If Jinja errors persist: use `froggeric/Qwen-Fixed-Chat-Templates` alternative template
- If `reasoning = on` becomes necessary: add it to entries that benefit (e.g., MTP2 Compact)
- If `reasoning = on` needed later: add it to entries that benefit (e.g., MTP2 Compact)
