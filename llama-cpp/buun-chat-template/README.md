# Buun Chat Template

Download the chat template from Hugging Face:

```bash
huggingface-cli download spiritbuun/buun-Qwen3.6-chat_template chat_template.jinja --local-dir .
```

Or manually from: https://huggingface.co/spiritbuun/buun-Qwen3.6-chat_template

This directory is mounted read-only into the buun-llama-cpp container at `/app/buun-chat-template`.
