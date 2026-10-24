#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="${1:-build/review-2026-10-25/ShareMenuProbe.app}"
mkdir -p "$output"
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun --sdk iphonesimulator swiftc -j 1 -parse-as-library -sdk "$sdk" -target arm64-apple-ios16.0-simulator \
  Tests/ShareMenuProbe/Host.swift -o "$output/ShareMenuProbe"
cp Tests/Fixtures/valid-iphone.ips "$output/"
python3 - "$output" <<'PY'
from pathlib import Path
import plistlib, sys
root=Path(sys.argv[1])
info={
 'CFBundleIdentifier':'net.ryuya-dev.MochiLog.ShareMenuProbe',
 'CFBundleName':'ShareMenuProbe','CFBundleDisplayName':'共有メニュー検証',
 'CFBundleExecutable':'ShareMenuProbe','CFBundlePackageType':'APPL',
 'CFBundleShortVersionString':'1.0','CFBundleVersion':'1',
 'LSRequiresIPhoneOS':True,'MinimumOSVersion':'16.0','UIDeviceFamily':[1,2],
 'UILaunchScreen':{},
 'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},
 'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],
}
(root/'Info.plist').write_bytes(plistlib.dumps(info))
PY
codesign --force --sign - "$output"
printf 'Built isolated simulator share host: %s\n' "$output"
