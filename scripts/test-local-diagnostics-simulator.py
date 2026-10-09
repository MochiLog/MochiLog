#!/usr/bin/env python3
"""Exercise the production Swift/native path using a loopback-only TLS fixture.

Run on a booted simulator after installing a Debug MochiLog build. No physical
phone, VPN profile, real pairing file or user interaction is used. Does not
emulate Apple's OS service availability or OS update behavior.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time


def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs).stdout.strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('simulator')
    parser.add_argument('--app', type=Path)
    parser.add_argument('--output', type=Path, default=Path('Build/local-native-simulator-results.json'))
    args = parser.parse_args()
    bundle = 'net.ryuya-dev.MochiLog'
    repo = Path(__file__).resolve().parent.parent
    with tempfile.TemporaryDirectory(prefix='mochilog-lockdown-fixture-') as temporary:
        root = Path(temporary)
        process = subprocess.Popen([sys.executable, str(repo / 'scripts/tests/local_diagnostics_fixture.py'), str(root)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        fixture_dir = result = None
        try:
            deadline = time.monotonic() + 30
            while not (root / 'config.json').exists():
                if process.poll() is not None:
                    raise RuntimeError('Fixture startup failed: ' + process.stderr.read())
                if time.monotonic() > deadline:
                    raise TimeoutError('Fixture startup timed out')
                time.sleep(0.2)
            if args.app:
                run('xcrun', 'simctl', 'install', args.simulator, str(args.app.resolve()))
            container = Path(run('xcrun', 'simctl', 'get_app_container', args.simulator, bundle, 'data'))
            documents = container / 'Documents'
            documents.mkdir(exist_ok=True)
            fixture_dir = documents / 'LocalDiagnosticsFixture'
            if fixture_dir.exists():
                raise RuntimeError('An older fixture input exists; refusing to overwrite it')
            fixture_dir.mkdir(mode=0o700)
            for name in ['old.plist', 'new.plist', 'config.json']:
                shutil.copy2(root / name, fixture_dir / name)
            result = documents / 'LocalDiagnosticsFixtureResult.json'
            result.unlink(missing_ok=True)
            env = dict(os.environ, SIMCTL_CHILD_MOCHI_LOCAL_NATIVE_FIXTURE='1')
            run('xcrun', 'simctl', 'launch', '--terminate-running-process', args.simulator, bundle,
                '-hasCompletedTutorial', 'YES', '-showPopupOnLoad', 'NO', '-iCloudSyncEnabled', 'NO',
                '-pcAutomaticCollectionEnabled', 'NO', '-localAutomaticCollectionEnabled', 'NO',
                '-liveBatteryEnabled', 'NO', '-LastKnownAppVersion', '4.0.0', env=env)
            deadline = time.monotonic() + 120
            while not result.exists():
                if time.monotonic() > deadline:
                    raise TimeoutError('Native simulator probe did not finish; app may have crashed')
                time.sleep(0.3)
            summary = json.loads(result.read_text())
            for key, value in sorted(summary.items()):
                print(('PASS ' if value else 'FAIL ') + key)
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(summary, sort_keys=True, indent=2) + '\n')
            if not summary.get('passed'):
                raise RuntimeError('Native fixture checks failed; inspect the value-free summary')
        finally:
            process.send_signal(signal.SIGINT) if process.poll() is None else None
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            if fixture_dir:
                shutil.rmtree(fixture_dir, ignore_errors=True)
            if result:
                result.unlink(missing_ok=True)
            try:
                run('xcrun', 'simctl', 'terminate', args.simulator, bundle)
            except subprocess.CalledProcessError:
                pass
            if (root / 'counts.json').exists():
                print('Protocol counts: ' + (root / 'counts.json').read_text())


if __name__ == '__main__':
    main()
