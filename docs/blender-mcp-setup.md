# Blender MCP — Connecting Blender 5.2 to VS Code (Copilot)

How to connect a running Blender instance to VS Code's Copilot chat via the
**official Blender Lab MCP server**, so the LLM can inspect scenes, execute
Python in Blender, take screenshots, and render.

> Verified working: 2026-08-18, Blender 5.2.0, VS Code on Ubuntu.
>
> References:s
>
> - Official docs: <https://www.blender.org/lab/mcp-server/>
> - Source: <https://projects.blender.org/lab/blender_mcp>
> - Demo video: <https://www.youtube.com/watch?v=sIlu2cxISII>

## Architecture

Three components; all must be running:

```txt
┌──────────────┐   stdio    ┌─────────────────────┐  TCP :9876  ┌──────────────────────┐
│  VS Code      │◄─────────►│  blender-mcp server   │◄──────────►│  Blender + MCP add-on  │
│  (Copilot)    │            │  (blmcp, from repo)   │  (null-byte │  (bridge socket)       │
└──────────────┘            └─────────────────────┘   JSON)     └──────────────────────┘
```

| Component      | What it is                                                                                                                                                                          | Where it lives                                                       |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| **Add-on**     | Socket bridge inside Blender (listens on `localhost:9876`, null-byte-delimited JSON)                                                                                                | Blender 5.1+, official *Blender Lab* extension `lab_blender_org/mcp` |
| **MCP server** | stdio MCP server exposing tools (`execute_blender_code`, `get_objects_summary`, `get_screenshot_of_window_as_image`, `render_viewport_to_path`, …); forwards requests to the add-on | `mcp/` subdirectory of the `blender_mcp` repo (package `blmcp`)      |
| **Client**     | VS Code Copilot, configured via `mcp.json`                                                                                                                                          | `~/.config/Code/User/mcp.json`                                       |

### ⚠️ Don't confuse the two "blender-mcp" projects

|                 | **Official (Blender Lab)**                     | **Community (ahujasid)**                                |
| --------------- | ---------------------------------------------- | ------------------------------------------------------- |
| Repo            | <https://projects.blender.org/lab/blender_mcp> | <https://github.com/ahujasid/blender-mcp>               |
| PyPI            | **not published**                              | `blender-mcp` (this is what `uvx blender-mcp` installs) |
| Socket protocol | null-byte (`\0`) delimited JSON                | newline-delimited JSON                                  |
| Add-on          | official Blender 5.1+ extension                | `addon.py` for Blender 3.0+                             |

Mixing them (e.g. community server + official add-on) fails with
`Communication error with Blender: Incomplete JSON response received`.
This setup uses the **official** stack end to end.

## Prerequisites

- Blender **5.1 or newer** (tested with 5.2.0), running with a GUI.
- Python 3.10+ (uv manages its own interpreter, so nothing to install).
- `uv` / `uvx` package manager.
- VS Code with Copilot.

## Step 1 — Install `uv`

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# installs to ~/.local/bin/{uv,uvx}
which uvx   # → /home/<you>/.local/bin/uvx
```

> **Why the absolute path matters later:** VS Code launched from the GUI does
> not inherit your shell's `PATH`, so a bare `"command": "uvx"` in `mcp.json`
> fails with `spawn uvx ENOENT`. Always use the full path from `which uvx`.

## Step 2 — Clone the official repo

```bash
git clone https://projects.blender.org/lab/blender_mcp
# → /mnt/data/git/blender_mcp   (keep it where it stays; mcp.json points at it)
```

Repo layout:

```
blender_mcp/
├── addon/      # the Blender add-on source (only needed if building from source)
├── mcp/        # ← the MCP server (package blmcp, entry point "blender-mcp")
├── chat_client/  # optional: text-mode client for llama.cpp setups
└── tests/
```

## Step 3 — Install & enable the add-on in Blender

1. **Add the Blender Lab extensions repository** (one-time):
   Edit → Preferences → *Get Extensions* → ⚙ (top right) → *Install from URL…* →
   `https://lab.blender.org/`
2. In *Get Extensions*, search **MCP** → **Install** (extension `mcp`,
   maintainer *Blender Lab*, requires Blender ≥ 5.1).
3. **Enable** it (checkbox).
4. In its Preferences panel verify:
   - **Host** `localhost`, **Port** `9876` (defaults are fine)
   - **Auto Start** checked (server comes up ~1 s after Blender starts)
   - *"Server is running"* with a checkmark at the bottom
