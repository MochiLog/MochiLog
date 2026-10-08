#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
runtime=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x.get("isAvailable") and x["name"] == "iOS 27.0"]; assert r; print(sorted(r,key=lambda x:x["version"])[-1]["identifier"])')
mkdir -p Build
hub="$(xcode-select -p)/../Applications/DeviceHub.app"
if [[ -d "$hub" ]]; then open -a "$hub"; fi
# Bound infrastructure hangs as well as test execution; never leave a simulator
# or xcodebuild child consuming runner resources after a failed boot.
bounded() {
  python3 - "$@" <<'PY'
import os, signal, subprocess, sys
seconds = int(sys.argv[1])
child = subprocess.Popen(sys.argv[2:], start_new_session=True)
try:
    sys.exit(child.wait(timeout=seconds))
except subprocess.TimeoutExpired:
    print(f"Infrastructure timeout after {seconds}s: {sys.argv[2]}", flush=True)
    os.killpg(child.pid, signal.SIGTERM)
    try:
        child.wait(timeout=15)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGKILL)
        child.wait()
    sys.exit(124)
PY
}
device=""
failed=0
cleanup() { if [[ -n "$device" ]]; then xcrun simctl shutdown "$device" || true; xcrun simctl delete "$device"; fi; }
trap cleanup EXIT
for kind in ipad iphone; do
  if [[ "$kind" == ipad ]]; then type=iPad-Pro-13-inch-M5-12GB; else type=iPhone-17-Pro-Max; fi
  device=$(xcrun simctl create "MochiLog CI $kind" "com.apple.CoreSimulator.SimDeviceType.$type" "$runtime")
  xcrun simctl boot "$device"
  if ! bounded 300 xcrun simctl bootstatus "$device" -b > "Build/automatic-ui-$kind-boot.log" 2>&1; then
    cat "Build/automatic-ui-$kind-boot.log"; failed=1; cleanup; device=""; continue
  fi
  # Compilation can consume the full test budget on a fresh hosted runner.
  # Give compilation and actual UI execution separate bounded phases.
  if ! bounded 1200 xcodebuild build-for-testing -project MochiLog.xcodeproj -scheme MochiLogUITests \
    -destination "platform=iOS Simulator,id=$device" -derivedDataPath Build/automatic-ui-derived \
    -parallel-testing-enabled NO -jobs 2 \
    > "Build/automatic-ui-$kind-build.log" 2>&1; then
    tail -30 "Build/automatic-ui-$kind-build.log"; failed=1; cleanup; device=""; continue
  fi
  if ! bounded 900 xcodebuild test-without-building -project MochiLog.xcodeproj -scheme MochiLogUITests \
    -destination "platform=iOS Simulator,id=$device" -derivedDataPath Build/automatic-ui-derived \
    -parallel-testing-enabled NO -jobs 2 -collect-test-diagnostics never \
    -resultBundlePath "Build/automatic-ui-$kind.xcresult" \
    -only-testing:MochiLogUITests/LanguageAndLayoutTests/testAutomaticCollectionInEightLanguages \
    -only-testing:MochiLogUITests/LanguageAndLayoutTests/testLiveBatteryTabChangesWithoutRelaunch \
    > "Build/automatic-ui-$kind.log" 2>&1; then failed=1; fi
  tail -30 "Build/automatic-ui-$kind.log"
  cleanup; device=""
done
exit "$failed"
