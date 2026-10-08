#!/bin/bash
# Builds the Jeya Staff Android app and puts it on the download page (staff.jeyahyperstore.in/download/).
# Phones with the app see "New version available" and update from there.
#   staff_app/tool/release_apk.sh "What changed (optional)"
# Bump `version:` in pubspec.yaml first (the +number must go up every release).
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f android/key.properties ]; then
  echo "No signing key yet — run staff_app/tool/create_release_key.sh first." >&2
  exit 1
fi
VERSION_LINE=$(grep '^version:' pubspec.yaml | awk '{print $2}')
NAME="${VERSION_LINE%%+*}"
CODE="${VERSION_LINE##*+}"
echo "Building Jeya Staff $NAME ($CODE)…"
# Every Android phone (64- and 32-bit ARM; emulator-only x86 left out). Debug symbols are kept on
# this Mac (not in the APK) to read crash reports: ~/JeyaReleases/jeya-staff/<version>/debug-info.
SYMBOLS="$HOME/JeyaReleases/jeya-staff/$NAME-$CODE/debug-info"
mkdir -p "$SYMBOLS"
flutter build apk --release --target-platform android-arm,android-arm64 --split-debug-info="$SYMBOLS"
APK="build/app/outputs/flutter-apk/app-release.apk"
export PATH="/opt/homebrew/opt/node@22/bin:$PATH"
(cd ../backend && R2_PUBLIC_BASE_URL=https://cdn.jeyahyperstore.in npx tsx src/scripts/publish-staff-apk.ts "../staff_app/$APK" "$NAME" "$CODE" "${1:-}")
echo "Done. Download page: https://staff.jeyahyperstore.in/download/"
