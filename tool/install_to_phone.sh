#!/usr/bin/env bash
# Builds the release APK and installs it on the USB-connected Android phone.
# Usage:  bash tool/install_to_phone.sh
set -euo pipefail

FLUTTER_BIN="${FLUTTER_BIN:-/c/flutter/bin/flutter}"
ADB_BIN="${ADB_BIN:-/c/Users/Admin/android/sdk/platform-tools/adb.exe}"
SDK_DIR="$(cd "$(dirname "$0")/.." && pwd)"

"$FLUTTER_BIN" analyze
"$FLUTTER_BIN" test
"$FLUTTER_BIN" build apk --release

"$ADB_BIN" install -r -d "$SDK_DIR/build/app/outputs/flutter-apk/app-release.apk"
"$ADB_BIN" shell am force-stop com.freebuff.music_player
"$ADB_BIN" shell monkey -p com.freebuff.music_player -c android.intent.category.LAUNCHER 1 >/dev/null
echo "Installed and launched com.freebuff.music_player"
