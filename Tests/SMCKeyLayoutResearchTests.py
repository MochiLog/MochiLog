"""Malformed-input and address-layout tests using entirely synthetic SMC tries."""

import importlib.util
from pathlib import Path
import struct
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "smc_layout", ROOT / "scripts/research/inspect-smc-key-layout.py"
)
layout = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(layout)


class SMCKeyLayoutResearchTests(unittest.TestCase):
    def fixture(self, encoding):
        data = bytearray(512)
        profile = {"root": 0x10, "metadata": 0x100, "types": 0x140, "keyCount": 2}
        # One-byte prefix followed by three-byte leaf suffixes, stored little endian.
        data[0x10:0x18] = bytes([0x0C, 1, 2, 0, ord("B"), 0x30, 0, 0])
        headers = (
            bytes([0x18, 2]),
            bytes([0x19, 2, 1, 0, 0, 2]),
            bytes([0x1A, 2, 1, 0, 0, 2]),
            bytes([0x1B, 2, 1]),
        )
        suffixes = b"PTL" + b"VTL"  # BLTP and BLTV
        addresses = (
            bytes([1, 0, 0, 2, 1, 0, 1, 2]),
            b"",
            struct.pack("<2H", 0, 0x100),
            bytes([0, 0, 2, 0, 1, 2]),
        )
        payload = headers[encoding] + suffixes + addresses[encoding]
        data[0x30:0x30 + len(payload)] = payload
        data[0x103:0x106] = bytes([40, 0, 0x84])
        data[0x140:0x144] = b"_xeh"
        return data, profile

    def test_four_encodings_preserve_ram_addresses_without_dereferencing(self):
        for encoding in range(4):
            with self.subTest(encoding=encoding):
                data, profile = self.fixture(encoding)
                records = layout.decode_trie(data, profile)
                self.assertEqual(set(records), {"BLTP", "BLTV"})
                self.assertEqual(records["BLTP"]["dataOrHandler"], "0x20000")
                expected = "0x20000" if encoding == 1 else "0x20100"
                self.assertEqual(records["BLTV"]["dataOrHandler"], expected)
                self.assertEqual(records["BLTV"]["type"], "hex_")

    def test_cycles_and_out_of_image_branches_are_rejected(self):
        for target in (0x10, 0x200):
            data, profile = self.fixture(0)
            data[0x15:0x18] = target.to_bytes(3, "little")
            with self.subTest(target=target), self.assertRaises(ValueError):
                layout.decode_trie(data, profile)

    def test_duplicate_keys_and_incorrect_count_are_rejected(self):
        data, profile = self.fixture(0)
        data[0x35:0x38] = data[0x32:0x35]
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            layout.decode_trie(data, profile)
        data, profile = self.fixture(0)
        profile["keyCount"] = 3
        with self.assertRaisesRegex(ValueError, "count"):
            layout.decode_trie(data, profile)


if __name__ == "__main__":
    unittest.main()
