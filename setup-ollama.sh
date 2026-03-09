#!/usr/bin/env bash
#===============================================================================
# Ollama Setup Script
#===============================================================================
# Description: Sets up Ollama for local LLM inference on the host.
#              Creates the ollama user, installs the binary from USB, sets up
#              model storage, and optionally symlinks models from SECRETS.
# Usage: /usr/local/bin/setup-ollama.sh
# Phase: AI Sandbox Phase 2
#===============================================================================

set -euo pipefail

readonly FLAG_FILE="/var/lib/ollama/.setup-complete"
readonly OLLAMA_BINARY="/usr/local/bin/ollama"
readonly OLLAMA_TGZ="/media/autoinstall/usb-autoinstall/ollama/ollama-linux-amd64.tar.zst"
readonly MODEL_DIR="/var/lib/ollama/models"
readonly SECRETS_MODELS="/media/secrets/ollama/models"

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERR]  $*" >&2
}

create_ollama_user() {
    if id ollama &>/dev/null; then
        log_info "User 'ollama' already exists"
        return 0
    fi

    log_info "Creating system user 'ollama'..."
    useradd --system --shell /usr/sbin/nologin --no-create-home \
        --home-dir /var/lib/ollama ollama
}

install_ollama_binary() {
    if [ -x "$OLLAMA_BINARY" ]; then
        log_info "Ollama binary already installed at $OLLAMA_BINARY"
        return 0
    fi

    if [ ! -f "$OLLAMA_TGZ" ]; then
        log_error "Ollama archive not found: $OLLAMA_TGZ"
        return 1
    fi

    log_info "Extracting Ollama binary from $OLLAMA_TGZ..."
    local tmpdir
    tmpdir=$(mktemp -d)
    tar --zstd -xf "$OLLAMA_TGZ" -C "$tmpdir"

    if [ -f "$tmpdir/bin/ollama" ]; then
        cp "$tmpdir/bin/ollama" "$OLLAMA_BINARY"
        for runner in "$tmpdir/bin/ollama-"*; do
            [ -f "$runner" ] && cp "$runner" /usr/local/bin/
        done
    elif [ -f "$tmpdir/ollama" ]; then
        cp "$tmpdir/ollama" "$OLLAMA_BINARY"
    else
        log_error "Could not find ollama binary in archive"
        rm -rf "$tmpdir"
        return 1
    fi

    chmod 755 "$OLLAMA_BINARY"
    rm -rf "$tmpdir"
    log_info "Ollama binary installed to $OLLAMA_BINARY"
}

setup_model_directory() {
    log_info "Setting up model directory at $MODEL_DIR..."
    mkdir -p "$MODEL_DIR"

    # If SECRETS partition has pre-downloaded models, symlink to them.
    # Avoids duplicating multi-GB model files and persists models
    # across weekly workstation rebuilds.
    if [ -d "$SECRETS_MODELS" ]; then
        log_info "Found models on SECRETS partition: $SECRETS_MODELS"

        if [ -L "$MODEL_DIR" ]; then
            log_info "Model directory already symlinked: $(readlink -f "$MODEL_DIR")"
        elif [ -d "$MODEL_DIR" ] && [ -z "$(ls -A "$MODEL_DIR" 2>/dev/null)" ]; then
            rmdir "$MODEL_DIR"
            ln -s "$SECRETS_MODELS" "$MODEL_DIR"
            log_info "Symlinked $MODEL_DIR -> $SECRETS_MODELS"
        fi
    fi

    chown -R ollama:ollama /var/lib/ollama 2>/dev/null || true
}

mark_complete() {
    mkdir -p /var/lib/ollama
    cat > "$FLAG_FILE" << EOF
Ollama setup completed: $(date)
Binary: $OLLAMA_BINARY
Models: $MODEL_DIR
EOF
    chown ollama:ollama "$FLAG_FILE" 2>/dev/null || true
}

main() {
    if [ -f "$FLAG_FILE" ]; then
        log_info "Ollama setup already complete. Skipping."
        exit 0
    fi

    log_info "Ollama Setup — AI Sandbox Phase 2"
    create_ollama_user
    install_ollama_binary
    setup_model_directory
    mark_complete
    log_info "Ollama setup complete. Start with: systemctl start ollama"
}

main "$@"
