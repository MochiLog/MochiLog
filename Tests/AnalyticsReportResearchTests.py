"""Structural research diagnostics, separate from the production parser."""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/research/classify-analytics-report.py"
SPEC = importlib.util.spec_from_file_location("analytics_report_research", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class AnalyticsReportResearchTests(unittest.TestCase):
    def test_distinguishes_absence_of_payload_from_incomplete_file(self):
        header = {"bug_type": "211", "os_version": "iPhone OS 27.2", "incident_id": "PRIVATE_SENTINEL"}
        metadata = {"_marker": "<metadata>", "version": "2.4", "deviceId": "PRIVATE_SENTINEL"}
        footer = {"_marker": "<end-of-file>"}
        battery = {
            "aggregationPeriod": "Daily",
            "message": {
                "last_value_CycleCount": 0,
                "last_value_NominalChargeCapacity": 4000,
                "last_value_AppleRawMaxCapacity": 3900,
            },
        }
        missing_capacity = {
            "aggregationPeriod": "Daily",
            "message": {"last_value_NominalChargeCapacity": None},
        }
        weekly = {"aggregationPeriod": "Weekly", "message": {"Count": 1}}
        cases = [
            ([], "zero-byte", 0),
            ([header, metadata, footer], "complete-format-without-events", 0),
            ([header, metadata, weekly, footer], "complete-format-without-battery", 0),
            ([header, metadata, battery, footer], "complete-format-with-battery", 1),
            ([header, metadata, missing_capacity, footer], "complete-format-with-incomplete-battery", 0),
            ([header, metadata, battery], "incomplete-or-different-format", 1),
            ([header, metadata, footer, battery], "incomplete-or-different-format", 1),
            ([header, metadata, "broken-json", footer], "incomplete-or-different-format", 0),
            ([{"message": {"Count": 1}}], "unrecognized-analytics-header", 0),
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "PRIVATE_SENTINEL.ips"
            for rows, expected, complete in cases:
                with self.subTest(classification=expected, rows=len(rows)):
                    path.write_text("".join(json.dumps(row) + "\n" for row in rows))
                    result = MODULE.classify(path)
                    self.assertEqual(result["classification"], expected)
                    self.assertEqual(result["completeBatteryRows"], complete)
                    self.assertTrue(result["stableDuringRead"])
                    self.assertNotIn("PRIVATE_SENTINEL", json.dumps(result))

    def test_footer_does_not_hide_a_truncated_event(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "truncated.ips"
            path.write_text(
                '{"bug_type":"211"}\n'
                '{"_marker":"<metadata>"}\n'
                '{"message":{"last_value_CycleCount":\n'
                '{"_marker":"<end-of-file>"}\n'
            )
            result = MODULE.classify(path)
            self.assertTrue(result["footerSeen"])
            self.assertEqual(result["invalidRows"], 1)
            self.assertEqual(result["classification"], "incomplete-or-different-format")


if __name__ == "__main__":
    unittest.main()
