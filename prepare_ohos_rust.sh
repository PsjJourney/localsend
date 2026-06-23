#!/usr/bin/env bash

set -euo pipefail

TARGET="${1:-aarch64-unknown-linux-ohos}"

if ! command -v rustup >/dev/null 2>&1; then
  if [ -f "${HOME}/.cargo/env" ]; then
    # shellcheck disable=SC1090
    . "${HOME}/.cargo/env"
  fi
fi

if ! command -v rustup >/dev/null 2>&1; then
  echo "rustup is not installed or not available in PATH."
  echo "Install Rust first, then rerun this build."
  echo "Suggested installer:"
  echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
  exit 1
fi

if ! rustup target list --installed | grep -qx "$TARGET"; then
  echo "==> Installing Rust target: $TARGET"
  rustup target add "$TARGET"
fi

echo "==> Rust toolchain"
rustup show active-toolchain
cargo --version
