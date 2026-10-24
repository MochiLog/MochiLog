#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_binary=$(mktemp -t mochilog-device-library)
trap 'rm -f "$test_binary"' EXIT
xcrun swiftc -j 1 -swift-version 5 -parse-as-library \
  MochiLog/Models/DeviceLibrary.swift MochiLog/Models/DeviceProfile.swift \
  MochiLog/Services/DeviceProfileStore.swift \
  MochiLog/Migrations/Migration_v3_WatchSeries3Capacity.swift Tests/DeviceLibraryTests.swift -o "$test_binary"
"$test_binary"