5. **System preferences → General → enable "Online Access"** — the add-on
   refuses to start the bridge otherwise (error: *"Online access must be
   enabled in the system preferences"*).

> Alternative install: download `mcp-1.0.0.zip` from the
> [releases page](https://projects.blender.org/lab/blender_mcp/releases) and
> *Install from Disk*. Or build from the cloned repo:
> `blender -c extension build --source-dir ./addon/blender_mcp_addon`.

## Step 4 — Register the MCP server in VS Code

Edit `~/.config/Code/User/mcp.json` (User → MCP Settings in the UI) and add:

```jsonc
"blender": {
  "type": "stdio",
  "command": "/home/<you>/.local/bin/uvx",
  "args": [
    "--from", "/mnt/data/git/blender_mcp/mcp",
    "--with", "mcp[cli]<1.10",
    "blender-mcp"
  ]
}
```

Then **reload the MCP server** (MCP view → reload `blender`, or restart the
chat session). The first start takes a few seconds while `uvx` builds the
package and fetches dependencies.

### Why each part of the config

| Piece                                  | Reason                                                                                                                                                                                                             |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `--from /mnt/data/git/blender_mcp/mcp` | The official server is **not on PyPI** — `uvx blender-mcp` would install the *community* project. `--from <path>` builds from the local clone instead.                                                             |
| `--with "mcp[cli]<1.10"`               | **Required.** The repo declares `mcp[cli]>=1.2.0`, but newer `mcp` SDK releases removed `mcp.server.fastmcp`, which `blmcp` imports. Without the pin: `ModuleNotFoundError: No module named 'mcp.server.fastmcp'`. |
| absolute `uvx` path                    | GUI-launched VS Code lacks `~/.local/bin` on `PATH` (see Step 1).                                                                                                                                                  |

No `env` block is needed: the server defaults to `localhost:9876`, matching
the add-on. For non-default add-on settings use `BLENDER_MCP_HOST` /
`BLENDER_MCP_PORT` (note: the *community* project uses `BLENDER_HOST` /
`BLENDER_PORT` — different names).

## Step 5 — Verify

Ask Copilot: *"Draw a 3D sphere in Blender."* It should call
`execute_blender_code`, then `get_screenshot_of_window_as_image` — and you
should see the object appear in your viewport.

Quick manual checks:

```bash
# Add-on bridge is listening:
ss -tlnp | grep 9876
# → LISTEN ... 127.0.0.1:9876 ... users:(("blender",...))

# MCP server starts cleanly from the CLI (Ctrl-C to exit):
uvx --from /mnt/data/git/blender_mcp/mcp --with "mcp[cli]<1.10" blender-mcp --help
```

## Tools you get

`execute_blender_code` (run arbitrary Python in Blender — always save your
work first), `execute_blender_code_for_cli` (headless, against a `.blend`
file), `get_objects_summary`, `get_object_detail_summary`,
`get_blendfile_summary_*` (datablocks, missing files, linked libraries, path
info, usage guess), `get_screenshot_of_window_as_image` /
`get_screenshot_of_area_as_image` / `get_screenshot_of_window_as_json`,
`render_viewport_to_path`, `render_thumbnail_to_path`,
`jump_to_view3d_object_*`, `jump_to_tab_*`, `search_api_docs`,
`search_manual_docs` (full bundled Blender API + user-manual reference —
a big win over the community server).

## Troubleshooting

| Symptom                                                               | Cause / fix                                                                                                                                                   |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `spawn uvx ENOENT`                                                    | `uvx` not on VS Code's PATH → use the absolute path in `mcp.json`; fully quit and relaunch VS Code after changes.                                             |
| `ModuleNotFoundError: No module named 'mcp.server.fastmcp'`           | `mcp` SDK too new → keep `--with "mcp[cli]<1.10"` in `args`.                                                                                                  |
| `Communication error with Blender: Incomplete JSON response received` | Protocol mismatch — you're running the **community** `ahujasid/blender-mcp` server against the **official** add-on (or vice versa). Use the config in Step 4. |
| `Connection refused` on 9876                                          | Add-on server not running → check *"Server is running"* in add-on Preferences; check **Online Access** is enabled in System Preferences.                      |
| `Online access must be enabled in the system preferences`             | Enable it: Edit → Preferences → System → *Online Access*.                                                                                                     |
| Server config changed but no effect                                   | Reload the `blender` MCP server / restart the chat session.                                                                                                   |
| `uvx` replaying an old broken build                                   | `uv cache clean blender-mcp && uvx --refresh --from /mnt/data/git/blender_mcp/mcp --with "mcp[cli]<1.10" blender-mcp --help`                                  |
| Repo updated (git pull)                                               | Re-run the CLI check in Step 5; if new code needs a newer `mcp`, adjust the `--with` pin.                                                                     |

## Security note

`execute_blender_code` runs **arbitrary LLM-generated Python inside Blender
with no sandbox** — it can delete files or exfiltrate data. The official
docs recommend a VM or a machine without sensitive data. Always save your
`.blend` before asking the LLM to do big things.
