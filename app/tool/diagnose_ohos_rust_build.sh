#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="$ROOT_DIR/rust_builder"
MANIFEST_DIR="$ROOT_DIR/rust"
TEMP_DIR="${OHOS_RUST_TEMP_DIR:-$ROOT_DIR/build/ohos-rust-diagnose}"
OUTPUT_DIR="$TEMP_DIR/output"

mkdir -p "$TEMP_DIR" "$OUTPUT_DIR"

export CARGOKIT_CONFIGURATION="${CARGOKIT_CONFIGURATION:-release}"
export CARGOKIT_MANIFEST_DIR="$MANIFEST_DIR"
export CARGOKIT_TARGET_TEMP_DIR="$TEMP_DIR"
export CARGOKIT_OUTPUT_DIR="$OUTPUT_DIR"
export CARGOKIT_TARGET_PLATFORM="${CARGOKIT_TARGET_PLATFORM:-ohos-arm64}"
export CARGOKIT_TOOL_TEMP_DIR="$TEMP_DIR/tool"
export CARGOKIT_ROOT_PROJECT_DIR="$ROOT_DIR/ohos"
export CARGOKIT_VERBOSE=1

echo "==> Cargokit environment"
env | sort | rg '^CARGOKIT_|^OHOS_' || true
echo

echo "==> Running direct OHOS Rust build diagnostic"
set +e
"$PLUGIN_DIR/cargokit/run_build_tool.sh" build-cmake
status=$?
set -e

echo
echo "==> Output dir: $OUTPUT_DIR"
find "$OUTPUT_DIR" -maxdepth 3 -type f | sort || true
echo

echo "==> Target temp dir: $TEMP_DIR"
find "$TEMP_DIR" -maxdepth 5 -type f \( -name 'librust_lib_localsend_app*' -o -name 'rust_lib_localsend_app*' \) | sort || true
echo

echo "==> Known build directories under rust_builder"
find "$PLUGIN_DIR" -maxdepth 8 -type d \( -path '*/cargokit_build*' -o -path '*/.cxx/*' \) | sort || true
echo

if [ "$status" -ne 0 ]; then
  echo "OHOS Rust diagnostic build failed with exit code $status"
  exit "$status"
fi
