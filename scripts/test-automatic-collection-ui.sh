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
    -only-testing:MochiLogUITests/LanguageAndLayoutTests/testCollectionProgressAndResumeInEightLanguages \
    > "Build/automatic-ui-$kind.log" 2>&1; then
    if python3 -c 'import re,sys; sys.exit(0 if re.search(r"Simulator device failed to launch .*xctrunner", open(sys.argv[1]).read()) else 1)' "Build/automatic-ui-$kind.log"; then
      # Retry only a simulator runner launch failure, never an assertion failure.
      xcrun simctl shutdown "$device"
      xcrun simctl boot "$device"
      bounded 300 xcrun simctl bootstatus "$device" -b > "Build/automatic-ui-$kind-retry-boot.log" 2>&1
      if ! bounded 900 xcodebuild test-without-building -project MochiLog.xcodeproj -scheme MochiLogUITests \
        -destination "platform=iOS Simulator,id=$device" -derivedDataPath Build/automatic-ui-derived \
        -parallel-testing-enabled NO -jobs 2 -collect-test-diagnostics never \
        -resultBundlePath "Build/automatic-ui-$kind-retry.xcresult" \
        -only-testing:MochiLogUITests/LanguageAndLayoutTests/testAutomaticCollectionInEightLanguages \
        -only-testing:MochiLogUITests/LanguageAndLayoutTests/testLiveBatteryTabChangesWithoutRelaunch \
    -only-testing:MochiLogUITests/LanguageAndLayoutTests/testCollectionProgressAndResumeInEightLanguages \
        > "Build/automatic-ui-$kind-retry.log" 2>&1; then failed=1; fi
      tail -30 "Build/automatic-ui-$kind-retry.log"
    else
      failed=1
    fi
  fi
  tail -30 "Build/automatic-ui-$kind.log"
  if ! bounded 180 python3 scripts/test-local-diagnostics-simulator.py "$device" \
    --app Build/automatic-ui-derived/Build/Products/Debug-iphonesimulator/MochiLog.app \
    --output "Build/automatic-ui-$kind-native.json" \
    > "Build/automatic-ui-$kind-native.log" 2>&1; then failed=1; fi
  cat "Build/automatic-ui-$kind-native.log"
  cleanup; device=""
done

# Reuse an installed older runtime when present; never download one here.
legacy_runtime=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x.get("isAvailable") and x["name"] == "iOS 17.0"]; print(r[0]["identifier"] if r else "")')
if [[ -n "$legacy_runtime" ]]; then
  device=$(xcrun simctl create "MochiLog CI iOS 17 boundary" com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro "$legacy_runtime")
  xcrun simctl boot "$device"
  if bounded 300 xcrun simctl bootstatus "$device" -b > Build/automatic-ui-ios17-boot.log 2>&1 && \
     bounded 1200 xcodebuild build-for-testing -project MochiLog.xcodeproj -scheme MochiLogUITests \
       -destination "platform=iOS Simulator,id=$device" -derivedDataPath Build/automatic-ui-derived -parallel-testing-enabled NO -jobs 2 \
       > Build/automatic-ui-ios17-build.log 2>&1; then
    if ! bounded 900 xcodebuild test-without-building -project MochiLog.xcodeproj -scheme MochiLogUITests \
      -destination "platform=iOS Simulator,id=$device" -derivedDataPath Build/automatic-ui-derived -parallel-testing-enabled NO -jobs 2 \
      -collect-test-diagnostics never -resultBundlePath Build/automatic-ui-ios17.xcresult \
      -only-testing:MochiLogUITests/LanguageAndLayoutTests/testDeviceAcquisitionOnOlderOS \
      > Build/automatic-ui-ios17.log 2>&1; then failed=1; fi
    tail -30 Build/automatic-ui-ios17.log
    if ! bounded 180 python3 scripts/test-local-diagnostics-simulator.py "$device" \
      --app Build/automatic-ui-derived/Build/Products/Debug-iphonesimulator/MochiLog.app \
      --output Build/automatic-ui-ios17-native.json \
      > Build/automatic-ui-ios17-native.log 2>&1; then failed=1; fi
    cat Build/automatic-ui-ios17-native.log
  else
    failed=1
    tail -30 Build/automatic-ui-ios17-build.log 2>/dev/null || true
  fi
  cleanup; device=""
else
  echo "iOS 17 runtime not installed; older-OS UI check skipped explicitly."
fi
exit "$failed"
