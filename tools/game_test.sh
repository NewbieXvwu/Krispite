#!/bin/bash
# In-game smoke test on a real Apple Silicon Mac: launches the dev client of one loader
# in the background, straight into a pre-generated flat world, and checks that Minecraft
# renders through KosmicKrisp. Only the game window is captured, never the whole screen.
#
# Usage: ./tools/game_test.sh <fabric|neoforge> [minecraft version]
# Output: game-test-output/ (logs, crash reports, window screenshots)
set -euo pipefail

LOADER="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MC_VERSION="${2:-$(sed -n 's/^minecraft_version=//p' "$ROOT/gradle.properties")}"
RUN_DIR="$ROOT/$LOADER/run"
OUT="$ROOT/game-test-output"
WORLD="krispite-test"
JOIN_TIMEOUT="${KRISPITE_JOIN_TIMEOUT:-1200}"
RENDER_SECONDS="${KRISPITE_RENDER_SECONDS:-30}"

rm -rf "$OUT"
mkdir -p "$OUT" "$RUN_DIR/saves"

# --- 1. Generate a flat world with the matching dedicated server ---
SERVER_DIR="$(mktemp -d)"
SERVER_URL="$(python3 - "$MC_VERSION" <<'PY'
import json, sys, urllib.request
manifest = json.load(urllib.request.urlopen("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"))
version_url = next(v["url"] for v in manifest["versions"] if v["id"] == sys.argv[1])
print(json.load(urllib.request.urlopen(version_url))["downloads"]["server"]["url"])
PY
)"
curl -sSfL -o "$SERVER_DIR/server.jar" "$SERVER_URL"
echo "eula=true" > "$SERVER_DIR/eula.txt"
cat > "$SERVER_DIR/server.properties" <<'PROPS'
level-name=world
level-type=minecraft\:flat
generate-structures=false
online-mode=false
spawn-protection=0
PROPS
echo "Generating a flat $MC_VERSION world..."
(
  cd "$SERVER_DIR"
  {
    for _ in $(seq 300); do
      grep -q 'Done (' logs/latest.log 2>/dev/null && break
      sleep 1
    done
    echo stop
  } | java -jar server.jar --nogui > "$OUT/world-generation.log" 2>&1
)
rm -rf "$RUN_DIR/saves/$WORLD"
cp -R "$SERVER_DIR/world" "$RUN_DIR/saves/$WORLD"
rm -rf "$SERVER_DIR"

# Skip first-launch screens and keep rendering while the window is not focused.
cat > "$RUN_DIR/options.txt" <<'OPTS'
onboardAccessibility:false
skipMultiplayerWarning:true
tutorialStep:none
pauseOnLostFocus:false
narrator:0
soundCategory_master:0.0
renderDistance:8
OPTS
rm -rf "$RUN_DIR/logs" "$RUN_DIR/crash-reports"

# --- 2. Launch the client in the background ---
# SDL hints (read from the environment): run as an accessory app without a Dock icon
# and never take focus away from whatever the user is doing.
SDL_MAC_BACKGROUND_APP=1 \
SDL_WINDOW_ACTIVATE_WHEN_SHOWN=0 \
SDL_WINDOW_ACTIVATE_WHEN_RAISED=0 \
"$ROOT/gradlew" -p "$ROOT" ":$LOADER:runClient" \
  -Pminecraft_version="$MC_VERSION" \
  -Pkrispite.quickPlayWorld="$WORLD" \
  > "$OUT/gradle-run.log" 2>&1 &
GRADLE_PID=$!
GAME_LOG="$RUN_DIR/logs/latest.log"

# The game JVM is forked by Gradle; identify it by its working directory.
game_pid() {
  local pid
  for pid in $(pgrep -x java); do
    if [ "$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')" = "$RUN_DIR" ]; then
      echo "$pid"
      return
    fi
  done
}

# Captures only the game window (works while it is covered by other windows).
WINDOW_ID_SWIFT="$(mktemp -d)/window_id.swift"
cat > "$WINDOW_ID_SWIFT" <<'SWIFT'
import CoreGraphics
let pid = Int32(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows where (window[kCGWindowOwnerPID as String] as? Int32) == pid
    && (window[kCGWindowLayer as String] as? Int) == 0 {
    let bounds = window[kCGWindowBounds as String] as? [String: Double] ?? [:]
    if (bounds["Width"] ?? 0) >= 320 {
        print(window[kCGWindowNumber as String]!)
        break
    }
}
SWIFT
capture_window() {
  local pid window
  pid="$(game_pid)"
  [ -n "$pid" ] || { echo "warning: game process not found, no screenshot"; return 0; }
  window="$(swift "$WINDOW_ID_SWIFT" "$pid" 2>/dev/null || true)"
  [ -n "$window" ] || { echo "warning: game window not found, no screenshot"; return 0; }
  screencapture -x -o -l "$window" "$OUT/$1" || echo "warning: screencapture failed"
}

cleanup() {
  local pid
  pid="$(game_pid)"
  [ -n "$pid" ] && kill "$pid" 2>/dev/null
  kill "$GRADLE_PID" 2>/dev/null || true
  rm -rf "$(dirname "$WINDOW_ID_SWIFT")"
  cp -R "$RUN_DIR/logs" "$OUT/" 2>/dev/null || true
  cp -R "$RUN_DIR/crash-reports" "$OUT/" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1"
  capture_window failure.png
  tail -n 60 "$GAME_LOG" 2>/dev/null || tail -n 60 "$OUT/gradle-run.log"
  exit 1
}

echo "Waiting for the client to join the world (timeout ${JOIN_TIMEOUT}s)..."
for ((elapsed = 0; elapsed < JOIN_TIMEOUT; elapsed += 5)); do
  grep -q 'joined the game' "$GAME_LOG" 2>/dev/null && break
  ls "$RUN_DIR/crash-reports"/*.txt >/dev/null 2>&1 && fail "Minecraft wrote a crash report"
  kill -0 "$GRADLE_PID" 2>/dev/null || fail "Client exited before joining the world"
  sleep 5
done
grep -q 'joined the game' "$GAME_LOG" 2>/dev/null || fail "Timed out waiting for the client to join the world"

echo "Joined the world; letting it render for ${RENDER_SECONDS}s..."
sleep "$RENDER_SECONDS"
kill -0 "$GRADLE_PID" 2>/dev/null || fail "Client exited while rendering the world"
capture_window world.png

# --- 3. Verify ---
status=0
check() {
  local description="$1" pattern="$2" line
  if line="$(grep -m1 -E "$pattern" "$GAME_LOG")"; then
    echo "PASS: $description"
    echo "      $line"
  else
    echo "FAIL: $description (no log line matching '$pattern')"
    status=1
  fi
}
check "Krispite redirected LWJGL to the bundled Vulkan loader" 'LWJGL Vulkan Loader=.*kosmickrisp-mc'
check "Minecraft renders with Vulkan on KosmicKrisp" 'Using graphics backend Vulkan.*KosmicKrisp'
check "Graphics device" 'Using graphics device:'
if ls "$RUN_DIR/crash-reports"/*.txt >/dev/null 2>&1; then
  echo "FAIL: Minecraft wrote a crash report"
  status=1
fi
exit $status
