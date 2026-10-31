#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
TEST_BINARY=$(mktemp -t mochilog-profile-tests)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 MochiLog/Models/DeviceProfile.swift MochiLog/Models/DeviceCatalog.swift MochiLog/Services/DeviceCatalogCache.swift MochiLog/Services/DeviceProfileStore.swift Tests/DeviceProfileTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
