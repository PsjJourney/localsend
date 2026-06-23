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

"$ROOT_DIR/prepare_ohos_rust.sh"
if [ -f "$HOME/.cargo/env" ]; then
  # shellcheck disable=SC1090
  . "$HOME/.cargo/env"
fi

cd "$APP_DIR"

echo "==> Flutter SDK"
flutter --version
echo

if [ -z "${OHOS_SDK_HOME:-${OHOS_BASE_SDK_HOME:-}}" ]; then
  echo "OHOS_SDK_HOME/OHOS_BASE_SDK_HOME is not set."
  echo "Set it to your HarmonyOS/OpenHarmony SDK root before building."
  exit 1
fi

echo "==> Resolving Dart and Flutter packages"
flutter pub get

echo
echo "==> Normalizing OHOS plugin hvigor files"
dart run tool/fix_ohos_plugin_hvigor.dart
node ohos/ensure-ohos-plugins.js .

echo
echo "==> Building HarmonyOS HAP"
flutter build hap --release

echo
echo "==> Output"
find build -name "*.hap" -type f 2>/dev/null | sort
