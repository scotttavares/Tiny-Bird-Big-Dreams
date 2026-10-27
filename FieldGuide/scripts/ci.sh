#!/usr/bin/env bash
# Generates the Xcode project, builds with a zero-warnings check, and runs the unit tests.
# Usage: scripts/ci.sh            (from anywhere; needs Xcode 26+ and xcodegen)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="$ROOT/build"
mkdir -p "$OUT"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }
xcodegen generate --quiet

# Turn on the iPhone Duo code paths only when the SDK has them (iOS 27.1+).
SDK_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-version)"
CONDITIONS="DEBUG"
if python3 -c "import sys; v=tuple(int(x) for x in sys.argv[1].split('.')); sys.exit(0 if v >= (27, 1) else 1)" "$SDK_VERSION"; then
  CONDITIONS="DEBUG FIELDGUIDE_DUO_SDK"
fi
echo "iOS Simulator SDK $SDK_VERSION → SWIFT_ACTIVE_COMPILATION_CONDITIONS='$CONDITIONS'"
echo "$CONDITIONS" > "$OUT/conditions.txt"

UDID="$("$ROOT/scripts/pick-simulator.sh" phone)"
echo "Simulator: $UDID"
echo "$UDID" > "$OUT/phone-udid.txt"

set +e
xcodebuild \
  -project FieldGuide.xcodeproj \
  -scheme FieldGuide \
  -destination "id=$UDID" \
  -derivedDataPath "$OUT/DerivedData" \
  -resultBundlePath "$OUT/FieldGuide.xcresult" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$CONDITIONS" \
  CODE_SIGNING_ALLOWED=NO \
  clean build-for-testing test-without-building 2>&1 | tee "$OUT/xcodebuild.log"
STATUS=${PIPESTATUS[0]}
set -e

# Zero-warnings bar: any compiler/asset/linker warning in our sources fails the build.
grep -E ": warning: " "$OUT/xcodebuild.log" \
  | grep -v "Metadata extraction skipped" \
  | sort -u > "$OUT/warnings.txt" || true
WARNINGS=$(wc -l < "$OUT/warnings.txt" | tr -d ' ')
echo "Warnings: $WARNINGS"
cat "$OUT/warnings.txt"

if [ "$STATUS" -ne 0 ]; then
  echo "xcodebuild failed with status $STATUS" >&2
  exit "$STATUS"
fi
if [ "$WARNINGS" -ne 0 ]; then
  echo "Build produced warnings" >&2
  exit 1
fi
echo "Build and tests passed with zero warnings."
