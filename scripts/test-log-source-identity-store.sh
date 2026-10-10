#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
folder=$(mktemp -d -t mochilog-identity-store)
trap 'rm -rf "$folder"' EXIT
xcrun swiftc -parse-as-library MochiLog/Services/CloudSharedLogToken.swift MochiLog/Services/LogSourceIdentity.swift MochiLog/Services/LogSourceIdentityStore.swift Tests/LogSourceIdentityStoreTests.swift -o "$folder/tests"
"$folder/tests"
