#!/usr/bin/env bash
# Launches Field Guide in each posture on a simulator and saves screenshots to screenshots/.
# Run scripts/ci.sh first (it builds the app into build/DerivedData).
#
# On an SDK with the iPhone Duo simulator every posture uses it. Otherwise the closed
# posture uses an iPhone (outer display stand-in) and book/laptop/tent use an iPad
# (inner display stand-in), with the posture forced through -FGPostureOverride.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="$ROOT/build"
SHOTS="$ROOT/screenshots"
BUNDLE_ID="com.tinybirdbigdreams.fieldguide"
mkdir -p "$SHOTS"

# macOS has no GNU `timeout`; perl's alarm gives each simulator command a hard limit.
limit() { local secs="$1"; shift; echo "+ [$secs s] $*" >&2; perl -e 'alarm shift; exec @ARGV' "$secs" "$@"; }

CONDITIONS="$(cat "$OUT/conditions.txt" 2>/dev/null || echo DEBUG)"
PHONE="$("$ROOT/scripts/pick-simulator.sh" phone)"
SPREAD="$("$ROOT/scripts/pick-simulator.sh" spread)"

# A fresh iPad simulator takes minutes to boot on CI; start it now so it's warm by the time
# the iPhone shots are done.
xcrun simctl boot "$SPREAD" 2>/dev/null || true

# One app build serves both simulators (same platform).
xcodebuild \
  -project FieldGuide.xcodeproj \
  -scheme FieldGuide \
  -destination "id=$SPREAD" \
  -derivedDataPath "$OUT/DerivedData" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$CONDITIONS" \
  CODE_SIGNING_ALLOWED=NO \
  build -quiet
echo "Built app for screenshots" >&2
APP="$(find "$OUT/DerivedData/Build/Products" -maxdepth 2 -name 'FieldGuide.app' -path '*iphonesimulator*' | head -n 1)"

prepare() {
  local udid="$1"
  limit 60 xcrun simctl boot "$udid" 2>/dev/null || true
  limit 600 xcrun simctl bootstatus "$udid" -b >/dev/null || echo "bootstatus timed out; continuing" >&2
  limit 30 xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
  limit 300 xcrun simctl install "$udid" "$APP"
}

shoot() {
  local udid="$1" posture="$2" name="$3" appearance="${4:-light}"
  limit 90 xcrun simctl ui "$udid" appearance "$appearance" || true
  limit 30 xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  limit 240 xcrun simctl launch "$udid" "$BUNDLE_ID" \
    -FGInMemoryStore -FGSeedDemo -FGPostureOverride "$posture" >/dev/null || { echo "launch failed for $name" >&2; return 1; }
  sleep 8
  limit 90 xcrun simctl io "$udid" screenshot --type=png "$SHOTS/$name.png" || { echo "screenshot failed for $name" >&2; return 1; }
  echo "saved screenshots/$name.png"
}

FAILED=""
prepare "$PHONE"
shoot "$PHONE" closed closed || FAILED="$FAILED closed"
shoot "$PHONE" closed closed-dark dark || FAILED="$FAILED closed-dark"

if [ "$SPREAD" != "$PHONE" ]; then
  prepare "$SPREAD" || FAILED="$FAILED spread-device"
fi
shoot "$SPREAD" book book || FAILED="$FAILED book"
shoot "$SPREAD" book book-dark dark || FAILED="$FAILED book-dark"
shoot "$SPREAD" laptop laptop || FAILED="$FAILED laptop"
shoot "$SPREAD" tent tent || FAILED="$FAILED tent"

xcrun simctl shutdown "$PHONE" 2>/dev/null || true
xcrun simctl shutdown "$SPREAD" 2>/dev/null || true

if [ -n "$FAILED" ]; then
  echo "Screenshots that failed:$FAILED (the others were saved and will be committed)" >&2
fi
ls -la "$SHOTS"
