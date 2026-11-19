"""Synthetic tests for research extraction, not battery hardware behavior."""

import copy
import hashlib
import importlib.util
from pathlib import Path
import struct
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "gauge_catalog", ROOT / "scripts/research/catalog-gauge-firmware.py"
)
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)


def payload_record(payload):
    return {"payload": payload, "Digest": hashlib.sha256(payload).digest()}


class GaugeFirmwareResearchTests(unittest.TestCase):
    def fixture(self):
        firmware = b"synthetic gauge!"
        digest = hashlib.sha256(firmware).hexdigest()
        configuration = bytearray(8192)
        struct.pack_into("<2i", configuration, 0x150, 483183821, 510027366)
        struct.pack_into("<4i", configuration, 0x1D20, 0, 327680, 393216, 419430)
        entry = {"configuration": payload_record(bytes(configuration))}
        document = {"hw_version": {"fixture": {
            "firmware": dict(payload_record(firmware), version=7),
            "chemistry": {"fixture-a": entry, "fixture-b": copy.deepcopy(entry)},
        }}}
        profile = {
            "name": "synthetic", "firmwareVersion": 7, "firmwareBytes": len(firmware),
            "configurationBase": 0xA000,
            "highSocOffsets": {"socThresholdsQ29": [0xA150, 2]},
            "lvrOffsets": {"voltageBoundsQ17": [0xBD20, 4]},
            "lvrSecondsPerCount": 1,
        }
        return document, digest, profile

    def test_unaudited_firmware_is_rejected_before_interpreting_offsets(self):
        document, _, _ = self.fixture()
        with self.assertRaisesRegex(ValueError, "Unaudited firmware"):
            catalog.catalog(document)

    def test_matching_thresholds_are_grouped_without_exposing_payloads(self):
        document, digest, profile = self.fixture()
        with patch.dict(catalog.PROFILES, {digest: profile}):
            result = catalog.catalog(document)["profiles"][0]
        self.assertEqual(len(result["thresholdSets"]), 1)
        identifier = result["configurations"][0]["thresholdSetSHA256"]
        self.assertEqual(identifier, result["configurations"][1]["thresholdSetSHA256"])
        self.assertEqual(
            result["thresholdSets"][identifier]["lowVoltageResidency"]["voltageBoundsQ17"],
            [0, 327680, 393216, 419430],
        )
        self.assertNotIn("payload", repr(result))
        self.assertEqual(len(result["firmwareSHA256"]), 64)

    def test_digest_and_version_mismatches_do_not_produce_a_catalog(self):
        document, digest, profile = self.fixture()
        record = document["hw_version"]["fixture"]
        with patch.dict(catalog.PROFILES, {digest: profile}):
            record["firmware"]["version"] = 8
            with self.assertRaisesRegex(ValueError, "version/hash"):
                catalog.catalog(document)
            record["firmware"]["version"] = 7
            record["chemistry"]["fixture-a"]["configuration"]["Digest"] = bytes(32)
            with self.assertRaisesRegex(ValueError, "embedded digest"):
                catalog.catalog(document)

    def test_offsets_cannot_escape_the_configuration(self):
        for address in (0x9FFC, 0xC000, 0xBFFE):
            with self.subTest(address=address), self.assertRaises(ValueError):
                catalog.constants(bytes(8192), 0xA000, {"fixture": [address, 1]})


if __name__ == "__main__":
    unittest.main()
