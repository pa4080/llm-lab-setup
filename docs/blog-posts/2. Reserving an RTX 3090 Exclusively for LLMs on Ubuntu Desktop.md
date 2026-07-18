<!-- keywords: dedicated local AI server, compute GPU, RTX 3090, 24GB VRAM, low-power GPU, NVIDIA T600, host operating system display output, AI server hardware strategy, dual GPU setup, VRAM optimization, headless AI server, GPU passthrough, AI inference hardware -->

When building a home-lab local AI server, my current hardware strategy is to pair a massive compute GPU (an RTX 3090 with 24GB VRAM) with a smaller, low-power GPU (an NVIDIA T600) to handle the host operating system's display output.
<!--more-->

In theory, this leaves the compute GPU with 100% of its VRAM available for loading Large Language Models (LLMs). In practice, Linux's Desktop display servers (Xorg/Wayland) and desktop environments (GNOME) are greedy. They will automatically probe, attach to, and siphon VRAM from the most powerful GPU in the system—even if no monitor is physically plugged into it.

> I am running this setup on a Proxmox VM powered by Ubuntu Desktop, where both the [RTX 3090 and NVIDIA T600 were passed through](/blog/four-gpu-passthrough-in-proxmox-ve-overcoming-hostage-framebuffers-and-identical-cards).

Here is how I successfully wrested my RTX 3090 away from Ubuntu/GNOME and locked all host rendering to the T600.

## Table of Contents

## The Problem: The Missing Megabytes

I checked `nvidia-smi` expecting to see an empty RTX 3090 (GPU 0), but instead found nearly 300MiB of VRAM held hostage by the host system, while my dedicated display T600 (GPU 1) sat underutilized:

```text
|=========================================+========================+======================|
|   0  NVIDIA GeForce RTX 3090        Off |   00000000:01:00.0 Off |                  N/A |
|  0%   42C    P8             19W /  370W |     293MiB /  24576MiB |      0%      Default |
|=========================================+========================+======================|
|   1  NVIDIA T600                    Off |   00000000:02:00.0  On |                  N/A |
| 64%   80C    P0             N/A  /   41W |     863MiB /   4096MiB |      6%     Default |
+-----------------------------------------+------------------------+----------------------+

Processes:
|  GPU   GI   CI               PID   Type   Process name                       GPU Memory |
|=========================================================================================|
|    0   N/A  N/A             2700      G   /usr/lib/xorg/Xorg                       4MiB |
|    0   N/A  N/A             2912    C+G   ...c/gnome-remote-desktop-daemon       260MiB |
```

The culprits? Xorg claiming DRM node space, and `gnome-remote-desktop-daemon` aggressively grabbing the 3090 to utilize its NVENC hardware encoder for remote access streams.

