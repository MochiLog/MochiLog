#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
binary=$(mktemp -t mochilog-catalog-export)
trap 'rm -f "$binary"' EXIT
xcrun swiftc -swift-version 5 -parse-as-library \
  MochiLog/Models/DeviceLibrary.swift MochiLog/Models/DeviceProfile.swift \
  MochiLog/Models/DeviceCatalog.swift MochiLog/Services/DeviceCatalogCache.swift \
  MochiLog/Services/DeviceProfileStore.swift scripts/ExportDeviceCatalog.swift -o "$binary"
"$binary" "$@"
