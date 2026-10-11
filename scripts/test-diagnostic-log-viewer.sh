#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
folder=$(mktemp -d -t mochilog-log-viewer)
trap 'rm -rf "$folder"' EXIT
xcrun swiftc -parse-as-library MochiLog/Services/DiagnosticLogArchive.swift MochiLog/Services/DiagnosticLogViewer.swift MochiLog/Services/ErrorLogStore.swift MochiLog/Services/ErrorLogPresentation.swift Tests/DiagnosticLogViewerTests.swift -o "$folder/tests"
"$folder/tests"
