#!/usr/bin/env python3
"""Read-only structural classification of CoreAnalytics NDJSON for research.

Reports no file paths, device IDs, usage payloads, or battery values. This is
not the app's admission filter or measurement parser. Classification describes
file contents; it cannot establish why an absent file was never generated.
"""

import argparse
import collections
import hashlib
import json
import os
import re
import stat
from pathlib import Path

MAX_FILE_BYTES = 64 * 1024 * 1024
MAX_LINE_BYTES = 4 * 1024 * 1024
MEASURES = (
    "last_value_CycleCount",
    "last_value_NominalChargeCapacity",
    "last_value_AppleRawMaxCapacity",
)


def classify(path):
    before = path.stat()
    if not stat.S_ISREG(before.st_mode):
        raise ValueError("Research input must be a regular file")
    if before.st_size > MAX_FILE_BYTES:
        raise ValueError("Research file limit is 64 MiB")
    digest = hashlib.sha256()
    lines = 0
    parsed_rows = 0
    errors = 0
    header_seen = False
    metadata_seen = False
    footer_seen = False
    rows_after_footer = 0
    battery_rows = 0
    complete_battery_rows = 0
    events = 0
    periods = collections.Counter()
    os_family = "unknown"
    partial_flag = "absent"
    size = 0
    with path.open("rb") as stream:
        while raw := stream.readline(MAX_LINE_BYTES + 1):
            if len(raw) > MAX_LINE_BYTES:
                raise ValueError("Research line limit is 4 MiB")
            digest.update(raw)
            size += len(raw)
            if stream.tell() > MAX_FILE_BYTES:
                raise ValueError("File grew beyond the research limit")
            lines += 1
            if not raw.strip():
                continue
            if footer_seen:
                rows_after_footer += 1
            try:
                row = json.loads(raw, parse_constant=reject_non_json_number)
            except (ValueError, UnicodeError):
                errors += 1
                continue
            if not isinstance(row, dict):
                errors += 1
                continue
            parsed_rows += 1
            if str(row.get("bug_type")) == "211" and not header_seen:
                header_seen = True
                os_version = row.get("os_version", "")
                if isinstance(os_version, str):
                    match = re.match(r"^(iPhone OS|iPad OS|Watch OS|watchOS|Apple TVOS|macOS)\b", os_version)
                    if match:
                        os_family = match.group(1)
            if row.get("_marker") == "<metadata>":
                metadata_seen = True
                if "partialDataFromDay" in row:
                    # Expose presence/type only; do not infer a boolean from a date/string.
                    partial_flag = type(row["partialDataFromDay"]).__name__
            if row.get("_marker") == "<end-of-file>":
                footer_seen = True
            if "message" not in row:
                continue
            events += 1
            period = row.get("aggregationPeriod")
            if period in ("Daily", "Weekly", "Monthly", "90Day", "Never"):
                periods[period] += 1
            elif period is not None:
                periods["other"] += 1
            message = row["message"]
            if not isinstance(message, dict) or not any(key in message for key in MEASURES):
                continue
            battery_rows += 1
            if all(type(message.get(key)) is int for key in MEASURES):
                if message[MEASURES[1]] > 0 and message[MEASURES[2]] > 0:
                    complete_battery_rows += 1
        after = os.fstat(stream.fileno())
    path_after = path.stat()
    def identity(stat):
        return stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns
    stable = identity(before) == identity(after) == identity(path_after) and size == after.st_size

    # The observed v2.4 writer emits metadata, then events, then an EOF marker.
    # Missing markers are evidence of an incomplete/different format, not proof
    # of a particular crash, transport fault, or behavior in every older OS.
    structure_complete = (
        header_seen and metadata_seen and footer_seen and not errors and not rows_after_footer
    )
    if not stable:
        kind = "changed-during-read"
    elif not size:
        kind = "zero-byte"
    elif not header_seen:
        kind = "unrecognized-analytics-header"
    elif not structure_complete:
        kind = "incomplete-or-different-format"
    elif complete_battery_rows:
        kind = "complete-format-with-battery"
    elif battery_rows:
        kind = "complete-format-with-incomplete-battery"
    elif not events:
        kind = "complete-format-without-events"
    else:
        kind = "complete-format-without-battery"
    return {
        "sha256": digest.hexdigest(),
        "bytes": size,
        "stableDuringRead": stable,
        "lines": lines,
        "jsonObjectRows": parsed_rows,
        "invalidRows": errors,
        "headerSeen": header_seen,
        "metadataSeen": metadata_seen,
        "footerSeen": footer_seen,
        "nonblankRowsAfterFooter": rows_after_footer,
        "osFamily": os_family,
        "partialDataFromDayType": partial_flag,
        "eventRows": events,
        "periods": dict(periods),
        "batteryCandidateRows": battery_rows,
        "completeBatteryRows": complete_battery_rows,
        "classification": kind,
    }


def reject_non_json_number(value):
    raise ValueError("Non-JSON numeric constant")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path)
    args = parser.parse_args()
    if len(args.files) > 200:
        parser.error("At most 200 files per invocation")
    print(json.dumps([classify(path) for path in args.files], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
