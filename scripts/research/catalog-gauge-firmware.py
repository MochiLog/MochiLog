#!/usr/bin/env python3
"""Extract static gauge configuration evidence; never contact a device.

Only the three firmware hashes audited in the accompanying research report are
accepted. Offsets from one gauge must not be applied to a different firmware.
The output contains configuration constants and hashes, not firmware payloads
or readings from a user's battery.
"""

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import stat
import struct


PROFILES = {
    "6b13c4970f2eeeae0331d470aa7f7128ce395baa22f40ed2bf227ea0381f4456": {
        "name": "Veridian X1861 / 109060052",
        "firmwareVersion": 109060052,
        "firmwareBytes": 69632,
        "counterIncrementFunction": "0xe4e0",
        "highSoc": {
            "socThresholdsQ29": [0x1CCCCCCD, 0x1E666666],
            "temperatureUpperBoundsKelvinQ17": [
                0x2544CCD, 0x25E4CCD, 0x2684CCD, 0x2724CCD, 0x7FFFFFFF,
            ],
            "origin": "instruction immediates, not chemistry configuration",
        },
        "lvr": {
            "voltageBoundsQ17": [0, 0x56666, 0x5B333, 0x60000],
            "temperatureBoundsKelvinQ17": [0, 0x25E4CCD, 0x2724CCD, 0x7FFFFFFF],
            "absoluteCurrentBoundsQ17": [0, 0x3333, 0x40000, 0x280000],
            "origin": "instruction immediates, not chemistry configuration",
            "rawSecondsPerCount": 1,
        },
    },
    "b5b468f0bd6d6a40345ef8c0260d435dd52ee9d617c8799f5b2b61aee4c65d9e": {
        "name": "Volchok X3357 / 209200028",
        "firmwareVersion": 209200028,
        "firmwareBytes": 98304,
        "counterIncrementFunction": "0x16146",
        "configurationBase": 0xA000,
        "highSocOffsets": {
            "socThresholdsQ29": [0xA150, 2],
            "temperatureUpperBoundsKelvinQ17": [0xA158, 5],
        },
        "lvrOffsets": {
            "voltageBoundsQ17": [0xBD20, 4],
            "temperatureBoundsKelvinQ17": [0xBD30, 4],
            "absoluteCurrentBoundsQ17": [0xBD40, 4],
        },
        "lvrSecondsPerCount": 0.01,
    },
    "08f806b766d395fe7d928460be0a0d32736229f786872768ec4bdbf4cbf50bb7": {
        "name": "Volchok X3528 / 209400036",
        "firmwareVersion": 209400036,
        "firmwareBytes": 98304,
        "counterIncrementFunction": "0x1602e",
        "configurationBase": 0xA000,
        "highSocOffsets": {
            "socThresholdsQ29": [0xA150, 2],
            "temperatureUpperBoundsKelvinQ17": [0xA158, 5],
        },
        "lvrOffsets": {
            "voltageBoundsQ17": [0xBD20, 4],
            "temperatureBoundsKelvinQ17": [0xBD30, 4],
            "absoluteCurrentBoundsQ17": [0xBD40, 4],
        },
        "lvrSecondsPerCount": 1,
    },
}


def bounded_file(path):
    path = Path(path)
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_size > 2 * 1024 * 1024:
        raise ValueError("Expected a regular FirmwareMap.plist of at most 2 MiB")
    return path.read_bytes()


def verified_payload(record, size):
    payload = record["payload"]
    if not isinstance(payload, bytes) or len(payload) != size:
        raise ValueError("Unexpected payload size")
    digest = hashlib.sha256(payload).digest()
    if record.get("Digest") != digest:
        raise ValueError("Payload does not match its embedded digest")
    return payload, digest.hex()


def constants(configuration, base, offsets):
    result = {}
    for field, (address, count) in offsets.items():
        offset = address - base
        if offset < 0 or offset + count * 4 > len(configuration):
            raise ValueError("Configuration address is outside payload")
        result[field] = list(struct.unpack_from(f"<{count}i", configuration, offset))
    return result


def catalog(document):
    result = {
        "formatVersion": 1,
        "scope": "Static firmware/configuration evidence; no device measurements",
        "profiles": [],
    }
    for hardware, record in sorted(document["hw_version"].items()):
        firmware = record["firmware"]
        payload = firmware["payload"]
        if not isinstance(payload, bytes):
            raise ValueError("Firmware payload must be bytes")
        digest = hashlib.sha256(payload).hexdigest()
        if digest not in PROFILES:
            raise ValueError("Unaudited firmware; refusing to infer layout or units")
        profile = PROFILES[digest]
        verified_payload(firmware, profile["firmwareBytes"])
        if firmware["version"] != profile["firmwareVersion"]:
            raise ValueError("Firmware version/hash disagreement")
        configurations = []
        threshold_sets = {}
        for chemistry, entry in sorted(record["chemistry"].items()):
            if "configuration" not in entry:
                continue
            configuration, config_hash = verified_payload(entry["configuration"], 8192)
            item = {"chemistryID": chemistry, "configurationSHA256": config_hash}
            if "configurationBase" in profile:
                thresholds = {}
                thresholds["highSoc"] = constants(
                    configuration, profile["configurationBase"], profile["highSocOffsets"]
                )
                thresholds["lowVoltageResidency"] = constants(
                    configuration, profile["configurationBase"], profile["lvrOffsets"]
                )
                thresholds["lowVoltageResidency"]["rawSecondsPerCount"] = profile["lvrSecondsPerCount"]
                canonical = json.dumps(thresholds, sort_keys=True, separators=(",", ":"))
                identifier = hashlib.sha256(canonical.encode()).hexdigest()
                threshold_sets[identifier] = thresholds
                item["thresholdSetSHA256"] = identifier
            configurations.append(item)
        item = {
            "profile": profile["name"], "hardwareVersion": hardware,
            "firmwareVersion": firmware["version"], "firmwareSHA256": digest,
            "firmwareBytes": len(payload), "configurations": configurations,
        }
        if "configurationBase" not in profile:
            item["highSoc"] = profile["highSoc"]
            item["lowVoltageResidency"] = profile["lvr"]
        else:
            item["configurationBase"] = hex(profile["configurationBase"])
            item["thresholdSets"] = threshold_sets
        result["profiles"].append(item)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("firmware_map", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = catalog(plistlib.loads(bounded_file(args.firmware_map)))
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
