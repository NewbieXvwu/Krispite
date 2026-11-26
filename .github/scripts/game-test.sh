#!/bin/bash
# In-game smoke test for CI: launches the dev client of one loader straight into a
# pre-generated world and checks that Minecraft renders through KosmicKrisp.
#
# Usage: .github/scripts/game-test.sh <fabric|neoforge> <minecraft version>
set -euo pipefail

LOADER="$1"
MC_VERSION="$2"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUN_DIR="$ROOT/$LOADER/run"
OUT="$ROOT/game-test-output"
WORLD="krispite-ci"
JOIN_TIMEOUT="${KRISPITE_JOIN_TIMEOUT:-1200}"
RENDER_SECONDS="${KRISPITE_RENDER_SECONDS:-45}"

mkdir -p "$OUT" "$RUN_DIR/saves"

# --- 1. Generate a flat world with the matching dedicated server ---
SERVER_DIR="${RUNNER_TEMP:-/tmp}/krispite-server"
rm -rf "$SERVER_DIR"
mkdir -p "$SERVER_DIR"
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
echo "::group::Generate world ($MC_VERSION dedicated server)"
(
  cd "$SERVER_DIR"
  {
    for _ in $(seq 300); do
      grep -q 'Done (' logs/latest.log 2>/dev/null && break
      sleep 1
    done
    echo stop
  } | java -jar server.jar --nogui
)
echo "::endgroup::"
rm -rf "$RUN_DIR/saves/$WORLD"
cp -R "$SERVER_DIR/world" "$RUN_DIR/saves/$WORLD"

# Skip first-launch screens and keep rendering when the window is not focused.
cat > "$RUN_DIR/options.txt" <<'OPTS'
onboardAccessibility:false
skipMultiplayerWarning:true
tutorialStep:none
pauseOnLostFocus:false
narrator:0
soundCategory_master:0.0
renderDistance:8
OPTS
rm -rf "$RUN_DIR/logs" "$RUN_DIR/crash-reports" "$RUN_DIR/screenshots"

# --- 2. Launch the client ---
"$ROOT/gradlew" -p "$ROOT" ":$LOADER:runClient" \
  -Pminecraft_version="$MC_VERSION" \
  -Pkrispite.quickPlayWorld="$WORLD" \
  > "$OUT/gradle-run.log" 2>&1 &
GRADLE_PID=$!

GAME_LOG="$RUN_DIR/logs/latest.log"
cleanup() {
  kill "$GRADLE_PID" 2>/dev/null || true
  # The game JVM is forked by Gradle; find it by its working directory.
  for pid in $(pgrep -x java); do
    if [ "$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')" = "$RUN_DIR" ]; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
  cp -R "$RUN_DIR/logs" "$OUT/" 2>/dev/null || true
  cp -R "$RUN_DIR/crash-reports" "$OUT/" 2>/dev/null || true
  cp -R "$RUN_DIR/screenshots" "$OUT/" 2>/dev/null || true
  cp "$RUN_DIR/options.txt" "$OUT/" 2>/dev/null || true
  cp -R "$HOME/Library/Logs/DiagnosticReports" "$OUT/DiagnosticReports" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  echo "::error::$1"
  screencapture -x "$OUT/screen-failure.png" 2>/dev/null || true
  tail -n 80 "$GAME_LOG" 2>/dev/null || tail -n 80 "$OUT/gradle-run.log"
  exit 1
}

echo "Waiting for the client to join $WORLD (timeout ${JOIN_TIMEOUT}s)..."
captured_loading=false
for ((elapsed = 0; elapsed < JOIN_TIMEOUT; elapsed += 5)); do
  if grep -q 'joined the game' "$GAME_LOG" 2>/dev/null; then
    break
  fi
  if ! $captured_loading && grep -q 'Using graphics backend' "$GAME_LOG" 2>/dev/null; then
    captured_loading=true
    sleep 10
    screencapture -x "$OUT/screen-loading.png" || true
  fi
  if ls "$RUN_DIR/crash-reports"/*.txt >/dev/null 2>&1; then
    fail "Minecraft wrote a crash report"
  fi
  if ! kill -0 "$GRADLE_PID" 2>/dev/null; then
    fail "Client exited before joining the world"
  fi
  sleep 5
done
grep -q 'joined the game' "$GAME_LOG" 2>/dev/null || fail "Timed out waiting for the client to join the world"

echo "Joined the world; letting it render for ${RENDER_SECONDS}s..."
sleep "$RENDER_SECONDS"
kill -0 "$GRADLE_PID" 2>/dev/null || fail "Client exited while rendering the world"
screencapture -x "$OUT/screen-world.png" || echo "::warning::screencapture failed"
# Also ask the game itself for a screenshot (F2) in case screen capture is restricted.
osascript -e 'tell application "System Events" to key code 120' 2>/dev/null || true
sleep 5

# --- 3. Verify ---
status=0
check() {
  local description="$1" pattern="$2"
  if line="$(grep -m1 -E "$pattern" "$GAME_LOG")"; then
    echo "PASS: $description"
    echo "      $line"
  else
    echo "::error::FAIL: $description (no log line matching '$pattern')"
    status=1
  fi
}
check "Krispite redirected LWJGL to the bundled Vulkan loader" 'LWJGL Vulkan Loader=.*kosmickrisp-mc'
check "Minecraft selected the Vulkan backend" 'Using graphics backend Vulkan'
check "The Vulkan driver is KosmicKrisp" 'Using graphics backend Vulkan.*KosmicKrisp'
if ls "$RUN_DIR/crash-reports"/*.txt >/dev/null 2>&1; then
  echo "::error::FAIL: Minecraft wrote a crash report"
  status=1
fi

{
  echo "### $LOADER on Minecraft $MC_VERSION"
  echo '```'
  grep -m1 -E 'Using graphics backend' "$GAME_LOG" || echo "(no graphics backend line)"
  grep -m1 -E 'Using graphics device' "$GAME_LOG" || true
  grep -m1 -E 'LWJGL Vulkan Loader=' "$GAME_LOG" || echo "(no Krispite line)"
  echo '```'
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

exit $status
