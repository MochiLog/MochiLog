#!/usr/bin/env python3
"""Export selected analytics schemas and counts, never observed readings.

The optional observations file is a private research inventory. Only event/field
names and aggregate non-null row counts are allowlisted for export. Its numeric
ranges, values, device groups and paths must not be copied to the public catalog.
"""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "battery_catalog", Path(__file__).with_name("catalog-battery-fields.py")
)
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)

SELECTED = {
    "CPUAndWallUptime", "JITCharging_aggregated_metrics_with_trial",
    "OBCNoRotationBatteryHealthMetricsv2", "EnergyTelemetrySummary_v3",
    "BatteryTimeAtHighSocLast", "UnpluggedDurationEnergyViewNew",
    "Battery_LowVoltageResidencyCountersLastValue", "SlowChargingReason",
    "SMCThermalKeys_90DayRotation", "thermalKeys_TH0x",
    "intervalUsageChargingParamsHistogramView_withTimeInterval",
    "BatteryHeatmapSoCAggregationViewCorrected",
    "BatteryCellDisconnectCount_Last_Value_Of_Day", "BatteryLevelReportView5",
    "massStorage_NANDInfo_FTLCounters_1", "BatteryShutdownHistogramDailyTotal",
}


def count(value):
    if type(value) is not int or value < 0:
        raise ValueError("Observation count must be a non-negative integer")
    return value


def bucket_boundaries(expression):
    found = []
    if isinstance(expression, list):
        # Preserve only literal numeric boundary arrays, not arbitrary expressions.
        for item in expression:
            if isinstance(item, list):
                if item and all(type(v) in (int, float) for v in item):
                    found.append(item)
                else:
                    found.extend(bucket_boundaries(item))
    return found


def export(configuration, observations, firmware="unverified"):
    digest = hashlib.sha256()
    entries = []
    for raw in common.bounded_lines(configuration):
        digest.update(raw)
        if not raw.strip():
            continue
        t = json.loads(raw, parse_constant=common.reject_constant).get("addTransform", {})
        name = t.get("name")
        if name not in SELECTED:
            continue
        observed = observations.get(name, {})
        fields = []
        for role in ("dimensions", "measures"):
            for field in t.get(role, []):
                key = field["name"]
                fields.append({
                    "name": key, "role": role, "type": field.get("type"),
                    "aggregation": field.get("function"),
                    "inputFields": common.source_fields(field.get("expression")),
                    "literalNumericBoundaries": bucket_boundaries(field.get("expression")),
                    "observedNonNullRows": count(observed.get("fields", {}).get(key, 0)),
                    "semantics": "See dated report; otherwise unresolved, not a unit specification",
                })
        entries.append({
            "name": name, "inputEvents": [i.get("event") for i in t.get("inputs", [])],
            "explicitAggPeriod": t.get("aggPeriod"),
            "explicitCollectionCadence": t.get("collectionCadence"),
            "conditional": t.get("enableIf") is not None,
            "observedFiles": count(observed.get("files", 0)),
            "observedRows": count(observed.get("rows", 0)),
            "fields": fields,
        })
    if SELECTED - {entry["name"] for entry in entries}:
        raise ValueError("Some selected definitions were not found")
    return {
        "formatVersion": 1, "researchDate": "2026-11-19",
        "firmware": firmware,
        "configurationSHA256": digest.hexdigest(),
        "observationScope": "Aggregate counts from the supplied inventory; see dated report for sample size and selection bias",
        "transformDefinitions": sorted(entries, key=lambda item: item["name"]),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("configuration", type=Path)
    parser.add_argument("--observations", type=Path, required=True)
    parser.add_argument("--firmware", required=True, help="Verified product / OS / build of the input")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    observations = json.loads(
        b"".join(common.bounded_lines(args.observations)), parse_constant=common.reject_constant
    )
    result = export(args.configuration, observations, args.firmware)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{len(result['transformDefinitions'])} selected definitions; no readings exported")


if __name__ == "__main__":
    main()
