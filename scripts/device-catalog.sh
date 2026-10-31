#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tools
binary="$PWD/build/tools/DeviceCatalogSigner"
if [ ! -x "$binary" ] || [ MochiLog/Models/DeviceProfile.swift -nt "$binary" ] || \
  [ MochiLog/Models/DeviceCatalog.swift -nt "$binary" ] || [ scripts/DeviceCatalogSigner.swift -nt "$binary" ]; then
  xcrun swiftc -swift-version 5 -parse-as-library \
    MochiLog/Models/DeviceProfile.swift MochiLog/Models/DeviceCatalog.swift \
    scripts/DeviceCatalogSigner.swift -o "$binary.next"
  codesign --force --sign - --identifier net.ryuya-dev.MochiLog.DeviceCatalogSigner "$binary.next"
  mv "$binary.next" "$binary"
fi
"$binary" "$@"
