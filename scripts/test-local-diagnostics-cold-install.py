#!/usr/bin/env python3
"""Install synthetic pairing files while the app is stopped, then launch it.

Each case owns a new disposable simulator. No existing simulator, pairing or
history is erased, and no physical device or real credential is used.
"""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import uuid


def run(*args, timeout=180):
    child = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             text=True, start_new_session=True)
    try:
        output, error = child.communicate(timeout=timeout)
    except (subprocess.TimeoutExpired, KeyboardInterrupt):
        os.killpg(child.pid, signal.SIGINT)
        try:
            child.communicate(timeout=15)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.communicate()
        raise
    if child.returncode:
        raise RuntimeError(f'{args[0]} failed ({child.returncode}): {error[-2000:]} {output[-2000:]}')
    return output.strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--runtime-name', default='iOS 17.0')
    parser.add_argument('--device-type', default='com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro')
    parser.add_argument('--output', type=Path, default=Path('Build/cold-install-results.json'))
    args = parser.parse_args()
    runtimes = json.loads(run('xcrun', 'simctl', 'list', 'runtimes', '-j'))
    available = [r for r in runtimes['runtimes'] if r.get('isAvailable') and r['name'] == args.runtime_name]
    if not available:
        raise RuntimeError('Requested runtime is not installed; will not download a runtime')
    runtime = available[-1]['identifier']
    repo = Path(__file__).resolve().parent.parent
    args.output.parent.mkdir(parents=True, exist_ok=True)
    results = {}
    for case in ['valid', 'standard', 'remote-aliases', 'malformed', 'symlink']:
        device = None
        started = time.monotonic()
        try:
            device = run('xcrun', 'simctl', 'create', 'MochiLog Cold Install ' + uuid.uuid4().hex[:8], args.device_type, runtime)
            run('xcrun', 'simctl', 'boot', device)
            run('xcrun', 'simctl', 'bootstatus', device, '-b')
            case_file = args.output.with_name(args.output.stem + '-' + case + '.json')
            print('Testing cold installation: ' + case, flush=True)
            print(run(sys.executable, str(repo / 'scripts/test-local-diagnostics-simulator.py'), device,
                      '--app', str(args.app.resolve()), '--cold-case', case,
                      '--output', str(case_file.resolve()), timeout=240), flush=True)
            results[case] = json.loads(case_file.read_text())
            print(f'Finished {case} in {time.monotonic() - started:.1f}s', flush=True)
        finally:
            if device:
                try:
                    run('xcrun', 'simctl', 'shutdown', device, timeout=60)
                except (RuntimeError, subprocess.TimeoutExpired):
                    pass
                finally:
                    run('xcrun', 'simctl', 'delete', device, timeout=60)
    args.output.write_text(json.dumps(results, sort_keys=True, indent=2) + '\n')
    if not all(r.get('passed') for r in results.values()):
        raise RuntimeError('Cold installation tests failed')
    print('PASS: all five cold-start cases; disposable simulators deleted', flush=True)


if __name__ == '__main__':
    main()
