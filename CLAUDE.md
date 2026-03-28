# Ollama Component

## What This Is

A deployment component for the usb-autoinstall ephemeral security workstation. Installs and configures Ollama (local LLM inference server) with NVIDIA GPU acceleration. Designed to be bundled into the autoinstall USB and re-deployed on weekly OS rebuilds.

## Architecture

```
USB STORAGE partition
├── ollama/ollama-linux-amd64.tar.zst    ← pre-downloaded binary

USB SECRETS partition (persists across rebuilds)
└── ollama/models/                        ← downloaded models persist here
         ↓ (symlinked)
Host system
├── /usr/local/bin/ollama                 ← binary
├── /var/lib/ollama/models → SECRETS      ← symlink to persistent storage
├── /etc/systemd/system/ollama.service    ← systemd unit
└── NVIDIA driver + CUDA                  ← GPU acceleration
         ↓ (localhost:11434)
Consumers
├── morning-brief pipeline                ← article summarization
├── dtl AI containers                     ← local model access
└── AI sandbox VMs                        ← port-forwarded access
```

## Tech Stack

| Component | Choice | Why |
|-----------|--------|-----|
| LLM server | Ollama | Simple, well-audited Go binary, GPU support |
| Default model | Qwen 2.5 7B (Q4_K_M) | Fits 6GB VRAM (RTX 2060), good at summaries |
| GPU | NVIDIA RTX 2060 6GB | Host GPU, not passed through to VMs |
| Driver | nvidia-driver-560 | Supports RTX 2060, Ubuntu 24.04 compatible |
| Install method | Pre-downloaded to USB | Works offline, fast deployment |

## Project Structure

```
ollama/
├── install.sh              ← Component installer (called by post-install.sh)
├── setup-ollama.sh         ← First-boot setup (user, binary, models)
├── packages.list           ← APT packages needed (nvidia driver, cuda)
├── services.list           ← Systemd units to enable
├── systemd/
│   └── ollama.service      ← Systemd unit file
├── scripts/
│   └── download-ollama.sh  ← Downloads binary + model for USB creation
├── docs/
│   └── DEVPLAN.md
├── CLAUDE.md
└── README.md
```

## Constraints

- Must work offline after USB installation (no internet required for deploy)
- Models persist on SECRETS partition across weekly OS rebuilds
- Binary pre-downloaded to STORAGE partition during USB creation
- Ollama listens on localhost only (127.0.0.1:11434) — never exposed to LAN
- NVIDIA driver installation requires reboot — plan accordingly in autoinstall
- Single GPU shared between host display and Ollama (no passthrough)
- Shell scripts only — no Python dependencies (runs before dev environment exists)

## Commit Conventions

- Conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `chore:`
- Gitflow branching: `main`, `develop`, `feature/*`, `release/*`, `hotfix/*`
- Feature branches merge to develop via PR

## Code Standards

- `shellcheck` on all `.sh` files
- Scripts must be idempotent (safe to re-run)
- All scripts use `set -euo pipefail`

## Key Decisions

- Ollama on host, not in VM: GPU stays on host for display, Ollama connects via CUDA directly
- SECRETS symlink for models: avoids re-downloading 4.4GB model every weekly rebuild
- Standalone binary (not apt): Ollama doesn't have an official .deb, binary is simpler
- nvidia-driver-560: stable driver series for RTX 2060 on Ubuntu 24.04

## Integration Points

- **usb-autoinstall**: `install.sh` called by `post-install.sh` during autoinstall, `packages.list` merged into master package list
- **morning-brief**: connects at `OLLAMA_HOST=http://localhost:11434`
- **devtools (dtl)**: AI containers connect at `http://host.docker.internal:11434` or via docker network
- **AI sandbox VMs**: connect via port-forwarded TAP interface
