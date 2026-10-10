#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
folder=$(mktemp -d -t mochilog-cloud-sharing)
trap 'rm -rf "$folder"' EXIT
xcrun swiftc -parse-as-library MochiLog/Services/CloudSharedLogToken.swift MochiLog/Services/CloudSharingCapability.swift MochiLog/Services/LogSourceIdentity.swift Tests/CloudSharedLogTests.swift -o "$folder/tests"
"$folder/tests"
