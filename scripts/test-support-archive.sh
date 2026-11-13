#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
folder="$(mktemp -d "${TMPDIR:-/tmp}/mochilog-support-zip.XXXXXX")"
trap 'rm -rf "$folder"' EXIT
source_file="Sources/SupportArchive.swift"
if [[ -f MochiLog/Services/SupportArchive.swift ]]; then source_file="MochiLog/Services/SupportArchive.swift"; fi
module_dir="${MOCHILOG_ZIP_TEST_MODULE:-$folder/zip-module}"
if [[ ! -f "$module_dir/libZIPFoundation.dylib" ]]; then bash scripts/prepare-zip-test-module.sh "$module_dir"; fi
xcrun swiftc -I "$module_dir" -L "$module_dir" -lZIPFoundation -j 1 -warnings-as-errors -parse-as-library "$source_file" Tests/SupportArchiveTests.swift -o "$folder/tests"
"$folder/tests" "$folder/fixture"
python3 - "$folder/fixture/snapshots/mochilog-support.zip" <<'PY'
import sys, zipfile
from pathlib import PurePosixPath
with zipfile.ZipFile(sys.argv[1]) as z:
    assert z.testzip() is None, 'ZIP CRC mismatch'
    entries = [i for i in z.infolist() if not i.is_dir() and not i.filename.startswith('__MACOSX/')]
    assert {PurePosixPath(i.filename).name for i in entries} == {'pairing-v2.log','pc-transfer-v2.log','mochilog-support-manifest.json'}
    for item in entries:
        assert '..' not in PurePosixPath(item.filename).parts and not item.filename.startswith('/'), repr(item.filename)
        assert z.read(item) == ('日本語 diagnostic: ' + PurePosixPath(item.filename).name + '\n').encode()
    assert not any('private-secret' in i.filename for i in z.infolist())
print('PASS: ZIP independently opened, all entries/UTF-8 bytes/CRC matched, unrelated files excluded')
PY
