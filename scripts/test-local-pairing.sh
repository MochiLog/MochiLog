#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
folder=$(mktemp -d -t mochilog-local-pairing)
trap 'rm -rf "$folder"' EXIT
xcrun swiftc -parse-as-library MochiLog/Services/LocalPairingAddressPolicy.swift Tests/LocalPairingAddressTests.swift -o "$folder/tests"
"$folder/tests"
xcrun swiftc -parse-as-library MochiLog/Services/LocalPairingFileFormat.swift Tests/LocalPairingFileFormatTests.swift -o "$folder/format-tests"
"$folder/format-tests"
xcrun swiftc -parse-as-library MochiLog/Services/LocalCollectionProgress.swift Tests/LocalCollectionProgressTests.swift -o "$folder/progress-tests"
"$folder/progress-tests"
xcrun swiftc -parse-as-library MochiLog/Services/LocalCollectionSchedule.swift Tests/LocalCollectionScheduleTests.swift -o "$folder/schedule-tests"
"$folder/schedule-tests"
