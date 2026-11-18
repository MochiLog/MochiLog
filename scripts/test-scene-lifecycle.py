#!/usr/bin/env python3
"""Exercise real OS scene archives across in-place updates of a synthetic app.

The fixed app compiles the production SwiftUI entry point and window host.
Creates disposable phone/tablet simulators and never installs/uninstalls MochiLog.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = "net.ryuya-dev.MochiLog.SceneRegression"
EXECUTABLE = "MochiLogSceneRegression"


def run(*args, check=True, timeout=60, env=None):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout, env=env)
    if check and result.returncode:
        raise RuntimeError(f"{args[0]} failed: {result.stderr[-2000:]}")
    return result


def sim(*args, **kwargs):
    return run("xcrun", "simctl", *args, **kwargs)


def build(directory):
    sdk = run("xcrun", "--sdk", "iphonesimulator", "--show-sdk-path").stdout.strip()
    for variant in ("SwiftUI", "UIKit", "Fixed", "Sender"):
        app = directory / f"{variant}.app"
        app.mkdir(parents=True, exist_ok=True)
        command = [
            "xcrun",
            "swiftc",
            "-j",
            "1",
            "-parse-as-library",
            "-sdk",
            sdk,
            "-target",
            "arm64-apple-ios16.0-simulator",
            "-module-name",
            "SceneRegression",
            str(ROOT / "Tests/SceneLifecycle/Fixtures.swift"),
            str(ROOT / "MochiLog/App/SceneWindowHost.swift"),
        ]
        if variant == "Fixed":
            command.append(str(ROOT / "MochiLog/App/MochiLogApplication.swift"))
        elif variant == "Sender":
            command += ["-D", "URL_SENDER"]
        else:
            command += ["-D", f"LEGACY_{variant.upper()}"]
        run(*command, "-o", str(app / EXECUTABLE), timeout=120)
        manifest = {"UIApplicationSupportsMultipleScenes": False}
        if variant in ("UIKit", "Fixed"):
            manifest["UISceneConfigurations"] = {
                "UIWindowSceneSessionRoleApplication": [
                    {
                        "UISceneClassName": "UIWindowScene",
                        "UISceneConfigurationName": "MochiLog Main Scene",
                        "UISceneDelegateClassName": "SceneRegression.MochiLogSceneDelegate",
                    }
                ]
            }
        info = {
            "CFBundleIdentifier": BUNDLE + ".Sender" if variant == "Sender" else BUNDLE,
            "CFBundleExecutable": EXECUTABLE,
            "CFBundleName": EXECUTABLE,
            "CFBundleDisplayName": "Scene Regression",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": str(("SwiftUI", "UIKit", "Fixed", "Sender").index(variant) + 1),
            "LSRequiresIPhoneOS": True,
            "MinimumOSVersion": "16.0",
            "UIDeviceFamily": [1, 2],
            "UILaunchScreen": {},
            "UIApplicationSceneManifest": manifest,
            "CFBundleURLTypes": [
                {
                    "CFBundleURLSchemes": ["mochisceneprobe"],
                    "CFBundleURLName": BUNDLE,
                    "CFBundleTypeRole": "Editor",
                }
            ],
            "UISupportedInterfaceOrientations": [
                "UIInterfaceOrientationPortrait",
                "UIInterfaceOrientationLandscapeLeft",
                "UIInterfaceOrientationLandscapeRight",
            ],
        }
        if variant == "Sender":
            del info["CFBundleURLTypes"]
        (app / "Info.plist").write_bytes(plistlib.dumps(info))
        run("codesign", "--force", "--sign", "-", str(app))


def documents(device):
    return Path(sim("get_app_container", device, BUNDLE, "data").stdout.strip()) / "Documents"


def events(device):
    path = documents(device) / "events.txt"
    return path.read_text() if path.exists() else ""


def wait_for(device, expected, offset=0):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        text = events(device)[offset:]
        if expected in text:
            return text
        time.sleep(0.2)
    raise AssertionError(f"Missing {expected}: {events(device)[offset:]}")


def digest(device):
    return hashlib.sha256((documents(device) / "record.json").read_bytes()).hexdigest()


def background(device):
    sim("launch", device, "com.apple.Preferences")
    time.sleep(1)


def open_url(device, url):
    # Some simulator releases silently reject simctl openurl's unregistered
    # CoreSimulatorBridge source. Use a real, installed app as the sender.
    sim("terminate", device, BUNDLE + ".Sender", check=False)
    sim(
        "launch", device, BUNDLE + ".Sender", env={**os.environ, "SIMCTL_CHILD_SCENE_OPEN_URL": url}
    )


def verify_fixed(device, expected_digest=None):
    for index in range(3):
        offset = len(events(device))
        sim("launch", device, BUNDLE)
        text = wait_for(device, "content appeared", offset)
        text = wait_for(device, "active contentWindows=1", offset)
        assert "active contentWindows=0" not in text and "active contentWindows=2" not in text, text
        if expected_digest:
            assert "launch marker=retained-user-record" in text, text
            assert digest(device) == expected_digest
        url = f"mochisceneprobe://warm/{index}"
        open_url(device, url)
        wait_for(device, f"url={url}", offset)
        background(device)
        text = wait_for(device, "background", offset)
        assert text.count("content appeared") == 1, text
        sim("terminate", device, BUNDLE)  # Fails if background state saving crashed.
        url = f"mochisceneprobe://cold/{index}"
        offset = len(events(device))
        open_url(device, url)
        wait_for(device, f"url={url}", offset)
        background(device)
        sim("terminate", device, BUNDLE)


def exercise(device, directory):
    sim("install", device, str(directory / "Sender.app"))
    results = []
    for legacy in ("SwiftUI", "UIKit", None):
        sim("uninstall", device, BUNDLE, check=False)
        expected_digest = None
        if legacy:
            sim("install", device, str(directory / f"{legacy}.app"))
            sim("launch", device, BUNDLE)
            wait_for(device, "content appeared")
            expected_digest = digest(device)
            background(device)
            sim("terminate", device, BUNDLE)
        sim("install", device, str(directory / "Fixed.app"))
        verify_fixed(device, expected_digest)
        results.append({"from": legacy or "fresh", "passed": True})
        print(f"PASS {device}: {legacy or 'fresh'} -> fixed", flush=True)
    # Negative control: reproduce the production failure with a named UIKit
    # manifest but no SwiftUI AppGraph. Require the actual restoration signature.
    sim("uninstall", device, BUNDLE)
    sim("install", device, str(directory / "SwiftUI.app"))
    sim("launch", device, BUNDLE)
    wait_for(device, "content appeared")
    background(device)
    sim("terminate", device, BUNDLE)
    sim("install", device, str(directory / "UIKit.app"))
    started = time.time()
    sim("launch", device, BUNDLE)
    time.sleep(1)
    background(device)
    deadline = time.monotonic() + 20
    reports = Path.home() / "Library/Logs/DiagnosticReports"
    reproduced = False
    while time.monotonic() < deadline:
        for path in reports.glob(f"{EXECUTABLE}-*.ips"):
            if (
                path.stat().st_mtime >= started
                and "AppSceneDelegate.stateRestorationActivity" in path.read_text()
            ):
                reproduced = True
                break
        if reproduced:
            break
        time.sleep(0.5)
    assert reproduced, "Negative control did not produce the expected restoration crash"
    assert sim("terminate", device, BUNDLE, check=False).returncode != 0
    # Recover the very same crashed installation without uninstalling its data.
    expected_digest = digest(device)
    sim("install", device, str(directory / "Fixed.app"))
    verify_fixed(device, expected_digest)
    results.append({"from": "crashed SwiftUI-to-UIKit update", "passed": True})
    print(f"PASS {device}: reproduced baseline crash and recovered in place", flush=True)
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", help="Available iOS runtime identifier (defaults to latest)")
    parser.add_argument("--output", type=Path, default=ROOT / "Build/scene-lifecycle-tests")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    build(args.output)
    runtimes = json.loads(sim("list", "runtimes", "-j").stdout)["runtimes"]
    available = [r for r in runtimes if r["isAvailable"] and r["name"].startswith("iOS ")]
    runtime = (
        next((r for r in available if r["identifier"] == args.runtime), None)
        if args.runtime
        else max(available, key=lambda r: tuple(map(int, r["version"].split("."))))
    )
    assert runtime, "Requested iOS simulator runtime is not installed"
    results = []
    owned_devices = []
    for family in ("iPhone", "iPad"):
        kind = next(d for d in runtime["supportedDeviceTypes"] if d["productFamily"] == family)
        device = sim(
            "create", f"MochiLog Scene Test {family}", kind["identifier"], runtime["identifier"]
        ).stdout.strip()
        owned_devices.append(device)
        (args.output / "owned-simulators.json").write_text(json.dumps(owned_devices))
        try:
            sim("boot", device)
            sim("bootstatus", device, "-b", timeout=180)
            results.append(
                {
                    "family": family,
                    "runtime": runtime["version"],
                    "cases": exercise(device, args.output),
                }
            )
        finally:
            sim("shutdown", device, check=False)
            sim("delete", device)
    (args.output / "results.json").write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
