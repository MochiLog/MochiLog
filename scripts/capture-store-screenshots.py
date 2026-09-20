#!/usr/bin/env python3
"""Capture real UI in dedicated, reusable simulators; never erase personal simulators."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import struct
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--devices', nargs='+', choices=['iphone', 'ipad', 'watch'], default=['iphone', 'ipad', 'watch'])
selected = set(parser.parse_args().devices)
ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
OUTPUT = ROOT / 'build' / 'store-screenshots' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
DERIVED = ROOT / 'build' / 'store-derived'
OUTPUT.mkdir(parents=True)

def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)

def json_command(*args):
    return json.loads(subprocess.check_output(args, text=True))

def simulator(name, device_type, runtime):
    devices = json_command('xcrun', 'simctl', 'list', 'devices', '-j')['devices'].get(runtime, [])
    matches = [d for d in devices if d['name'] == name and d.get('isAvailable')]
    if len(matches) > 1:
        raise RuntimeError(f'Duplicate screenshot simulators: {name}')
    if matches:
        return matches[0]['udid']
    return subprocess.check_output(['xcrun', 'simctl', 'create', name,
                                   'com.apple.CoreSimulator.SimDeviceType.' + device_type, runtime], text=True).strip()

def boot(device, watch=False):
    state = [d for ds in json_command('xcrun', 'simctl', 'list', 'devices', '-j')['devices'].values()
             for d in ds if d['udid'] == device][0]['state']
    if state != 'Booted':
        run('xcrun', 'simctl', 'boot', device)
    run('xcrun', 'simctl', 'bootstatus', device, '-b')
    if not watch:
        run('xcrun', 'simctl', 'ui', device, 'appearance', 'dark')
        run('xcrun', 'simctl', 'status_bar', device, 'override', '--time', '9:41',
            '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3',
            '--cellularMode', 'active', '--cellularBars', '4', '--batteryState', 'discharging', '--batteryLevel', '100')

def xcode(scheme, device, platform, action, label, tests=()):
    command = ['xcodebuild', action, '-project', 'MochiLog.xcodeproj', '-scheme', scheme,
               '-destination', f'platform={platform} Simulator,id={device}',
               '-derivedDataPath', str(DERIVED), '-parallel-testing-enabled', 'NO',
               '-collect-test-diagnostics', 'never']
    if tests:
        command += ['-resultBundlePath', str(OUTPUT / (label + '.xcresult'))]
        command += ['-only-testing:' + t for t in tests]
    print(f'\n{label} — {action} (log: {OUTPUT / (label + ".log")})', flush=True)
    with (OUTPUT / (label + '.log')).open('w') as log:
        run(*command, stdout=log, stderr=subprocess.STDOUT)

def export(label):
    attachments = OUTPUT / (label + '-attachments')
    run('xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(OUTPUT / (label + '.xcresult')),
        '--output-path', str(attachments))
    count = 0
    for test in json.loads((attachments / 'manifest.json').read_text()):
        for attachment in test['attachments']:
            match = re.search(r'store_(en_US|ja_JP)_(\d{2}_[a-z]+)', attachment['suggestedHumanReadableName'])
            if not match:
                continue
            locale, screen = match.groups()
            destination = OUTPUT / 'screenshots' / ('ja' if locale == 'ja_JP' else 'en-US')
            destination.mkdir(parents=True, exist_ok=True)
            source = attachments / attachment['exportedFileName']
            with source.open('rb') as image:
                image.seek(16)
                dimensions = struct.unpack('>II', image.read(8))
            expected = {'iphone': (1320, 2868), 'ipad': (2064, 2752), 'watch': (416, 496)}[label]
            if dimensions != expected:
                raise RuntimeError(f'{label}: unexpected screenshot dimensions {dimensions}, expected {expected}')
            shutil.copy2(source, destination / f'{label}_{screen}.png')
            count += 1
    if count != 8:
        raise RuntimeError(f'{label}: expected 8 screenshots, got {count}')

version = subprocess.check_output(['xcodebuild', '-version'], text=True)
if not version.startswith('Xcode 27.0\n'):
    raise RuntimeError('Select stable Xcode 27.0 (or set DEVELOPER_DIR) before store capture.\n' + version)
phone = simulator('MochiLog Store iPhone 17 Pro Max', 'iPhone-17-Pro-Max', 'com.apple.CoreSimulator.SimRuntime.iOS-27-0')
pad = simulator('MochiLog Store iPad Pro 13', 'iPad-Pro-13-inch-M5-12GB', 'com.apple.CoreSimulator.SimRuntime.iOS-27-0')
watch = simulator('MochiLog Store Watch 46mm', 'Apple-Watch-Series-11-46mm', 'com.apple.CoreSimulator.SimRuntime.watchOS-27-0')
if 'watch' in selected:
    pairs = json_command('xcrun', 'simctl', 'list', 'pairs', '-j')['pairs']
    if not any(p.get('watch', {}).get('udid') == watch and p.get('phone', {}).get('udid') == phone for p in pairs.values()):
        run('xcrun', 'simctl', 'pair', watch, phone)
    boot(phone)
    boot(watch, watch=True)
    xcode('MochiLogWatchUITests', watch, 'watchOS', 'build-for-testing', 'watch-build')
    watch_app = DERIVED / 'Build/Products/Debug-watchsimulator/MochiLog Watch App.app'
    run('xcrun', 'simctl', 'install', watch, str(watch_app))
for label, device in [('iphone', phone), ('ipad', pad)]:
    if label not in selected and not (label == 'iphone' and 'watch' in selected):
        continue
    boot(device)
    xcode('MochiLogUITests', device, 'iOS', 'test', label, [
        'MochiLogUITests/LanguageAndLayoutTests/testStoreScreenshotsEnglish',
        'MochiLogUITests/LanguageAndLayoutTests/testStoreScreenshotsJapanese'])
    export(label)
if 'watch' in selected:
    def data_container(device, bundle):
        return Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', device, bundle, 'data'], text=True).strip())
    fixture_name = 'store-screenshot-records.json'
    source = data_container(phone, 'net.ryuya-dev.MochiLog') / 'Documents' / fixture_name
    destination = data_container(watch, 'net.ryuya-dev.MochiLog.watchkitapp') / 'Documents' / fixture_name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    xcode('MochiLogWatchUITests', watch, 'watchOS', 'test-without-building', 'watch', [
        'MochiLogWatchUITests/WatchLayoutTests/testStoreScreenshotsEnglish',
        'MochiLogWatchUITests/WatchLayoutTests/testStoreScreenshotsJapanese'])
    export('watch')
(OUTPUT / 'capture.json').write_text(json.dumps({'gitCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'xcode': version.strip(), 'devices': {'iphone': phone, 'ipad': pad, 'watch': watch}, 'appearance': 'dark'}, indent=2))
print(f'\n{len(list((OUTPUT / "screenshots").rglob("*.png")))} screenshots saved: {OUTPUT / "screenshots"}', flush=True)
with zipfile.ZipFile(OUTPUT / 'MochiLog-screenshots.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for screenshot in sorted((OUTPUT / 'screenshots').rglob('*.png')):
        archive.write(screenshot, screenshot.relative_to(OUTPUT / 'screenshots'))
run('open', str(OUTPUT / 'screenshots'))
