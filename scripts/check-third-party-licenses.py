#!/usr/bin/env python3
"""Keep the iOS license screen aligned with its resolved Swift packages."""

import json
from pathlib import Path
import re


root = Path(__file__).resolve().parents[1]
resolved = json.loads((root / "MochiLog.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())
packages = {pin["identity"].lower() for pin in resolved["pins"]}
screen = (root / "MochiLog/Views/Settings/LicenseView.swift").read_text()
displayed = {name.lower() for name in re.findall(r'LicenseInfo\(\s*name:\s*"([^"]+)"', screen)}
displayed.discard("mochilog")
displayed.discard("idevice and native dependencies")
if not (root / "MochiLog/Resources/LICENSE-LocalDiagnostics.txt").is_file():
    raise SystemExit("Native diagnostics dependency notices are missing")
if packages != displayed:
    raise SystemExit(f"iOS license screen mismatch: missing={sorted(packages - displayed)}, "
                     f"extra={sorted(displayed - packages)}")
project = (root / "MochiLog.xcodeproj/project.pbxproj").read_text()
if "LICENSE in Resources" not in project:
    raise SystemExit("The MochiLog GPL license is not bundled in the app target.")
print(f"Verified license entries for {len(packages)} Swift package dependencies and MochiLog.")
