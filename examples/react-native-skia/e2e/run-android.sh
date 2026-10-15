#!/usr/bin/env bash
# Runs the on-device checks (src/E2E.tsx) on the connected Android device or emulator:
# installs the APK, opens gltransitions://e2e and waits for the "GLT_E2E done" line.
# Usage: e2e/run-android.sh [apk] [output dir]   (from examples/react-native-skia)
# Writes results.txt (the GLT_E2E lines), logcat.txt and screen.png to the output dir.
set -uo pipefail

APK=${1:-android/app/build/outputs/apk/release/app-release.apk}
OUT=${2:-e2e-output}
APP=com.gltransitions.example
mkdir -p "$OUT"

# Right after boot, adb can answer "device offline" for a moment.
for attempt in 1 2 3 4 5; do
  adb wait-for-device install -r "$APK" && break
  [ "$attempt" = 5 ] && exit 1
  sleep 5
done
adb logcat -c
# Streamed to a file from the start: the device's log buffer can rotate during a long run.
adb logcat > "$OUT/logcat.txt" &
logcat=$!
trap 'kill $logcat 2> /dev/null' EXIT
adb shell am start -W -a android.intent.action.VIEW -d "gltransitions://e2e" "$APP"

deadline=$((SECONDS + 600))
until grep -q "GLT_E2E done" "$OUT/logcat.txt"; do
  if [ "$SECONDS" -gt "$deadline" ]; then echo "Timed out"; break; fi
  if ! adb shell pidof "$APP" > /dev/null; then echo "The app exited"; break; fi
  sleep 5
done

adb exec-out screencap -p > "$OUT/screen.png"
sleep 1 # lets the last lines reach the file
kill $logcat
grep -o "GLT_E2E.*" "$OUT/logcat.txt" | sed 's/^GLT_E2E //' > "$OUT/results.txt"
grep -v "^ok " "$OUT/results.txt"
# Passes only when every check passed: "done: N/N passed".
grep -Eq "^done: ([0-9]+)/\1 passed" "$OUT/results.txt"
