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

rm -f "$FLUTTER_ROOT/bin/cache/shlock"* 2>/dev/null || true
rm -f "$FLUTTER_ROOT/bin/cache/lockfile" 2>/dev/null || true

flutter pub get
dart run tool/fix_ohos_plugin_hvigor.dart
flutter build hap --release
