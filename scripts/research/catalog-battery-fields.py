#!/usr/bin/env python3
"""Inventory battery definitions without exporting any device readings.

Inputs are a locally extracted Apple NDJSON configuration, MochiLog's parser,
and reviewed semantic notes. Firmware is not downloaded. No device is queried.
Unknown units and meanings remain explicitly unknown, rather than being inferred
from field names. This is a research artifact generator, not a runtime parser.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat

MAX_FILE = 128 * 1024 * 1024
MAX_LINE = 4 * 1024 * 1024


def reject_constant(value):
    raise ValueError(f"Non-JSON numeric constant: {value}")


def bounded_lines(path):
    # A mistakenly supplied FIFO must not block before the regular-file check.
    descriptor = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
    with os.fdopen(descriptor, "rb") as stream:
        descriptor = stream.fileno()
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_size > MAX_FILE:
            raise ValueError("Expected a regular file of at most 128 MiB")
        while raw := stream.readline(MAX_LINE + 1):
            if len(raw) > MAX_LINE:
                raise ValueError("Input line exceeds 4 MiB")
            yield raw
        after = os.fstat(descriptor)
        if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
            raise ValueError("Input changed during inventory")


def load_transforms(path):
    digest = hashlib.sha256()
    transforms = []
    names = set()
    for raw in bounded_lines(path):
        digest.update(raw)
        if not raw.strip():
            continue
        row = json.loads(raw, parse_constant=reject_constant)
        transform = row.get("addTransform", {})
        name = transform.get("name", "")
        if not name.startswith("BatteryConfigValueHistogram"):
            continue
        if name in names:
            raise ValueError("Duplicate battery transform name")
        names.add(name)
        transforms.append(transform)
    if not transforms:
        raise ValueError("No battery transforms found")
    return digest.hexdigest(), transforms


def source_fields(expression):
    """Extract explicit getEventField operands, not arbitrary string literals."""
    found = set()
    if isinstance(expression, list):
        for index, item in enumerate(expression):
            if item == ":getEventField" and index and isinstance(expression[index - 1], str):
                found.add(expression[index - 1])
            if isinstance(item, list):
                found.update(source_fields(item))
    return sorted(found)


def catalog(configuration, parser_source, notes, firmware="unverified"):
    digest, transforms = load_transforms(configuration)
    decoded = sorted(set(re.findall(r"let (last_value_\w+):", parser_source)))
    fields = {}
    for transform in sorted(transforms, key=lambda item: item["name"]):
        for role in ("dimensions", "measures"):
            for definition in transform.get(role, []):
                key = definition["name"]
                field = fields.setdefault(key, {"name": key, "definitions": []})
                field["definitions"].append(
                    {
                        "transform": transform["name"],
                        "role": role,
                        "type": definition.get("type"),
                        "aggregation": definition.get("function"),
                        "inputFields": source_fields(definition.get("expression")),
                    }
                )
    for key in decoded:
        fields.setdefault(key, {"name": key, "definitions": []})
    default = {
        "meaning": "内部項目。名前以外に意味を確定する証拠は未取得。",
        "unit": "未確定",
        "timeBasis": "lastは集計入力の最後の値。値自体の日次・累積は未確定。",
        "confidence": "unknown",
        "evidence": ["27.2 CoreAnalytics configuration: field definition only"],
    }
    for key, field in fields.items():
        field["parserDecoded"] = key in decoded
        field.update(default | notes.get(key, {}))
    stale = sorted(set(notes) - set(fields))
    if stale:
        raise ValueError("Semantic notes refer to absent fields: " + ", ".join(stale))
    return {
        "formatVersion": 1,
        "researchDate": "2026-11-19",
        "firmware": firmware,
        "configurationSHA256": digest,
        "scope": "All selected battery transform measures/dimensions and all parser-declared battery fields; no readings",
        "parserDeclaredBatteryFieldCount": len(decoded),
        "transformCount": len(transforms),
        "transforms": [
            {
                "name": t["name"],
                "inputEvents": [i.get("event") for i in t.get("inputs", [])],
                "measureCount": len(t.get("measures", [])),
                "dimensionCount": len(t.get("dimensions", [])),
                "explicitAggPeriod": t.get("aggPeriod"),
                "explicitCollectionCadence": t.get("collectionCadence"),
                "periodResolution": "collectionCadence > aggPeriod > Daily; outputs.sink is independent",
                "conditional": t.get("enableIf") is not None,
            }
            for t in sorted(transforms, key=lambda item: item["name"])
        ],
        "fields": [fields[k] for k in sorted(fields)],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("configuration", type=Path)
    parser.add_argument("--parser", type=Path, required=True)
    parser.add_argument("--notes", type=Path, required=True)
    parser.add_argument("--firmware", required=True, help="Verified product / OS / build of the input")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    parser_source = b"".join(bounded_lines(args.parser)).decode("utf-8")
    notes = json.loads(b"".join(bounded_lines(args.notes)), parse_constant=reject_constant)
    result = catalog(args.configuration, parser_source, notes, args.firmware)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{len(result['fields'])} fields; {result['parserDeclaredBatteryFieldCount']} parser declarations")


if __name__ == "__main__":
    main()
