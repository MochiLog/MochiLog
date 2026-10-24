#!/usr/bin/env python3
"""Create an isolated simulator using an installed, compatible device/OS pair."""

import argparse
import json
import subprocess
import sys


def simctl_list(kind):
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", kind, "-j"]))


def version_parts(value):
    parts = tuple(int(part) for part in value.split("."))
    return (parts + (0, 0))[:3]


def select_pair(runtimes, devices, device_types):
    available = sorted(
        (runtime for runtime in runtimes
         if runtime.get("isAvailable") and ".iOS-" in runtime["identifier"]
         and version_parts(runtime["version"]) >= (17, 0, 0)),
        key=lambda runtime: version_parts(runtime["version"]), reverse=True,
    )
    for runtime in available:
        # Existing available devices demonstrate compatibility. Create a new
        # instance of that type; never modify or boot the existing instance.
        for device in devices.get(runtime["identifier"], []):
            device_type = device.get("deviceTypeIdentifier", "")
            if device.get("isAvailable") and ".iPhone-" in device_type:
                return runtime["identifier"], device_type
        for device_type in reversed(device_types):
            if device_type.get("productFamily") != "iPhone":
                continue
            current = version_parts(runtime["version"])
            minimum = version_parts(device_type.get("minRuntimeVersionString", "0.0.0"))
            maximum = version_parts(device_type.get("maxRuntimeVersionString", "65535.255.255"))
            if minimum <= current <= maximum:
                return runtime["identifier"], device_type["identifier"]
    raise RuntimeError("No compatible installed iPhone simulator with iOS 17 or later")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    runtime, device_type = select_pair(
        simctl_list("runtimes")["runtimes"],
        simctl_list("devices")["devices"],
        simctl_list("devicetypes")["devicetypes"],
    )
    if args.dry_run:
        print(json.dumps({"runtime": runtime, "deviceType": device_type}))
        return
    print(f"Migration test simulator: {device_type}, {runtime}", file=sys.stderr)
    identifier = subprocess.check_output(
        ["xcrun", "simctl", "create", "MochiLog migration verification", device_type, runtime],
        text=True,
    ).strip()
    print(identifier)


if __name__ == "__main__":
    main()
