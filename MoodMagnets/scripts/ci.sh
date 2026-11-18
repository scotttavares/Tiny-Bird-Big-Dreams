#!/usr/bin/env bash
# Generates the Xcode project, builds the app, and runs the unit tests on a simulator.
# Usage: scripts/ci.sh            (from anywhere; needs Xcode 16+ and xcodegen)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="$ROOT/build"
mkdir -p "$OUT"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }
xcodegen generate --quiet

# Turn on the iPhone Duo hinge code only when the SDK has it (iOS 27.1+).
SDK_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-version)"
CONDITIONS="DEBUG"
if python3 -c "import sys; v=tuple(int(x) for x in sys.argv[1].split('.')); sys.exit(0 if v >= (27, 1) else 1)" "$SDK_VERSION"; then
  CONDITIONS="DEBUG MOODMAGNETS_DUO_SDK"
fi
echo "iOS Simulator SDK $SDK_VERSION → SWIFT_ACTIVE_COMPILATION_CONDITIONS='$CONDITIONS'"
echo "$CONDITIONS" > "$OUT/conditions.txt"

UDID="$("$ROOT/scripts/pick-simulator.sh" phone)"
echo "Simulator: $UDID"

set +e
xcodebuild \
  -project MoodMagnets.xcodeproj \
  -scheme MoodMagnets \
  -destination "id=$UDID" \
  -derivedDataPath "$OUT/DerivedData" \
  -resultBundlePath "$OUT/MoodMagnets.xcresult" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$CONDITIONS" \
  CODE_SIGNING_ALLOWED=NO \
  clean build-for-testing test-without-building 2>&1 | tee "$OUT/xcodebuild.log"
STATUS=${PIPESTATUS[0]}
set -e

grep -E ": (error|warning): " "$OUT/xcodebuild.log" | grep -v "Metadata extraction skipped" | sort -u > "$OUT/diagnostics.txt" || true
echo "---- compiler diagnostics ($(wc -l < "$OUT/diagnostics.txt" | tr -d ' ')) ----"
cat "$OUT/diagnostics.txt"
grep -E "Test Case .* (passed|failed)|Executed [0-9]+ tests" "$OUT/xcodebuild.log" | tail -n 60 || true
echo "Summary: Xcode $(xcodebuild -version | sed -n '1s/^Xcode //p'), simulator SDK $SDK_VERSION, conditions '$CONDITIONS'"

if [ "$STATUS" -ne 0 ]; then
  echo "xcodebuild failed with status $STATUS" >&2
  exit "$STATUS"
fi
echo "Build and tests passed."
