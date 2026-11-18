#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
folder="$(mktemp -d "${TMPDIR:-/tmp}/mochilog-pairing-support.XXXXXX")"
trap 'rm -rf "$folder"' EXIT
export MOCHILOG_TRANSFER_TEST_ROOT="$folder"
xcrun swiftc -j 1 -warnings-as-errors -parse-as-library MochiLog/Services/PCTransferRecoveryPolicy.swift Tests/PCTransferRecoveryTests.swift -o "$folder/recovery"
"$folder/recovery"
xcrun swiftc -j 1 -warnings-as-errors -parse-as-library MochiLog/Services/ProgressDeadline.swift Tests/ProgressDeadlineTests.swift -o "$folder/deadline"
"$folder/deadline"
xcrun swiftc -j 1 -warnings-as-errors -parse-as-library \
  MochiLog/Services/PCConnectionFailure.swift MochiLog/Services/NetworkAccessDiagnostics.swift MochiLog/Services/PairingTransport.swift Tests/PairingTransportTests.swift -o "$folder/transport"
"$folder/transport"
xcrun swiftc -j 1 -warnings-as-errors -parse-as-library \
  MochiLog/Services/DiagnosticLogArchive.swift MochiLog/Services/SupportLogExport.swift \
  Tests/SupportLogExportTests.swift -o "$folder/export"
"$folder/export"

xcrun swiftc -j 1 -warnings-as-errors -parse-as-library MochiLog/Services/PCConnectionFailure.swift MochiLog/Services/NetworkAccessDiagnostics.swift MochiLog/Services/SupportSettingsSnapshot.swift Tests/SupportSettingsTests.swift -o "$folder/settings"
MOCHILOG_TRANSFER_TEST_ROOT="$folder" "$folder/settings"
bash scripts/test-support-archive.sh
