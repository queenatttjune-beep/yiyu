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
TIMEOUT_SECONDS=180

rm -rf "$OUT"
mkdir -p "$OUT/data" "$BUNDLE/Contents/MacOS"

swift build
cp "$(swift build --show-bin-path)/Yiyu" "$BUNDLE/Contents/MacOS/Yiyu"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$(plutil -extract CFBundleIdentifier raw Resources/Info.plist).tour" "$BUNDLE/Contents/Info.plist"
codesign --force --sign - "$BUNDLE" 2>/dev/null

# Fake AI and 和风天气 services on localhost, so the diary-polish and weather steps run without real keys.
MOCK_PIDS=()
trap 'kill ${APP_PID:-} ${MOCK_PIDS[@]+"${MOCK_PIDS[@]}"} 2>/dev/null || true' EXIT

# start_mock <script> <log>: starts a mock server and sets mock_port to the port it printed.
start_mock() {
  python3 -I "$1" >"$2" 2>&1 &
  MOCK_PIDS+=($!)
  mock_port=""
  for _ in $(seq 1 50); do
    mock_port="$(sed -n 's/^PORT //p' "$2" | head -1)"
    [ -n "$mock_port" ] && return 0
    sleep 0.1
  done
  echo "The mock server $1 did not start; see $2"
  exit 1
}

start_mock scripts/mock-ai-server.py "$OUT/mock-ai.log"
ai_port="$mock_port"
start_mock scripts/mock-qweather-server.py "$OUT/mock-qweather.log"
weather_port="$mock_port"

YIYU_DATA_DIR="$PWD/$OUT/data" YIYU_TOUR="$MODE" YIYU_TOUR_SHOTS="$PWD/$OUT" \
  YIYU_TOUR_AI_URL="http://127.0.0.1:$ai_port/v1" YIYU_TOUR_WEATHER_URL="http://127.0.0.1:$weather_port" \
  "$BUNDLE/Contents/MacOS/Yiyu" >"$LOG" 2>&1 &
APP_PID=$!

window=""
seen=0
deadline=$((SECONDS + TIMEOUT_SECONDS))
while [ $SECONDS -lt $deadline ]; do
  sleep 0.2
  [ -z "$window" ] && window="$(sed -n 's/^TOUR WINDOW //p' "$LOG" | head -1)"
  steps="$(grep -c '^TOUR STEP ' "$LOG" || true)"
  while [ "$seen" -lt "$steps" ]; do
    seen=$((seen + 1))
    line="$(grep '^TOUR STEP ' "$LOG" | sed -n "${seen}p")"
    name="$(echo "$line" | cut -d' ' -f3)"
    target="$(echo "$line" | cut -d' ' -f4)"
    sleep 0.5
    shot="$OUT/$(printf '%02d' "$seen")-$name.png"
    screencapture -x -o -l "${target:-$window}" "$shot.tmp" && mv "$shot.tmp" "$shot" \
      || { echo "Screenshot $name failed (window ${target:-$window})"; touch "$shot"; }
  done
  grep -q '^TOUR DONE' "$LOG" && break
done

# Two shots of heavy rain (no mist drifting) a moment apart must differ, unless Reduce Motion stills it.
before="$(ls "$OUT"/*-sky-rain.png 2>/dev/null | head -1)"
after="$(ls "$OUT"/*-sky-rain-later.png 2>/dev/null | head -1)"
if [ -s "$before" ] && [ -s "$after" ] && ! grep -q '^TOUR INFO reduce motion' "$LOG"; then
  if cmp -s "$before" "$after"; then
    echo "TOUR FAIL the rain falls" >>"$LOG"
  else
    echo "TOUR PASS the rain falls" >>"$LOG"
  fi
fi

grep -E '^TOUR (PASS|FAIL)' "$LOG" | sed 's/^TOUR //'
if ! grep -q '^TOUR DONE' "$LOG"; then
  echo "Tour did not finish within ${TIMEOUT_SECONDS}s; see $LOG"
  exit 1
fi
if grep -q '^TOUR FAIL' "$LOG"; then
  exit 1
fi
echo "All checks passed. Screenshots in $OUT/"
