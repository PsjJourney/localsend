#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/app"

if [ -z "${FLUTTER_ROOT:-}" ]; then
  echo "FLUTTER_ROOT is not set."
  echo "Point it to an OHOS-enabled Flutter SDK before running this script."
  exit 1
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

cd "$APP_DIR"

echo "==> Flutter SDK"
flutter --version
echo

echo "==> flutter pub get"
flutter pub get
echo

echo "==> flutter build hap --release"
flutter build hap --release
echo

echo "==> Output"
find "$APP_DIR/build" -name "*.hap" -type f 2>/dev/null | sort
