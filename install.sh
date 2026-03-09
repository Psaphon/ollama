#!/bin/bash
#===============================================================================
# Ollama Component Installer
#===============================================================================
# Deploys Ollama LLM inference server from pre-downloaded binary.
# Called by post-install.sh during autoinstall or standalone for updates.
#
# Usage:
#   sudo ./install.sh              # deploy to running system
#   sudo ./install.sh /target      # deploy to chroot (during autoinstall)
#===============================================================================

set -euo pipefail

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"
PREFIX="${TARGET}"
STORAGE_ROOT="${STORAGE_ROOT:-/media/storage}"

log() { echo "[ollama] $1"; }

#--- Ollama binary ---
log "Deploying Ollama..."

local_archive="$STORAGE_ROOT/ollama/ollama-linux-amd64.tar.zst"
if [ -f "$local_archive" ]; then
    log "Extracting Ollama from $local_archive..."
    tmpdir=$(mktemp -d)
    tar --use-compress-program=unzstd -xf "$local_archive" -C "$tmpdir" 2>/dev/null \
        || tar -I zstd -xf "$local_archive" -C "$tmpdir" 2>/dev/null \
        || { log "WARNING: Failed to extract Ollama archive"; rm -rf "$tmpdir"; }

    if [ -d "$tmpdir" ] && [ -n "$(ls -A "$tmpdir" 2>/dev/null)" ]; then
        # Find and install the ollama binary
        if [ -f "$tmpdir/bin/ollama" ]; then
            cp "$tmpdir/bin/ollama" "${PREFIX}/usr/local/bin/ollama"
            chmod +x "${PREFIX}/usr/local/bin/ollama"
            # Copy runner libraries if present
            if [ -d "$tmpdir/lib/ollama" ]; then
                mkdir -p "${PREFIX}/usr/local/lib/ollama"
                cp -r "$tmpdir/lib/ollama/"* "${PREFIX}/usr/local/lib/ollama/"
            fi
            log "Ollama binary installed"
        else
            log "WARNING: ollama binary not found in archive"
        fi
        rm -rf "$tmpdir"
    fi
else
    log "Ollama archive not found at $local_archive — skipping"
    log "Download with: scripts/download-all-packages.sh"
fi

#--- Ollama system user ---
log "Setting up Ollama user..."
if [ -n "$PREFIX" ]; then
    # During autoinstall (chroot) — user creation happens via chroot
    chroot "$PREFIX" useradd -r -s /bin/false -U -m -d /var/lib/ollama ollama 2>/dev/null || true
else
    useradd -r -s /bin/false -U -m -d /var/lib/ollama ollama 2>/dev/null || true
fi

#--- Model directory ---
mkdir -p "${PREFIX}/var/lib/ollama/models"
if [ -n "$PREFIX" ]; then
    chroot "$PREFIX" chown -R ollama:ollama /var/lib/ollama 2>/dev/null || true
else
    chown -R ollama:ollama /var/lib/ollama 2>/dev/null || true
fi

#--- Setup script ---
if [ -f "$COMPONENT_DIR/setup-ollama.sh" ]; then
    cp "$COMPONENT_DIR/setup-ollama.sh" "${PREFIX}/usr/local/bin/"
    chmod +x "${PREFIX}/usr/local/bin/setup-ollama.sh"
fi

#--- Systemd unit ---
log "Deploying systemd unit..."
for unit in "$COMPONENT_DIR"/systemd/*.service; do
    [ -f "$unit" ] || continue
    cp "$unit" "${PREFIX}/etc/systemd/system/"
    chmod 644 "${PREFIX}/etc/systemd/system/$(basename "$unit")"
done

log "Ollama component deployed"
