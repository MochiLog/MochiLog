#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_binary=$(mktemp -t mochilog-selected-record-deletion)
trap 'rm -f "$test_binary"' EXIT
xcrun swiftc -j 1 -swift-version 5 -parse-as-library \
  MochiLog/Models/BatteryRecord.swift \
  MochiLog/Services/ExactDuplicateRecords.swift \
  MochiLog/Services/SelectedRecordDeletion.swift \
  Tests/SelectedRecordDeletionTests.swift -o "$test_binary"
"$test_binary"
