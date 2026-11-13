#!/usr/bin/env bash
set -euo pipefail
module_dir="$1"
mkdir -p "$module_dir"
source_dir="${MOCHILOG_ZIPFOUNDATION_SOURCE:-}"
if [[ -z "$source_dir" ]]; then
  source_dir="$module_dir/checkout"
  git -c advice.detachedHead=false -c http.lowSpeedLimit=1 -c http.lowSpeedTime=30 clone --quiet --depth 1 --branch 0.9.20 https://github.com/weichsel/ZIPFoundation.git "$source_dir"
fi
test "$(git -C "$source_dir" rev-parse HEAD)" = 22787ffb59de99e5dc1fbfe80b19c97a904ad48d
xcrun swiftc -j 2 -emit-library -emit-module -module-name ZIPFoundation \
  "$source_dir"/Sources/ZIPFoundation/*.swift \
  -emit-module-path "$module_dir/ZIPFoundation.swiftmodule" -o "$module_dir/libZIPFoundation.dylib"
