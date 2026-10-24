#!/usr/bin/env bash
# Run the real Core Data and SwiftData migrations in a disposable simulator.
# Usage: bash scripts/test-record-migrations.sh SIMULATOR_UDID
set -euo pipefail
cd "$(dirname "$0")/.."
simulator_id="${1:?Pass the UDID of a disposable iOS simulator (not a physical device)}"
python3 - "$simulator_id" <<'PY'
import json, subprocess, sys
devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))
assert any(d['udid'] == sys.argv[1] for rows in devices['devices'].values() for d in rows), 'Not an available simulator'
PY
result_directory="build/record-migrations-$(date +%Y%m%d-%H%M%S)"
xcodebuild test -project MochiLog.xcodeproj -scheme MochiLogMigrations \
  -configuration Debug -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "${MIGRATION_DERIVED_DATA:-build/record-migrations-derived}" \
  -resultBundlePath "$result_directory.xcresult" \
  -parallel-testing-enabled NO -jobs 1 \
  CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
