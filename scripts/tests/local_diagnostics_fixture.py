#!/usr/bin/env python3
"""Loopback-only synthetic lockdown/TLS/AFC fixture; never connects to devices.

Certificates/UDIDs/data are generated test inputs, not real pairing records.
Only protocol verbs and scenario counts may be printed; keys stay in temp files.
"""
import argparse
import hashlib
import http.server
import json
import os
from pathlib import Path
import plistlib
import socket
import socketserver
import ssl
import struct
import subprocess
import threading

UDID = '00008100-0000000000000001'
NAME = 'Analytics-2026-10-09-090000.ips.ca.synced'
BODY = b'{"os_version":"iPhone OS 17.0","fixture":true}\n' + b'{"fixture":true}\n' * 1200
MAGIC = b'CFA6LPAA'


def exact(stream, size):
    result = bytearray()
    while len(result) < size:
        chunk = stream.recv(size - len(result))
        if not chunk:
            raise EOFError()
        result.extend(chunk)
    return bytes(result)


def read_plist(stream):
    length = struct.unpack('>I', exact(stream, 4))[0]
    if length > 1_048_576:
        raise ValueError('oversized fixture request')
    return plistlib.loads(exact(stream, length))


def send_plist(stream, value):
    data = plistlib.dumps(value)
    stream.sendall(struct.pack('>I', len(data)) + data)