To fix this, we need to apply rules across multiple layers: Xorg, Mutter (GNOME's Window Manager), the kernel KMS driver, and Systemd.

## Step 1: Tell Xorg to Ignore the 3090

First, we need to explicitly bind the X11 display server to the T600 based on its PCI Bus ID.
*(Note: You can find the Bus ID in the `nvidia-smi` output. In my case, the T600 is on `02:00.0`)*.

Create a new Xorg configuration file:

```bash
sudo mkdir -p /etc/X11/xorg.conf.d/
sudo nano /etc/X11/xorg.conf.d/10-gpu-isolation.conf
```

Add the following configuration to turn off automatic GPU probing and explicitly declare the T600 as the sole device:

```bash
# Prevent Xorg from automatically attaching to secondary GPUs
Section "ServerFlags"
    Option "AutoAddGPU" "off"
EndSection

# Explicitly bind the display server to the NVIDIA T600
Section "Device"
    Identifier "NVIDIA-T600"
    Driver "nvidia"
    BusID "PCI:2:0:0"
EndSection

# Prevent the 3090 from being used by Xorg at all
Section "Device"
    Identifier "RTX-3090-blocked"
    Driver "null"
    BusID "PCI:1:0:0"
EndSection
```

## Step 2: Force GNOME/Mutter to the Display GPU

If your system uses Wayland, it will largely ignore Xorg configs. We have to create a `udev` rule to tell Mutter which Direct Rendering Infrastructure (DRI) device to prefer.

First, identify which card ID belongs to your display GPU:

```bash
ls -l /dev/dri/by-path/
```

*(In my setup, the T600 `pci-0000:02:00.0` was symlinked to `card2`)*.

Create the udev rule:

```bash
sudo nano /etc/udev/rules.d/61-mutter-primary-gpu.rules
```

Add this line, ensuring you point it to the correct `cardX`:

```text
ENV{DEVNAME}=="/dev/dri/card2", TAG+="mutter-device-preferred-primary"
```

Reload the rules so they take effect on the next boot:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Step 3: Disable KMS on the Compute GPU

Even after isolating Xorg and Mutter, the NVIDIA Kernel Mode Setting (KMS) driver was still allocating VRAM on the 3090 for its framebuffer. I discovered this by checking which driver was bound to the 3090:

```bash
lspci -s 01:00.0 -k | grep -A3 "VGA\|Kernel"
```

This revealed that `nvidia_drm` (the DRM/KMS driver) was active — which means the kernel was reserving VRAM for display even though no display server was using it.

The fix is to disable KMS on the 3090 specifically, keeping it headless:

```bash
echo "options nvidia-drm modeset=0 fbdev=0" | sudo tee /etc/modprobe.d/nvidia-3090-headless.conf
sudo update-initramfs -u -k all
```

This configuration disables both modesetting and framebuffer on the 3090, reducing its idle VRAM footprint to the bare minimum (~15 MiB). A reboot is required for this change to take effect.

## Step 4: Defeat the Final Boss (GNOME Remote Desktop)

Even with Xorg and Mutter contained, `gnome-remote-desktop-daemon` will often bypass standard display rules to hunt for the most powerful NVENC encoder. We need to put blinders on the service so it literally cannot see the RTX 3090.

We do this by overriding the user-level systemd service and injecting CUDA/NVIDIA visibility environment variables.

Create a drop-in directory for the user service:

```bash
mkdir -p ~/.config/systemd/user/gnome-remote-desktop.service.d
nano ~/.config/systemd/user/gnome-remote-desktop.service.d/override.conf
```

Paste the following to restrict its vision entirely to GPU 1 (the T600):

```text
[Service]
Environment="CUDA_VISIBLE_DEVICES=1"
Environment="NVIDIA_VISIBLE_DEVICES=1"
```

Apply the changes and restart the daemon:

```bash
systemctl --user daemon-reload
systemctl --user restart gnome-remote-desktop
```

*Alternatively, if you don't use Ubuntu's built-in Screen Sharing at all, you can just stop and mask the service entirely with `systemctl --user mask gnome-remote-desktop`.*

## Step 5: Reboot

All the configuration changes take effect on reboot. This restarts the display server, reloads kernel modules with the new KMS settings, and applies the updated initramfs.

```bash
sudo reboot
```

After the system comes back up, verify the isolation with:

```bash
nvidia-smi -i 0 --query-gpu=memory.used,temperature.gpu,power.draw --format=csv,noheader,nounits
```

The RTX 3090 (GPU 0) should show an idle footprint of **~15 MiB**. You can also confirm that KMS is no longer loaded on the 3090:

```bash
lspci -s 01:00.0 -k | grep -A3 "VGA\|Kernel"
```

The output should no longer show `nvidia_drm` under the Kernel driver section.

You can also verify the DRI card mapping hasn't changed:

```bash
ls -l /dev/dri/by-path/
```

The 3090 (`pci-0000:01:00.0`) should still map to `card1` and the T600 (`pci-0000:02:00.0`) to `card2`.

Finally, confirm no compute processes are leaking onto the 3090:

```bash
nvidia-smi -i 0 --query-compute-apps=pid,used_memory --format=csv,noheader,nounits
```

This should return nothing (or only your `llama-server` process when running a model).

```bash
nvidia-smi -i 0 -q -d MEMORY
```

This should show the 3090's memory usage is minimal, confirming that the host system is no longer reserving VRAM for display purposes.

## The Result

After a quick `sudo reboot`, the system came back up perfectly segregated.

Checking `nvidia-smi`, `gnome-remote-desktop` was reduced to a microscopic 4MiB footprint, and Xorg had vacated the compute card entirely.

```text
|=========================================+========================+======================|
|   0  NVIDIA GeForce RTX 3090        Off |   00000000:01:00.0 Off |                  N/A |
|  0%   45C    P8             15W /  370W |      15MiB /  24576MiB |      0%      Default |
|=========================================+========================+======================|
```

The RTX 3090 now idles at **15MiB** (representing the bare-minimum architectural overhead required by the NVIDIA driver). The remaining **24,561 MiB** of VRAM is fully unfragmented and ready to swallow massive 4-bit quantized LLMs without throwing frustrating Out-Of-Memory exceptions.

When running your models (via Ollama, vLLM, etc.), you can now just prefix your launch commands with `CUDA_VISIBLE_DEVICES=0` to ensure your AI stack stays comfortably within its dedicated silicon.

## Bonus: How to tell your LLM to use the RTX 3090

Since the system is no longer touching the 3090, you just need to ensure your AI software (Ollama, vLLM, Text-Generation-WebUI, PyTorch, etc.) knows where to go. You can force any terminal application to only "see" the RTX 3090 by prefixing your run command with the `CUDA_VISIBLE_DEVICES` environment variable.

```bash
CUDA_VISIBLE_DEVICES=0 ollama serve
```
