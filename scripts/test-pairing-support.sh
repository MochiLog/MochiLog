#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
folder="$(mktemp -d "${TMPDIR:-/tmp}/mochilog-pairing-support.XXXXXX")"
trap 'rm -rf "$folder"' EXIT
xcrun swiftc -j 1 -warnings-as-errors -parse-as-library \
  MochiLog/Services/PairingTransport.swift Tests/PairingTransportTests.swift -o "$folder/transport"
"$folder/transport"
xcrun swiftc -j 1 -warnings-as-errors -parse-as-library \
  MochiLog/Services/DiagnosticLogArchive.swift MochiLog/Services/SupportLogExport.swift \
  Tests/SupportLogExportTests.swift -o "$folder/export"
"$folder/export"
