#!/usr/bin/env python3
"""Convert an existing own-device remote pairing for a disposable research app.

Never prints keys, modifies the original record or installs anything on a device.
The app deletes these input files after loading its in-memory credentials.
"""
import argparse
import os
from pathlib import Path
import platform
import plistlib
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pair-record', type=Path, required=True)
    parser.add_argument('--expected-udid', required=True)
    parser.add_argument('--host-identifier', help='Original pairing identifier; defaults to pymobiledevice3 hostname UUID')
    args = parser.parse_args()
    with args.pair_record.open('rb') as source:
        original = plistlib.load(source)
    pair = {}
    for key in ('public_key', 'private_key'):
        value = original.get(key)
        if not isinstance(value, bytes) or len(value) != 32:
            parser.error(f'{key} must contain 32 bytes in an existing remote pairing record')
        pair[key] = value
    pair['identifier'] = (args.host_identifier or original.get('identifier')
                          or original.get('host_identifier')
                          or str(uuid.uuid3(uuid.NAMESPACE_DNS, platform.node())).upper())
    alt_irk = original.get('alt_irk', original.get('peer_alt_irk'))
    if isinstance(alt_irk, bytes):
        pair['alt_irk'] = alt_irk
    directory = Path(tempfile.mkdtemp(prefix='mochilog-localdev-inputs-'))
    os.chmod(directory, 0o700)
    for name, value in [('probe-pairing.plist', pair),
                        ('probe-identity.plist', {'expectedUDID': args.expected_udid})]:
        fd = os.open(directory / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'wb') as output:
            plistlib.dump(value, output)
    print(directory)


if __name__ == '__main__':
    main()
