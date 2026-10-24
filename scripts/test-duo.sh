#!/bin/bash
set -euo pipefail

# Use the selected Xcode 27.1, with an optional per-command override.
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
export DEVELOPER_DIR="${DUO_DEVELOPER_DIR:-$(xcode-select -p)}"
if [[ "$(xcodebuild -version | head -1)" != "Xcode 27.1" ]]; then
  echo "Set DUO_DEVELOPER_DIR to Xcode 27.1's Contents/Developer directory." >&2
  exit 1
fi
device_id="${DUO_SIMULATOR_ID:-$(xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
matches = [d["udid"] for runtime, items in devices.items() if "iOS-27-1" in runtime
           for d in items if d["name"] == "iPhone Duo" and d.get("isAvailable")]
if len(matches) != 1:
    sys.exit("Set DUO_SIMULATOR_ID: expected exactly one available iPhone Duo on iOS 27.1.")
print(matches[0])')}"
result_dir="$repo_dir/build/duo/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$result_dir"
if [[ $# -eq 0 ]]; then
  set -- \
    -only-testing:MochiLogUITests/LanguageAndLayoutTests/testRefreshedOverviewScreens \
    -only-testing:MochiLogUITests/LanguageAndLayoutTests/testNativeDuoDetailRotationAndSharing \
    -only-testing:MochiLogUITests/LanguageAndLayoutTests/testNativeDuoDarkOverview \
    -only-testing:MochiLogUITests/LanguageAndLayoutTests/testRefreshedOverviewAtAccessibilitySize \
    -only-testing:MochiLogUITests/LanguageAndLayoutTests/testRefreshedLandscapeOverview
fi
echo "Branch: $(git branch --show-current)"
echo "Xcode: $DEVELOPER_DIR"
echo "Duo: $device_id"
echo "Results: $result_dir/Test.xcresult"
xcodebuild -project MochiLog.xcodeproj -scheme MochiLogUITests \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "${DUO_DERIVED_DATA:-$repo_dir/build/DerivedData-Duo-27.1}" \
  -collect-test-diagnostics never \
  -resultBundlePath "$result_dir/Test.xcresult" "$@" test \
  2>&1 | tee "$result_dir/test.log"
