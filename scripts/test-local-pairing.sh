#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
folder=$(mktemp -d -t mochilog-local-pairing)
trap 'rm -rf "$folder"' EXIT
xcrun swiftc -parse-as-library MochiLog/Services/LocalPairingAddressPolicy.swift Tests/LocalPairingAddressTests.swift -o "$folder/tests"
"$folder/tests"
