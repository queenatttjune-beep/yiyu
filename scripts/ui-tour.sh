#!/usr/bin/env bash
# UI smoke test: builds a debug copy of 一隅 (separate bundle id, throwaway data folder),
# lets it drive its own panel (see Sources/Yiyu/App/DebugTour.swift) and screenshots the
# panel window at every step into build/tour/. Exits non-zero if any check fails.
#
#   ./scripts/ui-tour.sh                 gallery: switches pages in code, never takes the keyboard
#   ./scripts/ui-tour.sh --interactive   also clicks and types; the panel holds the keyboard for
#                                        ~15 s, so don't type anywhere on the Mac while it runs
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="gallery"
if [ "${1:-}" = "--interactive" ]; then
  MODE="interactive"
  echo "Interactive tour: the test panel will take keyboard focus for ~15 s."
fi

OUT="build/tour"
BUNDLE="$OUT/一隅-tour.app"
LOG="$OUT/tour.log"
TIMEOUT_SECONDS=90

rm -rf "$OUT"
mkdir -p "$OUT/data" "$BUNDLE/Contents/MacOS"

swift build
cp "$(swift build --show-bin-path)/Yiyu" "$BUNDLE/Contents/MacOS/Yiyu"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$(plutil -extract CFBundleIdentifier raw Resources/Info.plist).tour" "$BUNDLE/Contents/Info.plist"
codesign --force --sign - "$BUNDLE" 2>/dev/null

YIYU_DATA_DIR="$PWD/$OUT/data" YIYU_TOUR="$MODE" "$BUNDLE/Contents/MacOS/Yiyu" >"$LOG" 2>&1 &
APP_PID=$!
trap 'kill "$APP_PID" 2>/dev/null || true' EXIT

window=""
seen=0
deadline=$((SECONDS + TIMEOUT_SECONDS))
while [ $SECONDS -lt $deadline ]; do
  sleep 0.2
  [ -z "$window" ] && window="$(sed -n 's/^TOUR WINDOW //p' "$LOG" | head -1)"
  steps="$(grep -c '^TOUR STEP ' "$LOG" || true)"
  while [ "$seen" -lt "$steps" ]; do
    seen=$((seen + 1))
    name="$(grep '^TOUR STEP ' "$LOG" | sed -n "${seen}p" | cut -d' ' -f3)"
    sleep 0.5
    screencapture -x -o -l "$window" "$OUT/$(printf '%02d' "$seen")-$name.png"
  done
  grep -q '^TOUR DONE' "$LOG" && break
done

grep -E '^TOUR (PASS|FAIL)' "$LOG" | sed 's/^TOUR //'
if ! grep -q '^TOUR DONE' "$LOG"; then
  echo "Tour did not finish within ${TIMEOUT_SECONDS}s; see $LOG"
  exit 1
fi
if grep -q '^TOUR FAIL' "$LOG"; then
  exit 1
fi
echo "All checks passed. Screenshots in $OUT/"
