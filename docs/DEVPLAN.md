# Development Plan: Ollama Component

**Status:** In Progress
**Created:** 2026-03-29
**Updated:** 2026-03-29

## Overview

Deployment component for Ollama local LLM inference on the ephemeral security workstation. Installs Ollama binary, NVIDIA drivers, pulls models, and configures systemd service. Bundled into usb-autoinstall for weekly OS rebuilds.

## Constraints

- Shell scripts only (no Python — runs before dev environment exists)
- Must work fully offline after USB creation
- `shellcheck` clean on all scripts
- All scripts idempotent (safe to re-run)
- Ollama listens on localhost:11434 only
- Models persist on SECRETS partition across rebuilds

---

## Feature: nvidia-drivers

**Branch:** `feature/nvidia-drivers`
**Depends on:** none
**Requires:** both
**Status:** Not Started

### Goal

Add NVIDIA driver and CUDA toolkit to the package list so GPU acceleration works. Handle the driver installation in install.sh with proper ordering (driver before Ollama service start).

### Acceptance Criteria

- [ ] `packages.list` includes `nvidia-driver-560` and `nvidia-cuda-toolkit`
- [ ] `install.sh` installs NVIDIA packages before deploying Ollama binary
- [ ] When running in autoinstall (chroot mode), drivers are installed via late-commands
- [ ] When running standalone, drivers install via apt and warn that reboot is needed
- [ ] Script detects if NVIDIA driver is already loaded (`nvidia-smi`) and skips if so
- [ ] [HUMAN] Reboot after first install to load the driver
- [ ] [HUMAN] Verify `nvidia-smi` shows RTX 2060 after reboot

### Files to Create or Modify

| File | Action | Purpose |
|------|--------|---------|
| `packages.list` | Modify | Add nvidia-driver-560, nvidia-cuda-toolkit |
| `install.sh` | Modify | Add driver detection and install step |

### Key Decisions

- nvidia-driver-560 (not 535 or 550): stable series, RTX 2060 support confirmed
- Install via apt (not .run file): integrates with Ubuntu package management, auto-updates
- During autoinstall: packages pulled from USB apt cache, installed in chroot

### Notes

- NVIDIA driver install in chroot requires special handling — the kernel module can't load until first real boot
- The autoinstall USB's `download-all-packages.sh` must include these packages in the apt cache
- After this feature, Ollama will automatically detect and use the GPU on next start

---

## Feature: model-pull

**Branch:** `feature/model-pull`
**Depends on:** nvidia-drivers
**Requires:** both
**Status:** Not Started

### Goal

Add a model download script for USB creation and a post-install model pull step. Models are downloaded once during USB creation, stored on SECRETS partition, and symlinked on each rebuild.

### Acceptance Criteria

- [ ] `scripts/download-ollama.sh` downloads Ollama binary + default model for USB creation
- [ ] Model stored at `/media/secrets/ollama/models/` (SECRETS partition)
- [ ] `setup-ollama.sh` pulls model if not already present after first boot
- [ ] Model pull only happens when Ollama service is running and responsive
- [ ] Waits for Ollama readiness (retry loop with timeout)
- [ ] Default model: `qwen2.5:7b-instruct-q4_K_M` (~4.4GB)
- [ ] [HUMAN] Run download script during USB creation (requires internet)
- [ ] [HUMAN] Verify model responds: `ollama run qwen2.5:7b-instruct-q4_K_M "Hello"`

### Files to Create or Modify

| File | Action | Purpose |
|------|--------|---------|
| `scripts/download-ollama.sh` | Create | Downloads binary + model for USB |
| `setup-ollama.sh` | Modify | Add model pull with readiness wait |

### Key Decisions

- Download during USB creation (not post-install): 4.4GB download is too slow for post-install
- SECRETS partition (not STORAGE): models are user data, persist across format cycles
- Readiness wait: Ollama takes a few seconds to start; pull must wait for API response

### Notes

- To pre-download a model for USB: `OLLAMA_MODELS=/media/secrets/ollama/models ollama pull qwen2.5:7b-instruct-q4_K_M`
- The symlink from `/var/lib/ollama/models` → `/media/secrets/ollama/models` is already in setup-ollama.sh

---

## Feature: validation-and-health

**Branch:** `feature/validation-and-health`
**Depends on:** model-pull
**Requires:** ai
**Status:** Not Started

### Goal

Add a validation script that verifies the full Ollama stack: driver loaded, service running, model available, inference working. Used for post-install verification and ongoing health checks.

### Acceptance Criteria

- [ ] `scripts/validate-ollama.sh` checks: nvidia-smi responds, ollama service active, API responds at localhost:11434, model listed, test inference returns a response
- [ ] Exit code 0 if all checks pass, non-zero with clear error message if any fail
- [ ] Can be run standalone or called from usb-autoinstall's test suite
- [ ] Each check prints PASS/FAIL with details

### Files to Create or Modify

| File | Action | Purpose |
|------|--------|---------|
| `scripts/validate-ollama.sh` | Create | Full stack validation |

---

## Feature: docs-and-readme

**Branch:** `feature/docs-and-readme`
**Depends on:** validation-and-health
**Requires:** ai
**Status:** Not Started

### Goal

Write README documenting the component: what it is, how it integrates with usb-autoinstall, how to use standalone, GPU requirements, troubleshooting.

### Acceptance Criteria

- [ ] README.md with: description, architecture diagram, prerequisites (GPU), standalone install steps, autoinstall integration, model management, troubleshooting (driver issues, VRAM, model not loading)
- [ ] Integration instructions for morning-brief and dtl consumers

### Files to Create or Modify

| File | Action | Purpose |
|------|--------|---------|
| `README.md` | Create | Component documentation |
