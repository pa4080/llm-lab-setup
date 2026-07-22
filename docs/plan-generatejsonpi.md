# Plan: Add pi.dev JSON config generation alongside VS Code Copilot

**TL;DR** Split generated configs into `confs/copilot/` and `confs/pi/` subdirectories. Add `generate-json-pi.sh` (pi.dev format) alongside `generate-json-copilot.sh`, rename `merge-json.sh` to `merge-json-copilot.sh`, add `merge-json-pi.sh`, wire both into `generate-config-json.sh`, and update all 3 `serve.sh` scripts.

---

## Pi.dev format summary (from pi.dev docs)

pi expects `~/.pi/agent/models.json` with this structure:

```json
{
  "providers": {
    "<provider_name>": {
      "baseUrl": "http://host:port/v1",
      "api": "openai-completions",
      "apiKey": "<key>",
      "models": [
        {
          "id": "<model_id>",
          "name": "<human_name>",
          "reasoning": true,
          "input": ["text"] | ["text", "image"],
          "contextWindow": 128000,
          "maxTokens": 32000,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    }
  }
}
```

**Key mapping from INI to pi model fields:**

| INI / parse_ini output                  | pi field        | Logic                                                        |
| --------------------------------------- | --------------- | ------------------------------------------------------------ |
| Section `[id]`                          | `id`            | Direct                                                       |
| Section `[id]`                          | `name`          | Same as `id`                                                 |
| `hasMmproj` (from `mmproj` key)         | `input`         | `["text", "image"]` if mmproj, else `["text"]`               |
| `ctxSize` (client-ctx-size or ctx-size) | `contextWindow` | Direct                                                       |
| `ctxSize / 4`                           | `maxTokens`     | Floor division by 4 (matching current maxOutputTokens logic) |
| —                                       | `reasoning`     | `true` for all (all models in this repo support thinking)    |
| —                                       | `cost`          | All zeros (local models)                                     |

**Provider name:** use `LOCAL_SERVER_NAME` from `.env` (same as VS Code config uses for `name`).

---

## Steps

### Phase 1: Create new scripts

**Step 1 — Create `generate-json-pi.sh`**
- Location: `/mnt/data/llm-lab/scripts/generate-json-pi.sh`
- Signature: `./generate-json-pi.sh <ini-file> [output-dir]` (same as `generate-json-copilot.sh`)
- Reuses the same `parse_ini` function pattern (copy from `generate-json-copilot.sh`) to extract `id`, `ctxSize`, `hasMmproj` per section
- Uses `env-helper.sh` for env var parsing (same pattern)
- Reads `LOCAL_URL`, `LOCAL_SERVER_NAME`, `LOCAL_API_KEY` from `.env`
- Outputs `<ini>.json` in output-dir with pi.dev format:
  ```json
  {
    "providers": {
      "<LOCAL_SERVER_NAME>": {
        "baseUrl": "<LOCAL_URL>",
        "api": "openai-completions",
        "apiKey": "<LOCAL_API_KEY>",
        "models": [ ... ]
      }
    }
  }
  ```
- Each model: `id`, `name`, `reasoning: true`, `input` (based on `hasMmproj`), `contextWindow`, `maxTokens`, `cost: { all 0 }`

**Step 2 — Create `merge-json-pi.sh`**
- Location: `/mnt/data/llm-lab/scripts/merge-json-pi.sh`
- Signature: `./merge-json-pi.sh [confs-dir]` (same as merge-json.sh)
- Reads all `*.json` from the confs directory
- Merges all `providers` objects into a single `{ "providers": { ... } }` file
- Outputs `0-pi-models.json` in the confs directory
- Uses `jq -s` to slurp and merge provider objects

### Phase 2: Refactor existing scripts

**Step 3 — Rename `merge-json.sh` to `merge-json-copilot.sh`**
- Rename `/mnt/data/llm-lab/scripts/merge-json.sh` to `/mnt/data/llm-lab/scripts/merge-json-copilot.sh`
- No internal changes needed — the script logic stays identical

**Step 4 — Update `generate-config-json.sh`**
- After `rm -rf "$CONFS_PARTS_DIR"` and `mkdir -p "$CONFS_PARTS_DIR"`, also create subdirectories:
  ```bash
  mkdir -p "$CONFS_PARTS_DIR/copilot"
  mkdir -p "$CONFS_PARTS_DIR/pi"
  ```
- Inside the `for` loop, after the `generate-json-copilot.sh` call, add:
  ```bash
  bash "$SCRIPT_DIR/generate-json-pi.sh" "$ini" "$CONFS_PARTS_DIR/pi"
  ```
- Replace the single merge call with two merge calls:
  ```bash
  bash "$SCRIPT_DIR/merge-json-copilot.sh" "$CONFS_PARTS_DIR/copilot"
  bash "$SCRIPT_DIR/merge-json-pi.sh" "$CONFS_PARTS_DIR/pi"
  ```

### Phase 3: Update serve.sh orchestrators

**Step 5 — Update `llama-cpp/serve.sh`**
- Change:
  ```bash
  cp "$LLAMA_CPP_DIR/confs/0-chatLanguageModels.json" "../confs/chatLanguageModels.json"
  ```
  To:
  ```bash
  cp "$LLAMA_CPP_DIR/confs/copilot/0-chatLanguageModels.json" "../confs/chatLanguageModels.json"
  ```