def certificates(root):
    def run(*args):
        subprocess.run(['openssl', *args], cwd=root, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run('req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', 'root.key', '-out', 'root.crt', '-days', '2', '-subj', '/CN=MochiLog Test Root')
    for name, usage in [('device', 'serverAuth'), ('host', 'clientAuth'), ('foreign', 'serverAuth')]:
        run('req', '-new', '-newkey', 'rsa:2048', '-nodes', '-keyout', name + '.key', '-out', name + '.csr', '-subj', '/CN=Device' if name != 'host' else '/CN=FixtureHost')
        (root / (name + '.ext')).write_text('basicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=' + usage + '\nsubjectAltName=DNS:Device\n')
        run('x509', '-req', '-in', name + '.csr', '-CA', 'root.crt', '-CAkey', 'root.key', '-CAcreateserial', '-out', name + '.crt', '-days', '2', '-extfile', name + '.ext')
    for epoch in ['old', 'new']:
        pair = {'UDID': UDID, 'HostID': 'MochiLog-Fixture-' + epoch, 'SystemBUID': 'MochiLog-Fixture-System', 'WiFiMACAddress': '00:00:00:00:00:00'}
        for key, file in [('DeviceCertificate', 'device.crt'), ('HostCertificate', 'host.crt'), ('HostPrivateKey', 'host.key'), ('RootCertificate', 'root.crt'), ('RootPrivateKey', 'root.key')]:
            pair[key] = (root / file).read_bytes()
        (root / (epoch + '.plist')).write_bytes(plistlib.dumps(pair))
    for path in root.iterdir():
        path.chmod(0o600)


class Fixture:
    def __init__(self, root):
        self.root = root
        self.scenario = 'old'
        self.counts = {}
        self.lock = threading.Lock()
        self.contexts = {}
        for name in ['device', 'foreign']:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(root / (name + '.crt'), root / (name + '.key'))
            context.load_verify_locations(root / 'root.crt')
            context.verify_mode = ssl.CERT_REQUIRED
            context.maximum_version = ssl.TLSVersion.TLSv1_2
            self.contexts[name] = context
        self.servers = []
        self.diagnostics_port = self.listen('diagnostics', 0)
        self.afc_port = self.listen('afc', 0)
        self.listen('lockdown', 62078)
        self.control_port = self.listen('control', 0)

    def note(self, key):
        with self.lock:
            self.counts[key] = self.counts.get(key, 0) + 1

    def listen(self, kind, port):
        fixture = self
        class Handler(socketserver.BaseRequestHandler):
            def handle(self):
                self.request.settimeout(12)
                try:
                    getattr(fixture, kind)(self.request)
                except (EOFError, ConnectionError, ssl.SSLError, TimeoutError, OSError):
                    fixture.note(kind + '.closed')
        class Server(socketserver.ThreadingTCPServer):
            allow_reuse_address = True
            daemon_threads = True
        server = Server(('127.0.0.1', port), Handler)
        self.servers.append(server)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        return server.server_address[1]

    def lockdown(self, stream):
        while True:
            value = read_plist(stream)
            request = value.get('Request')
            self.note('lockdown.' + str(request))
            if request == 'GetValue':
                key = value.get('Key')
                result = '17.0' if key == 'ProductVersion' else UDID
                if self.scenario == 'identity' and key == 'UniqueDeviceID':
                    result = '00008100-0000000000000002'
                send_plist(stream, {'Value': result})
            elif request == 'StartSession':
                if self.scenario == 'disconnect':
                    return
                wanted = 'new' if self.scenario in ['revoked', 'new'] else 'old'
                if value.get('HostID') != 'MochiLog-Fixture-' + wanted:
                    send_plist(stream, {'Error': 'InvalidHostID'})
                    continue
                send_plist(stream, {'EnableSessionSSL': True, 'SessionID': 'FixtureSession'})
                context = self.contexts['foreign' if self.scenario == 'foreign' else 'device']
                stream = context.wrap_socket(stream, server_side=True)
                self.note('lockdown.authenticatedTLS')
            elif request == 'StartService':
                service = value.get('Service', '')
                port = self.diagnostics_port if 'diagnostics_relay' in service else self.afc_port
                send_plist(stream, {'Port': port, 'EnableServiceSSL': True})
            elif request == 'StopSession':
                send_plist(stream, {'Request': 'StopSession'})
            else:
                raise ValueError('unsupported lockdown fixture verb')

    def diagnostics(self, stream):
        stream = self.contexts['device'].wrap_socket(stream, server_side=True)
        value = read_plist(stream)
        if value.get('Request') != 'IORegistry':
            raise ValueError('unsupported diagnostics fixture verb')
        self.note('diagnostics.IORegistry')
        send_plist(stream, {'Status': 'Success', 'Diagnostics': {'IORegistry': {
            'CycleCount': 321, 'CurrentCapacity': 74, 'IsCharging': False,
            'BatteryData': {'DesignCapacity': 4000, 'FullChargeCapacity': 3800, 'NominalChargeCapacity': 3790, 'AppleRawMaxCapacity': 3810}}}})

    def afc(self, stream):
        stream = self.contexts['device'].wrap_socket(stream, server_side=True)
        offset = 0
        while True:
            magic, size, header_size, packet, op = struct.unpack('<8sQQQQ', exact(stream, 40))
            if magic != MAGIC or not 40 <= header_size <= size <= 1_048_576:
                raise ValueError('invalid AFC fixture request')
            data = exact(stream, size - 40)
            self.note('afc.' + str(op))
            response, header, payload = 1, struct.pack('<Q', 0), b''
            if op == 3:
                path = data.rstrip(b'\0').decode()
                response, header = 2, b''
                payload = (NAME.encode() + b'\0') if path == '/' else b''
            elif op == 10:
                response, header = 2, b''
                fields = {'st_size': str(len(BODY)), 'st_blocks': '40', 'st_ifmt': 'S_IFREG',
                          'st_nlink': '1', 'st_birthtime': '0', 'st_mtime': '0'}
                payload = b''.join(k.encode() + b'\0' + v.encode() + b'\0' for k, v in fields.items())
            elif op == 13:
                offset = 0
                response, header = 14, struct.pack('<Q', 1)
            elif op == 15:
                _, count = struct.unpack('<QQ', data[:16])
                response, header = 2, b''
                payload = BODY[offset:offset + count]
                offset += len(payload)
            elif op != 20:
                raise ValueError('unsupported AFC fixture verb')
            stream.sendall(struct.pack('<8sQQQQ', MAGIC, 40 + len(header) + len(payload), 40 + len(header), packet, response) + header + payload)

    def control(self, stream):
        command = exact(stream, 1)
        mode = {'o': 'old', 'r': 'revoked', 'n': 'new', 'i': 'identity', 'f': 'foreign', 'd': 'disconnect'}.get(command.decode())
        if mode is None:
            raise ValueError('invalid fixture scenario')
        self.scenario = mode
        self.note('scenario.' + mode)
        stream.sendall(b'OK')

    def close(self):
        for server in self.servers:
            server.shutdown()
            server.server_close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    root = args.directory.resolve()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    certificates(root)
    fixture = Fixture(root)
    config = {'udid': UDID, 'controlPort': fixture.control_port, 'name': NAME, 'sha256': hashlib.sha256(BODY).hexdigest()}
    (root / 'config.json').write_text(json.dumps(config))
    print('Synthetic lockdown fixture ready on loopback', flush=True)
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        pass
    finally:
        (root / 'counts.json').write_text(json.dumps(fixture.counts, sort_keys=True))
        fixture.close()


if __name__ == '__main__':
    main()
