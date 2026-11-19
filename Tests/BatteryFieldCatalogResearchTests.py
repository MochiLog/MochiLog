"""Research catalog coverage and privacy boundaries, using synthetic inputs."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(
        name.replace("-", "_"), ROOT / "scripts/research" / (name + ".py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


catalog = load("catalog-battery-fields")
additional = load("catalog-additional-metrics")


class BatteryFieldCatalogResearchTests(unittest.TestCase):
    def test_missing_definition_is_preserved_and_unknown_is_not_guessed(self):
        transform = {
            "name": "BatteryConfigValueHistogramFixture", "measures": [
                {"name": "last_value_Mystery", "function": "last", "type": "int",
                 "expression": ["Mystery", ":getEventField"]}
            ],
        }
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "config.ndjson"
            path.write_text(json.dumps({"addTransform": transform}) + "\n")
            result = catalog.catalog(path, "let last_value_Absent: Int?", {})
        fields = {f["name"]: f for f in result["fields"]}
        self.assertEqual(fields["last_value_Absent"]["definitions"], [])
        self.assertTrue(fields["last_value_Absent"]["parserDecoded"])
        self.assertEqual(fields["last_value_Mystery"]["confidence"], "unknown")
        self.assertEqual(fields["last_value_Mystery"]["unit"], "未確定")
        self.assertEqual(fields["last_value_Mystery"]["definitions"][0]["inputFields"], ["Mystery"])
        self.assertEqual(catalog.source_fields(["not-a-field", ["X", ":getEventField"]]), ["X"])

    def test_duplicate_and_non_json_numbers_are_rejected(self):
        row = json.dumps({"addTransform": {"name": "BatteryConfigValueHistogramFixture"}})
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "config.ndjson"
            for text in (row + "\n" + row, '{"header":{"bad":NaN}}\n' + row):
                path.write_text(text)
                with self.subTest(text=text), self.assertRaises(ValueError):
                    catalog.load_transforms(path)

    def test_non_regular_and_oversized_inputs_are_rejected(self):
        import os

        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "input"
            os.mkfifo(path)
            with self.assertRaises(ValueError):
                list(catalog.bounded_lines(path))
            path.unlink()
            with path.open("wb") as stream:
                stream.truncate(catalog.MAX_FILE + 1)
            with self.assertRaises(ValueError):
                list(catalog.bounded_lines(path))
            path.write_bytes(b"x" * (catalog.MAX_LINE + 1))
            with self.assertRaises(ValueError):
                list(catalog.bounded_lines(path))

    def test_actual_parser_and_published_catalog_have_complete_matching_coverage(self):
        import re

        source = (ROOT / "MochiLog/Services/LogParser.swift").read_text()
        expected = set(re.findall(r"let (last_value_\w+):", source))
        published = json.loads((ROOT / "docs/research/battery-field-catalog-27.2.json").read_text())
        actual = {f["name"] for f in published["fields"] if f["parserDecoded"]}
        self.assertEqual(expected, actual)
        self.assertEqual(len(published["fields"]), len({f["name"] for f in published["fields"]}))
        self.assertTrue(all(f["meaning"] and f["unit"] and f["timeBasis"] and f["evidence"]
                            for f in published["fields"]))

    def test_additional_export_excludes_private_values(self):
        rows = [{"addTransform": {
            "name": name, "measures": [{"name": "fixture", "function": "sum",
                                          "expression": ["fixture", ":getEventField"]}]
        }} for name in additional.SELECTED]
        private = {name: {
            "files": 1, "rows": 2, "fields": {"fixture": 2},
            "numeric": {"fixture": {"min": 991837463, "max": 991837463}},
            "groups": {"private-device-id": "private-device-name"},
            "raw": "private-measurement-secret",
        } for name in additional.SELECTED}
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "config.ndjson"
            path.write_text("\n".join(json.dumps(r) for r in rows))
            result = additional.export(path, private)
        encoded = json.dumps(result)
        for secret in ("991837463", "private-device-id", "private-device-name", "private-measurement-secret"):
            self.assertNotIn(secret, encoded)
        self.assertEqual(result["transformDefinitions"][0]["fields"][0]["observedNonNullRows"], 2)
        with self.assertRaises(ValueError):
            additional.count(True)


if __name__ == "__main__":
    unittest.main()