- Add after the public config block:
  ```bash
  cp "$LLAMA_CPP_DIR/confs/pi/0-pi-models.json" "../confs/pi-models.json"
  ```

**Step 6 — Update `llama-cpp-buun/serve.sh`**
- Same changes as Step 5

**Step 7 — Update `llama-cpp-prism/serve.sh`**
- Same changes as Step 5

### Phase 4: Documentation

**Step 8 — Update `llama-cpp/README.md`**
- Update the Scripts table:
  - Change `merge-json.sh` to `merge-json-copilot.sh`
  - Add `generate-json-pi.sh` row
  - Add `merge-json-pi.sh` row
- Update usage examples to reflect new structure

---

## Relevant files

| File                                                 | Action                                                                   |
| ---------------------------------------------------- | ------------------------------------------------------------------------ |
| `/mnt/data/llm-lab/scripts/generate-config-json.sh`  | **Modify** — add vscode/pi subdirs, call pi generator, rename merge call |
| `/mnt/data/llm-lab/scripts/merge-json.sh`            | **Rename** to `merge-json-copilot.sh`                                    |
| `/mnt/data/llm-lab/scripts/generate-json-copilot.sh` | **No change** — reference for `parse_ini` pattern                        |
| `/mnt/data/llm-lab/scripts/env-helper.sh`            | **Reference** — reuse `get_env` pattern                                  |
| `/mnt/data/llm-lab/scripts/generate-json-pi.sh`      | **Create** — pi.dev JSON generator                                       |
| `/mnt/data/llm-lab/scripts/merge-json-pi.sh`         | **Create** — pi.dev JSON merger                                          |
| `/mnt/data/llm-lab/scripts/merge-json-copilot.sh`    | **Create** (via rename from `merge-json.sh`)                             |
| `/mnt/data/llm-lab/llama-cpp/serve.sh`               | **Modify** — update copy paths, add pi copy                              |
| `/mnt/data/llm-lab/llama-cpp-buun/serve.sh`          | **Modify** — update copy paths, add pi copy                              |
| `/mnt/data/llm-lab/llama-cpp-prism/serve.sh`         | **Modify** — update copy paths, add pi copy                              |
| `/mnt/data/llm-lab/llama-cpp/README.md`              | **Modify** — update scripts table and examples                           |

---

## Directory structure after changes

```
llama-cpp/confs/
  vscode/
    1-Qwen3.6-27B-AutoRound.json    (individual per-INI)
    1-Qwen3.6-35B-A3B.json
    0-chatLanguageModels.json       (merged)
  pi/
    1-Qwen3.6-27B-AutoRound.json    (individual per-INI)
    1-Qwen3.6-35B-A3B.json
    0-pi-models.json                (merged)
```

---

## Verification

1. Run `bash scripts/generate-config-json.sh ./llama-cpp-prism/router ./llama-cpp-prism/confs` and verify:
   - `confs/copilot/` contains individual JSONs + `0-chatLanguageModels.json`
   - `confs/pi/` contains individual JSONs + `0-pi-models.json`
   - `0-pi-models.json` has valid `{ "providers": { ... } }` structure
   - Each model has `id`, `name`, `reasoning`, `input`, `contextWindow`, `maxTokens`, `cost`
2. Validate `0-pi-models.json` with `jq .` — should parse without errors
3. Verify `input` field is `["text", "image"]` for models with mmproj, `["text"]` for text-only
4. Run `llama-cpp-prism/serve.sh` (dry-run or actual) and verify:
   - `../confs/chatLanguageModels.json` is correctly copied from `confs/copilot/`
   - `../confs/pi-models.json` exists and is valid
5. Check `../confs/chatLanguageModels.json` still has correct structure (array of objects with `models` array)

---

## Decisions

- **Provider name**: `LOCAL_SERVER_NAME` from `.env` — keeps naming consistent with VS Code config
- **`reasoning: true` for all models** — all models in this repo support thinking (chat-template-kwargs preserve_thinking or similar); can be refined per-model later if needed
- **`maxTokens = ctxSize / 4`** — matches the existing `maxOutputTokens` logic in the VS Code generator
- **`cost: { all zeros }`** — local models, no cost
- **`api: "openai-completions"`** — llama.cpp serves OpenAI-compatible endpoint
- **Subdirectory naming**: `vscode/` and `pi/` — clear, matches consumer name
- **Output file names**: `0-pi-models.json` (merged), `<ini>.json` (individual) — mirrors VS Code naming convention

## Further Considerations

1. **Reasoning detection**: Currently setting `reasoning: true` for all. Could add INI parsing to detect `chat-template-kwargs` containing `preserve_thinking` or `enable_thinking` for per-model accuracy. **Recommendation**: keep `true` for now, refine later if a non-reasoning model is added.
2. **Public pi config**: Should we generate a public pi config (like `chatLanguageModels.public.json`)? **Recommendation**: exclude for now — pi configs are typically local (`~/.pi/agent/models.json`); add later if needed.
3. **Shared `parse_ini`**: Both `generate-json-copilot.sh` and `generate-json-pi.sh` will have copy-pasted `parse_ini` functions. **Recommendation**: accept duplication for now; extract to a shared library only if a 3rd consumer emerges.
