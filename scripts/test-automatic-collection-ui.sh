#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
runtime=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x.get("isAvailable") and x["name"].startswith("iOS 27")]; assert r; print(sorted(r,key=lambda x:x["version"])[-1]["identifier"])')
device=""
cleanup() { if [[ -n "$device" ]]; then xcrun simctl shutdown "$device" || true; xcrun simctl delete "$device"; fi; }
trap cleanup EXIT
for kind in ipad iphone; do
  if [[ "$kind" == ipad ]]; then type=iPad-Pro-13-inch-M5-12GB; else type=iPhone-17-Pro-Max; fi
  device=$(xcrun simctl create "MochiLog CI $kind" "com.apple.CoreSimulator.SimDeviceType.$type" "$runtime")
  xcodebuild test -project MochiLog.xcodeproj -scheme MochiLogUITests \
    -destination "platform=iOS Simulator,id=$device" -derivedDataPath Build/automatic-ui-derived \
    -parallel-testing-enabled NO -jobs 2 -collect-test-diagnostics never \
    -resultBundlePath "Build/automatic-ui-$kind.xcresult" \
    -only-testing:MochiLogUITests/LanguageAndLayoutTests/testAutomaticCollectionInEightLanguages \
    -only-testing:MochiLogUITests/LanguageAndLayoutTests/testLiveBatteryTabChangesWithoutRelaunch
  cleanup; device=""
done
