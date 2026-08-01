# TODO

## Tasks

### Reasoning fine tune

- [ ] The decisions from the pi-plan:
  - Reasoning detection: Currently setting reasoning: true for all. Could add INI parsing to detect chat-template-kwargs containing preserve_thinking or enable_thinking for per-model accuracy. Recommendation: keep true for now, refine later if a non-reasoning model is added.
- [ ] Let's introduce a fake commented out property in the ini - i.e. `; has-reasoning  = true|false` that will tell does the model have reasoning capabilities to the client configuration
- [ ] This property will be used in the `generate-json-pi.sh` as well as `generate-json-vscode.sh` scripts to set the `reasoning` field in the pi.dev model config, and the corresponding field in the VSCode model config.
- [ ] If the property is not present, we will default to `true` for all models (as they all support reasoning).
- [ ] Finally make a section in the README.md (root of the project), where all these custom 'hacks' are explained - i.e. the `has-reasoning` property, `dummy-ctx-size`, `client-ctx-size`, etc.

### Cost

- [ ] models.json have a property called `cost`, we should research does there is an analogical property in VSCode Copilot model config, and if so, we can introduce a new property in the ini files, i.e. `; cost = { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }` that will be used in the `generate-json-pi.sh` script to set the `cost` field in the pi.dev model config. Despite we running the models locally it cost us the electricity and the hardware.

### Systemd services

- [ ] Create systemd service for each of the llama-cpp, llama-cpp-buun, and llama-cpp-prism projects. The service will run the `serve.sh` script in the background, and will be configured to restart on failure. The service will also be configured to start on boot.

- [ ] Create a script that downloads the latest version to the bin/ folders:
  - [ ]  <https://github.com/ggml-org/llama.cpp/releases>

## Research

- [ ] Reasoning llama.cpp documentation and VSCode and decide does these properties we put in `chatLanguageModels.json` actually make sense. Primary I mean these properties: `reasoning`, `supportsReasoningEffort`, and `zeroDataRetentionEnabled`.

    ```json
    {
    "thinking": true,
    "supportsReasoningEffort": [
      "low",
      "medium",
      "high"
    ],
    "zeroDataRetentionEnabled": false,
    }
    ```

  Refs.:
  - <https://github.com/ggml-org/llama.cpp>
  - <https://llama-cpp.com/>
  - <https://code.visualstudio.com/docs/agent-customization/language-models>
