#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
TEST_BINARY=$(mktemp -t mochilog-watch-tests)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 Shared/WatchRecordSnapshot.swift "MochiLog Watch App/WatchBatteryRecord.swift" Tests/WatchRecordTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
