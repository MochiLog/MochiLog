#!/usr/bin/env python3
"""Experiment-only Bonjour sender for the iPhone receiver in the experiment branch."""

import argparse
import hashlib
import socketserver
import subprocess


SERVICE_TYPE = "_mochiprobe._tcp"
PORT = 8765


class ProbeServer(socketserver.TCPServer):
    allow_reuse_address = True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--large", action="store_true", help="send 25 MB instead of 27 bytes")
    args = parser.parse_args()

    if args.large:
        payload = b"MOCHILOG_WIRELESS_PROBE_v2\n"
        payload += b"x" * (25_000_000 - len(payload))
    else:
        payload = b"MOCHILOG_WIRELESS_PROBE_v1\n"

    class Handler(socketserver.BaseRequestHandler):
        def handle(self) -> None:
            print(f"Connected: {self.client_address[0]}", flush=True)
            self.request.sendall(payload)

    with ProbeServer(("0.0.0.0", PORT), Handler) as server:
        advertisement = subprocess.Popen(
            ["dns-sd", "-R", "MochiLog Probe", SERVICE_TYPE, "local", str(PORT)]
        )
        try:
            print(f"Ready: {len(payload)} bytes, SHA-256 {hashlib.sha256(payload).hexdigest()}", flush=True)
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            advertisement.terminate()
            advertisement.wait(timeout=5)


if __name__ == "__main__":
    main()
