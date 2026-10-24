#!/usr/bin/env python3
"""Validate the OS registration contract, not just whether the plist parses."""
from pathlib import Path
import plistlib

root = Path(__file__).resolve().parents[1]
extension = plistlib.loads((root / "MochiLogShareExtension/Info.plist").read_bytes())["NSExtension"]
assert extension["NSExtensionPointIdentifier"] == "com.apple.ui-services", "Keep the file-import action in the actions list"
rule = extension["NSExtensionAttributes"]["NSExtensionActivationRule"]
assert rule["NSExtensionActivationDictionaryVersion"] == 2, "Use Apple's documented matching-version key"
assert "NSExtensionActivationRuleVersion" not in rule, "The old unrecognized key silently uses strict matching"
assert rule["NSExtensionActivationSupportsFileWithMaxCount"] == 100
print("PASS: action placement, documented v2 matching and 100-file maximum")
