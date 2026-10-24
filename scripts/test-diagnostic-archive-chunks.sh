#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
folder=$(mktemp -d -t mochilog-archive-chunks)
trap 'rm -rf "$folder"' EXIT
xcrun swiftc -j 1 -parse-as-library MochiLog/Services/DiagnosticArchiveChunk.swift Tests/DiagnosticArchiveChunkTests.swift -o "$folder/tests"
"$folder/tests"
