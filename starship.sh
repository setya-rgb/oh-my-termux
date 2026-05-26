#!/usr/bin/env bash

set -Eeuo pipefail

REPO="starship/starship"
ASSET="aarch64-unknown-linux-musl.tar.gz"

# Detect architecture
ARCH="$(uname -m)"

case "$ARCH" in
    aarch64|arm64)
        ASSET="aarch64-unknown-linux-musl.tar.gz"
        ;;
    armv7l|armv8l)
        ASSET="arm-unknown-linux-musleabihf.tar.gz"
        ;;
    x86_64|amd64)
        ASSET="x86_64-unknown-linux-musl.tar.gz"
        ;;
    i686|i386)
        ASSET="i686-unknown-linux-musl.tar.gz"
        ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"

# Fetch latest release asset URL
URL="$(
    curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
    grep -oE '"browser_download_url":[[:space:]]*"[^"]+"' |
    cut -d'"' -f4 |
    grep "$ASSET" |
    head -n1
)"

[ -z "$URL" ] && {
    echo "Failed to locate Starship asset" >&2
    exit 1
}

echo "Downloading: $URL"

curl -fL# -O "$URL"

ARCHIVE="$(basename "$URL")"

tar -xzf "$ARCHIVE"

install -Dm755 starship "$PREFIX/bin/starship"

echo "Installed:"
command -v starship
starship --version