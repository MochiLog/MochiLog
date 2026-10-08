#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d -t mochilog-battery-comparison)
trap 'rm -rf "$test_dir"' EXIT
# Compile the actual shared value types without UIKit / the network manager.
sed '/\/\/\/ Foreground-only, session-only current values/,$d' MochiLog/Services/LiveBatteryManager.swift \
  | sed '/^import Combine$/d; /^import Network$/d; /^import UIKit$/d' > "$test_dir/ValueTypes.swift"
xcrun swiftc -parse-as-library "$test_dir/ValueTypes.swift" \
  MochiLog/Services/LiveBatteryComparison.swift Tests/LiveBatteryComparisonTests.swift -o "$test_dir/tests"
"$test_dir/tests"
