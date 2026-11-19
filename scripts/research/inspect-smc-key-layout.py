#!/usr/bin/env python3
"""Read the compressed key metadata in two audited SMC boot images.

This parses static layout information only. It does not execute firmware,
contact hardware, read the indicated RAM pointers, or retrieve battery values.
Unknown image hashes and malformed tries are rejected.
"""

import argparse
import hashlib
import json
from pathlib import Path
import stat


PROFILES = {
    "c2f0e60464c3cb2b79e93e49576218c5cde6d636b86286aac0287f3def4f990b": {
        "name": "H18_6-7372.42.1.v57.REL", "root": 0x7F9F9,
        "metadata": 0x853DA, "types": 0x856BC, "keyCount": 2936,
    },
    "5670e75bdd41dcbb93ab51c05ec2f50beb27890505ebbcd6bf53e7e5831d6982": {
        "name": "M11-7372.40.166.0.11.n227.REL", "root": 0x53A68,
        "metadata": 0x570A5, "types": 0x572F4, "keyCount": 1469,
    },
}


def decode_trie(data, profile):
    """Decode prefix branches and the four leaf address encodings."""
    result = {}
    visited = set()
    header_sizes = (2, 6, 6, 3)

    def read(address, size):
        if not 0 <= address <= address + size <= len(data):
            raise ValueError("Metadata address outside image")
        return int.from_bytes(data[address:address + size], "little")

    def add_record(name, type_index, pointer):
        if len(name) != 4 or not all(32 <= byte <= 126 for byte in name):
            raise ValueError("Invalid four-character key")
        name = name.decode("ascii")
        if name in result:
            raise ValueError("Duplicate key")
        address = profile["metadata"] + type_index * 3
        length = read(address, 1)
        kind = read(address + 1, 1)
        attributes = read(address + 2, 1)
        kind = kind if kind <= 18 else 0
        type_code = read(profile["types"] + kind * 4, 4).to_bytes(4, "big")
        result[name] = {
            "key": name, "attributes": hex(attributes), "length": length,
            "type": type_code.decode("ascii"), "dataOrHandler": hex(pointer),
        }

    def visit(node, prefix):
        if node in visited or len(visited) >= 10000:
            raise ValueError("Repeated node or excessive trie size")
        visited.add(node)
        flags = read(node, 1)
        count = read(node + 1, 1)
        width = (flags >> 3) & 3
        if not 1 <= width <= 3 or len(prefix) + width > 4:
            raise ValueError("Invalid key width")
        if flags & 4:
            if width > 2:
                raise ValueError("Invalid branch width")
            for index in range(count):
                entry = node + 2 + index * (width + 2)
                suffix = read(entry + 2, width).to_bytes(width, "big")
                child = read(node + 2 + count * (width + 2) + index * 3, 3)
                if child:
                    visit(child, prefix + suffix)
            return
        encoding = flags & 3
        header_size = header_sizes[encoding]
        values = node + header_size + width * count
        for index in range(count):
            suffix = read(node + header_size + index * width, width).to_bytes(width, "big")
            if encoding == 0:
                type_index = read(values + index * 4, 1)
                pointer = read(values + index * 4 + 1, 3)
            else:
                type_index = read(node + 2, 1)
                if encoding == 3:
                    pointer = read(values + index * 3, 3)
                else:
                    pointer = read(node + 3, 3)
                    if encoding == 2:
                        pointer += read(values + index * 2, 2)
            add_record(prefix + suffix, type_index, pointer)

    visit(profile["root"], b"")
    if len(result) != profile["keyCount"]:
        raise ValueError("Decoded count differs from audited firmware index bound")
    return result


def inspect(path, keys):
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_size > 2 * 1024 * 1024:
        raise ValueError("Expected a regular SMC image of at most 2 MiB")
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest not in PROFILES:
        raise ValueError("Unaudited image; refusing to guess metadata layout")
    profile = PROFILES[digest]
    records = decode_trie(data, profile)
    return {
        "formatVersion": 1, "scope": "Static metadata; never dereferences RAM pointers",
        "firmware": profile["name"], "sha256": digest, "keyCount": len(records),
        "keys": {key: records.get(key) for key in keys} if keys else records,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("--key", action="append", default=[])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(json.dumps(inspect(args.image, args.key), indent=2) + "\n")


if __name__ == "__main__":
    main()
