# GPU Power Limit — Making the Change Persistent

Two problems to solve when limiting GPU power:

1. **Keep the driver alive** so power limits don't get erased when the GPU goes idle → install the `nvidia-persistenced` daemon.
2. **Apply the power limit at boot** since both `nvidia-persistenced` and `-pl` are lost on reboot → pick one of 3 methods below.

> `nvidia-persistenced` is **not an alternative** to the 3 methods — it's a prerequisite. Without it, the driver unloads when idle and forgets your power limit.

## Quick Start

```bash
# 1. Enable Persistence Mode (keeps the driver loaded)
sudo nvidia-smi -pm 1

# 2. Set the power limit (300 W in this example)
sudo nvidia-smi -i 0 -pl 300
```

> **⚠️ Always run `-pm` and `-pl` as separate commands, not combined on one line.** Running `nvidia-smi -pm 1 -pl 300` can produce errors and the power limit won't be applied.

### Flags explained

| Flag      | Meaning                                                                                            |
| --------- | -------------------------------------------------------------------------------------------------- |
| `-pm 1`   | Enable **Persistence Mode**. Keeps the NVIDIA driver loaded even when no process is using the GPU. |
| `-i 0`    | Target GPU by index (0 = first GPU).                                                               |
| `-pl 300` | Set **power limit** to 300 W. Without this, the GPU uses its default power limit.                  |

### Verify

```bash
nvidia-smi -i 0 -q -d POWER
```

The `Power Limit` line should read `300.00 W`.

---

## Step 1 — Install the NVIDIA Persistence Daemon (always required)

### What is Persistence Mode?

**Persistence Mode** (`nvidia-smi -pm 1`) forces the NVIDIA driver to stay actively loaded in the kernel, even when no applications are using the GPU.

### Why is it mandatory for power limits?

By default, the NVIDIA driver is "lazy" — if no application is using the GPU, the driver unloads itself to save resources.

**When the driver unloads, it forgets all custom settings.** Without Persistence Mode, here's what happens:

1. You run `sudo nvidia-smi -pl 300` to set a 300 W limit.
2. Your `llama-server` container runs and respects the 300 W limit.
3. You stop the container. The GPU is idle, so the driver unloads.
4. **The 300 W limit is erased.**
5. You restart the container. The GPU runs at its **default factory limit** (e.g., 350 W), ignoring your previous setting.

Additionally, without Persistence Mode, the first GPU workload after boot suffers a multi-second "cold boot" delay while the driver re-initializes.

### How to use it correctly

Always enable Persistence Mode **before** setting the power limit, using **separate commands**:

**1. Enable Persistence Mode**

```bash
sudo nvidia-smi -pm 1
```

*(You should see: `Enabled persistence mode for GPU 0...`)*

**2. Set your custom Power Limit**

```bash
sudo nvidia-smi -i 0 -pl 300
```

Now the 300 W limit is securely locked in. You can start, stop, and restart your Docker containers as many times as you want, and the GPU will never exceed 300 W.

### The Reboot Catch

The `nvidia-smi -pm 1` command is **temporary** — it will be lost on reboot.

To solve this permanently, NVIDIA provides the **NVIDIA Persistence Daemon** (`nvidia-persistenced`). It acts as a permanent "dummy client" that keeps the driver awake at all times.

Enable it permanently on Ubuntu/Debian:

```bash
sudo systemctl enable --now nvidia-persistenced
```

Once this daemon is running, the driver will never unload, and your power limit will stick between container restarts. But you still need to **apply the power limit at boot** — the daemon doesn't do that for you. See [Step 2](#step-2---apply-the-power-limit-at-boot) below.

---

## Step 2 — Apply the Power Limit at Boot (pick one)

The power limit resets on reboot. Pick one of the following methods to auto-apply it.

### Option 1 — systemd service (recommended)

Create a unit file:

```bash
sudo nano /etc/systemd/system/gpu-power-limit.service
```

```ini
[Unit]
Description=Set GPU 0 power limit to 300W
After=nvidia-persistenced.service
Wants=nvidia-persistenced.service

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi -i 0 -pl 300
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Then enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable gpu-power-limit.service
```

**Why recommended:** Waits for `nvidia-persistenced.service` before applying the power limit, so there's no race condition. Clean and easy to disable or tweak later.

---

### Option 2 — `/etc/rc.local`

Edit (or create) the file:

```bash
sudo nano /etc/rc.local
```

Add the line **before** the final `exit 0`:

```bash
/usr/bin/nvidia-smi -i 0 -pl 300
```

Make it executable:

```bash
sudo chmod +x /etc/rc.local
```

**Caveat:** `rc.local` runs late in boot, after the driver is ready, so it usually works fine. Less structured than a systemd unit.

---

### Option 3 — cron `@reboot`

Add a reboot-time job:

```bash
sudo crontab -e
```

Append:

```
@reboot /usr/bin/nvidia-smi -i 0 -pl 300
```

**Caveat:** cron jobs can race against the NVIDIA driver starting up. If the driver isn't ready when the job fires, the command will silently fail. Adding a small `sleep` or wrapping in a retry loop can help, but systemd (Option 1) handles this more elegantly.
