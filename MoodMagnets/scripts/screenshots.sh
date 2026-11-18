#!/usr/bin/env bash
# Launches Mood Magnets in each posture on a simulator and saves screenshots to screenshots/.
# Run scripts/ci.sh first. Uses -MMAutoSolve so the shots catch the jellies mid-solve.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="$ROOT/build"
SHOTS="$ROOT/screenshots"
BUNDLE_ID="com.tinybirdbigdreams.moodmagnets"
mkdir -p "$SHOTS"

limit() { local secs="$1"; shift; echo "+ [$secs s] $*" >&2; perl -e 'alarm shift; exec @ARGV' "$secs" "$@"; }

CONDITIONS="$(cat "$OUT/conditions.txt" 2>/dev/null || echo DEBUG)"
PHONE="$("$ROOT/scripts/pick-simulator.sh" phone)"
SPREAD="$("$ROOT/scripts/pick-simulator.sh" spread)"
xcrun simctl boot "$SPREAD" 2>/dev/null || true

xcodebuild \
  -project MoodMagnets.xcodeproj \
  -scheme MoodMagnets \
  -destination "id=$PHONE" \
  -derivedDataPath "$OUT/DerivedData" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="$CONDITIONS" \
  CODE_SIGNING_ALLOWED=NO \
  build -quiet
APP="$(find "$OUT/DerivedData/Build/Products" -maxdepth 2 -name 'MoodMagnets.app' -path '*iphonesimulator*' | head -n 1)"

prepare() {
  local udid="$1"
  limit 60 xcrun simctl boot "$udid" 2>/dev/null || true
  limit 600 xcrun simctl bootstatus "$udid" -b >/dev/null || echo "bootstatus timed out; continuing" >&2
  limit 30 xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
  limit 300 xcrun simctl install "$udid" "$APP"
}

# shoot <udid> <name> <seconds-after-launch> [launch args...]
shoot() {
  local udid="$1" name="$2" wait="$3"; shift 3
  limit 30 xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  limit 240 xcrun simctl launch "$udid" "$BUNDLE_ID" -MMResetProgress -MMUnlockAll "$@" >/dev/null || { echo "launch failed for $name" >&2; return 1; }
  sleep "$wait"
  limit 90 xcrun simctl io "$udid" screenshot --type=png "$SHOTS/$name.png" || { echo "screenshot failed for $name" >&2; return 1; }
  echo "saved screenshots/$name.png"
}

FAILED=""
prepare "$PHONE"
shoot "$PHONE" warmup 12 >/dev/null 2>&1 || true
rm -f "$SHOTS/warmup.png"
shoot "$PHONE" home 5 || FAILED="$FAILED home"
shoot "$PHONE" level-04-start 3 -MMStartLevel 4 -MMPostureOverride closed || FAILED="$FAILED l4"
shoot "$PHONE" level-04-solving 5 -MMStartLevel 4 -MMPostureOverride closed -MMAutoSolve || FAILED="$FAILED l4s"
shoot "$PHONE" level-05-hop 3.6 -MMStartLevel 5 -MMPostureOverride closed -MMAutoSolve || FAILED="$FAILED l5"
shoot "$PHONE" level-10-won 7 -MMStartLevel 10 -MMPostureOverride closed -MMAutoSolve || FAILED="$FAILED l10"

if [ "$SPREAD" != "$PHONE" ]; then
  prepare "$SPREAD" || FAILED="$FAILED spread-device"
fi
shoot "$SPREAD" warmup 20 -MMStartLevel 9 -MMPostureOverride book >/dev/null 2>&1 || true
rm -f "$SHOTS/warmup.png"
shoot "$SPREAD" book-level-09 6 -MMStartLevel 9 -MMPostureOverride book -MMAutoSolve || FAILED="$FAILED book"
shoot "$SPREAD" laptop-level-06 5 -MMStartLevel 6 -MMPostureOverride laptop -MMAutoSolve || FAILED="$FAILED laptop"
shoot "$SPREAD" tent-level-08 5 -MMStartLevel 8 -MMPostureOverride tent -MMAutoSolve || FAILED="$FAILED tent"

xcrun simctl shutdown "$PHONE" 2>/dev/null || true
xcrun simctl shutdown "$SPREAD" 2>/dev/null || true
[ -n "$FAILED" ] && echo "Screenshots that failed:$FAILED" >&2
ls -la "$SHOTS"
