#!/usr/bin/env python3
"""Compare battery transforms in locally extracted Apple CoreAnalytics NDJSON.

Read-only research helper. It does not download firmware, access devices, or
include firmware contents in its output. Only hashes and selected schema facts
are reported. Input is NDJSON, not a single JSON document.
"""

import argparse
import hashlib
import json
from pathlib import Path

REQUIRED = {
    "last_value_CycleCount",
    "last_value_NominalChargeCapacity",
    "last_value_AppleRawMaxCapacity",
}
MAX_FILE = 128 * 1024 * 1024
MAX_LINE = 4 * 1024 * 1024


def inspect(path: Path):
    if path.stat().st_size > MAX_FILE:
        raise ValueError("Configuration exceeds the 128 MiB research limit")
    digest = hashlib.sha256()
    transforms = {}
    transform_count = 0
    header = {}
    count = 0
    with path.open("rb") as stream:
        while raw := stream.readline(MAX_LINE + 1):
            if len(raw) > MAX_LINE:
                raise ValueError("Configuration line exceeds the 4 MiB research limit")
            digest.update(raw)
            if not raw.strip():
                continue
            row = json.loads(raw)
            count += 1
            if "header" in row:
                header = row["header"]
            transform = row.get("addTransform")
            if transform is not None:
                transform_count += 1
                name = transform["name"]
                # Unrelated event families can intentionally share names.
                # Do not silently overwrite a battery definition, however.
                if name.startswith("BatteryConfigValueHistogram"):
                    if name in transforms:
                        raise ValueError(f"Duplicate battery transform name: {name}")
                    transforms[name] = transform
    return {
        "sha256": digest.hexdigest(),
        "jsonObjects": count,
        "configType": header.get("configType"),
        "transformCount": transform_count,
        "battery": transforms,
    }


def summarize(config):
    return {
        key: value for key, value in config.items() if key != "battery"
    } | {
        "batteryTransforms": [
            {
                "name": name,
                "inputEvents": [item.get("event") for item in transform.get("inputs", [])],
                "measureCount": len(transform.get("measures", [])),
                "requiredMeasures": [
                    item for item in transform.get("measures", []) if item["name"] in REQUIRED
                ],
                "enableIf": transform.get("enableIf"),
                "outputs": transform.get("outputs", []),
            }
            for name, transform in sorted(config["battery"].items())
        ]
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("current", type=Path)
    parser.add_argument("--opt-out", type=Path)
    args = parser.parse_args()
    baseline = inspect(args.baseline)
    current = inspect(args.current)
    output = {
        "baseline": summarize(baseline),
        "current": summarize(current),
        "batteryTransformsStructurallyEqual": baseline["battery"] == current["battery"],
        "comparisonHasBatteryTransforms": bool(baseline["battery"] and current["battery"]),
    }
    if args.opt_out:
        output["optOut"] = summarize(inspect(args.opt_out))
    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
