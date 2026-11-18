#!/usr/bin/env python3
"""Exercise the real mobile transfer manager against synthetic loopback peers.

Requires a Debug build and a disposable simulator named 'MochiLog Stability ...'.
The fixture uses cryptography in the developer environment; it is not an app
dependency. No Apple services, real pairings or battery records are involved.
"""

import argparse
import base64
from contextlib import ExitStack
import json
import os
from pathlib import Path
import socketserver
import struct
import subprocess
import threading
import time
import uuid

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

BUNDLE = "net.ryuya-dev.MochiLog"
KEY = bytes([7]) * 32  # Synthetic test material, never a real pairing key.


def run(*arguments, check=True, **kwargs):
    return subprocess.run(
        arguments, check=check, capture_output=True, text=True, timeout=60, **kwargs
    ).stdout.strip()


class Peer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True
    block_on_close = False

    def __init__(self, mode):
        self.mode = mode
        self.host_id = str(uuid.uuid4()).upper()
        self.stop_event = threading.Event()
        self.errors = []
        self.authenticated = 0
        super().__init__(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.serve_forever, daemon=True)
        self.thread.start()

    def close(self):
        self.stop_event.set()
        self.shutdown()
        self.server_close()
        self.thread.join(timeout=3)


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.settimeout(5)
        try:
            request = bytearray()
            while b"\n" not in request and len(request) <= 32768:
                part = self.request.recv(4096)
                if not part:
                    return
                request.extend(part)
            if len(request) > 32768:
                raise ValueError("Oversized fixture request")
            envelope = json.loads(request.split(b"\n", 1)[0])
            assert envelope["version"] == "3"
            assert envelope["hostID"] == self.server.host_id
            aad = (
                f"v3|request|{envelope['hostID']}|{envelope['physicalDeviceID']}|"
                f"{envelope['nonce']}|{envelope['issuedAt']}"
            ).encode()
            box = base64.b64decode(envelope["box"], validate=True)
            plain = json.loads(AESGCM(KEY).decrypt(box[:12], box[12:], aad))
            assert plain["nonce"] == envelope["nonce"]
            self.server.authenticated += 1
            mode = self.server.mode
            if mode == "oversized":
                self.request.sendall(b"\xff\xff\xff\xff")
                self.server.stop_event.wait(30)
                return
            if mode == "truncated":
                self.request.sendall(struct.pack(">I", 128) + bytes(12))
                return
            report = json.dumps({"schema": 1, "platform": "macOS"}, separators=(",", ":")).encode()
            response_aad = (
                f"v2|response|{envelope['hostID']}|{envelope['physicalDeviceID']}|"
                f"{envelope['nonce']}"
            ).encode()
            nonce = os.urandom(12)
            combined = nonce + AESGCM(KEY).encrypt(nonce, b"\0\0" + report, response_aad)
            if mode == "tampered":
                combined = combined[:-1] + bytes([combined[-1] ^ 1])
            frame = struct.pack(">I", len(combined)) + combined
            # Fragment both the header and body, then deliberately omit TCP EOF.
            for offset in range(0, len(frame), 3):
                self.request.sendall(frame[offset : offset + 3])
                time.sleep(0.005)
            self.server.stop_event.wait(30)
        except (BrokenPipeError, ConnectionResetError):
            pass  # A successfully authenticated client may close first.
        except Exception as error:
            self.server.errors.append(type(error).__name__ + ": " + str(error))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("simulator")
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--case",
        choices=["complete-without-eof", "oversized", "truncated", "tampered", "offline-computer"],
    )
    parser.add_argument(
        "--expect-failure",
        action="store_true",
        help="Verify reproduction using a separate baseline Debug build",
    )
    args = parser.parse_args()
    devices = json.loads(run("xcrun", "simctl", "list", "devices", "-j"))
    device = next(
        (d for group in devices["devices"].values() for d in group if d["udid"] == args.simulator),
        None,
    )
    if not device or not device["name"].startswith("MochiLog Stability "):
        raise RuntimeError("Refusing to alter a non-fixture simulator")
    run("xcrun", "simctl", "install", args.simulator, str(args.app.resolve()))
    container = Path(run("xcrun", "simctl", "get_app_container", args.simulator, BUNDLE, "data"))
    documents = container / "Documents"
    documents.mkdir(exist_ok=True)
    config_path = documents / "PCStabilityFixture.json"
    result_path = documents / "PCStabilityResult.json"
    results = []
    try:
        for scenario in (
            [args.case]
            if args.case
            else ["complete-without-eof", "oversized", "truncated", "tampered", "offline-computer"]
        ):
            run("xcrun", "simctl", "terminate", args.simulator, BUNDLE, check=False)
            result_path.unlink(missing_ok=True)
            with ExitStack() as stack:
                good = Peer("valid")
                stack.callback(good.close)
                hosts = []
                peers = [good]
                if scenario == "offline-computer":
                    hosts.append({"id": str(uuid.uuid4()).upper(), "port": 0})
                elif scenario != "complete-without-eof":
                    bad = Peer(scenario)
                    peers.append(bad)
                    stack.callback(bad.close)
                    hosts.append({"id": bad.host_id, "port": bad.server_address[1]})
                hosts.append({"id": good.host_id, "port": good.server_address[1]})
                config_path.write_text(
                    json.dumps(
                        {"hosts": hosts, "deviceID": str(uuid.uuid4()).upper(), "timeout": 25.0}
                    )
                )
                env = dict(os.environ, SIMCTL_CHILD_MOCHI_PC_STABILITY_PROBE="1")
                run("xcrun", "simctl", "launch", args.simulator, BUNDLE, env=env)
                deadline = time.monotonic() + 35
                while not result_path.exists():
                    if time.monotonic() >= deadline:
                        raise TimeoutError("No mobile probe result: " + scenario)
                    time.sleep(0.1)
                result = json.loads(result_path.read_text())
                result.update(
                    scenario=scenario,
                    serverErrors=[e for p in peers for e in p.errors],
                    authenticatedRequests=sum(p.authenticated for p in peers),
                )
                results.append(result)
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_text(json.dumps(results, indent=2) + "\n")
                assert result["passed"] != args.expect_failure, result
                if result["passed"]:
                    assert result["selectedComputer"] == good.host_id, result
                if scenario == "tampered" and not args.expect_failure:
                    assert any(
                        "kind=unverifiedPeer" in event and "phase=response-authentication" in event
                        for event in result["debugEvents"]
                    ), result
                assert not result["serverErrors"], result
                if scenario == "complete-without-eof" and not args.expect_failure:
                    assert result["elapsedSeconds"] < 5, result
                print(
                    json.dumps(
                        {
                            "scenario": scenario,
                            "passed": result["passed"],
                            "expectedFailure": args.expect_failure,
                            "elapsedSeconds": round(result["elapsedSeconds"], 3),
                        }
                    ),
                    flush=True,
                )
    finally:
        run("xcrun", "simctl", "terminate", args.simulator, BUNDLE, check=False)
        config_path.unlink(missing_ok=True)
        result_path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
