#!/usr/bin/env bash

set -euo pipefail

echo "=== SageMaker Development Environment Setup ==="

LOCAL_BIN="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config"
HELIX_CONFIG_DIR="$CONFIG_DIR/helix"
CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"

###############################################################################
# Helpers
###############################################################################

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_path() {
    local path="$1"

    if [[ ":$PATH:" != *":$path:"* ]]; then
        export PATH="$path:$PATH"
    fi

    if ! grep -Fq "$path" "$HOME/.bashrc" 2>/dev/null; then
        echo "export PATH=\"$path:\$PATH\"" >> "$HOME/.bashrc"
    fi
}

gh_latest_asset() {
    local repo="$1"
    local pattern="$2"

    curl -s "https://api.github.com/repos/${repo}/releases/latest" \
        | grep browser_download_url \
        | grep "$pattern" \
        | cut -d '"' -f 4 \
        | head -n1
}

get_arch() {
    case "$(uname -m)" in
        x86_64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        *)
            echo "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
}

ARCH="$(get_arch)"

###############################################################################
# 1. apt update / upgrade
###############################################################################

echo
echo "=== Updating system packages ==="

sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

###############################################################################
# 2. Directories
###############################################################################

echo
echo "=== Creating local directories ==="

mkdir -p "$LOCAL_BIN"
mkdir -p "$HELIX_CONFIG_DIR"

ensure_path "$LOCAL_BIN"

###############################################################################
# 3. uv
###############################################################################

echo
echo "=== Checking uv ==="

if ! command_exists uv; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

ensure_path "$HOME/.local/bin"

###############################################################################
# 4. Helix
###############################################################################

echo
echo "=== Checking Helix ==="

if ! command_exists hx || [[ ! -d "$HELIX_CONFIG_DIR/runtime" ]]; then

    TMP=$(mktemp -d)

    URL=$(gh_latest_asset \
        "helix-editor/helix" \
        "${ARCH}-linux.tar.xz")

    curl -L "$URL" -o "$TMP/helix.tar.xz"

    tar -xf "$TMP/helix.tar.xz" -C "$TMP"

    HELIX_DIR=$(find "$TMP" -maxdepth 1 -type d -name "helix-*")

    install -m 755 "$HELIX_DIR/hx" "$LOCAL_BIN/hx"

    rm -rf "$HELIX_CONFIG_DIR/runtime"
    cp -R "$HELIX_DIR/runtime" "$HELIX_CONFIG_DIR/runtime"

    rm -rf "$TMP"
fi

###############################################################################
# 5. btop
###############################################################################

echo
echo "=== Checking btop ==="

if ! command_exists btop; then
    sudo apt install -y btop
fi

###############################################################################
# 6. Ruff
###############################################################################

echo
echo "=== Checking Ruff ==="

if ! command_exists ruff; then
    uv tool install ruff
fi

###############################################################################
# 7. Rust
###############################################################################

echo
echo "=== Checking Rust ==="

if ! command_exists rustup; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
fi

ensure_path "$CARGO_HOME/bin"

if [[ -f "$CARGO_HOME/env" ]]; then
    source "$CARGO_HOME/env"
fi

###############################################################################
# 8. just
###############################################################################

echo
echo "=== Checking just ==="

if ! command_exists just; then
    uv tool install rust-just
fi

###############################################################################
# 9. tmux
###############################################################################

echo
echo "=== Checking tmux ==="

if ! command_exists tmux; then
    sudo apt install -y tmux
fi

###############################################################################
# 10. typst
###############################################################################

echo
echo "=== Checking typst ==="

if ! command_exists typst; then

    TMP=$(mktemp -d)

    URL=$(gh_latest_asset \
        "typst/typst" \
        "${ARCH}-unknown-linux-musl.tar.xz")

    curl -L "$URL" -o "$TMP/typst.tar.xz"

    tar -xf "$TMP/typst.tar.xz" -C "$TMP"

    BIN=$(find "$TMP" -type f -name typst | head -n 1)

    install -m 755 "$BIN" "$LOCAL_BIN/typst"

    rm -rf "$TMP"
fi

###############################################################################
# 11. tinymist
###############################################################################

echo
echo "=== Checking tinymist ==="

if ! command_exists tinymist; then
    echo "Installing tinymist..."

    curl --proto '=https' --tlsv1.2 -LsSf \
        https://github.com/Myriad-Dreamin/tinymist/releases/latest/download/tinymist-installer.sh \
        | sh

    ensure_path "$HOME/.local/bin"
fi

###############################################################################
# 12. typstyle
###############################################################################

echo
echo "=== Checking typstyle ==="

if ! command_exists typstyle; then

    echo "Installing typstyle..."

    TMP=$(mktemp -d)

    if [[ "$ARCH" == "x86_64" ]]; then
        ASSET="typstyle-x86_64-unknown-linux-gnu"
    else
        ASSET="typstyle-aarch64-unknown-linux-gnu"
    fi

    URL=$(gh_latest_asset \
        "typstyle-rs/typstyle" \
        "$ASSET")

    curl -L "$URL" -o "$TMP/typstyle"

    install -m 755 "$TMP/typstyle" "$LOCAL_BIN/typstyle"

    rm -rf "$TMP"
fi

###############################################################################
# 13. harper-ls
###############################################################################

echo
echo "=== Checking harper-ls ==="

if ! command_exists harper-ls; then

    TMP=$(mktemp -d)

    URL=$(gh_latest_asset \
        "Automattic/harper" \
        "x86_64-unknown-linux-musl.tar.gz")

    curl -L "$URL" -o "$TMP/harper.tar.gz"

    tar -xzf "$TMP/harper.tar.gz" -C "$TMP"

    BIN=$(find "$TMP" -type f -name harper-ls | head -n 1)

    install -m 755 "$BIN" "$LOCAL_BIN/harper-ls"

    rm -rf "$TMP"
fi

###############################################################################
# 14. Harlequin
###############################################################################

echo
echo "=== Checking Harlequin ==="

if ! command_exists harlequin; then
    echo "Installing Harlequin..."

    uv tool install harlequin[postgres]
else
    echo "Harlequin already installed"
fi


###############################################################################
# Summary
###############################################################################

echo
echo "=== Installation Complete ==="
echo

echo "uv        : $(command -v uv || true)"
echo "hx        : $(command -v hx || true)"
echo "btop      : $(command -v btop || true)"
echo "ruff      : $(command -v ruff || true)"
echo "rustup    : $(command -v rustup || true)"
echo "cargo     : $(command -v cargo || true)"
echo "just      : $(command -v just || true)"
echo "tmux      : $(command -v tmux || true)"
echo "typst     : $(command -v typst || true)"
echo "tinymist  : $(command -v tinymist || true)"
echo "typstyle : $(command -v typstyle || true)"
echo "harper-ls : $(command -v harper-ls || true)"
echo "harlequin : $(command -v harlequin || true)"

echo
echo "Helix runtime:"
echo "  $HOME/.config/helix/runtime"

echo
echo "Run the following if this is your first setup:"
echo "  source ~/.bashrc"

