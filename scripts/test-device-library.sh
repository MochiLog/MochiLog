#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_binary=$(mktemp -t mochilog-device-library)
trap 'rm -f "$test_binary"' EXIT
xcrun swiftc -j 1 -swift-version 5 -parse-as-library \
  MochiLog/Models/DeviceLibrary.swift MochiLog/Models/DeviceProfile.swift \
  MochiLog/Models/DeviceCatalog.swift MochiLog/Services/DeviceCatalogCache.swift MochiLog/Services/DeviceProfileStore.swift \
  MochiLog/Migrations/DeviceLibrary/DeviceLibraryMigrations.swift \
  MochiLog/Migrations/DeviceLibrary/Migration_v3_WatchSeries3Capacity.swift \
  MochiLog/Migrations/DeviceLibrary/Migration_v4_DeviceLibraryIdentity.swift \
  MochiLog/Migrations/DeviceLibrary/Migration_v5_iPadReferenceCapacity.swift \
  Tests/DeviceLibraryTests.swift -o "$test_binary"
"$test_binary"
