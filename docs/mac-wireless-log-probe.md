# Wireless Analytics log access probe (2026-09-25)

Status: **wireless Analytics acquisition and app-launch Mac-to-iPhone reception confirmed on iOS 27; app-launch reception confirmed on iOS 16**. This is a research note and an experiment-only receiver, not a product implementation. The proposed Mac transfer feature will target iOS 17 and later; the iOS 16 observation is research only.

## Device and connection

- Physical iPhone 17 on iOS 27.2; Mac using Xcode 27 stable.
- No USB cable attached during the probe.
- `devicectl device info details` reported `Transport Type: localNetwork`.
- `devicectl device info lockState` reported `passcodeRequired: true`, `unlockedSinceBoot: true` during the first transfer attempts. The user then unlocked the phone; the state changed to `passcodeRequired: false`.

## Results

1. `devicectl device info files --domain-type systemCrashLogs --search Analytics` listed 65 matching paths. The paths include the iPhone's own `Retired/Analytics-*.ips.ca.synced` and separate `ProxiedDevice-*/Retired/Analytics-*` entries. This is metadata visibility, not file-content access.
2. `devicectl device copy from --domain-type systemCrashLogs --source Retired/Analytics-2026-09-25-090006.ips.ca.synced` failed: remote `openat(2)` returned POSIX 1 (`EPERM`). An older Analytics log failed the same way.
3. `pymobiledevice3 crash ls --native --udid <device>` listed the same Analytics path over Apple's existing wireless tunnel. `crash pull` for one file failed with AFC `PERM_DENIED (10)`.
4. The same `devicectl` service copied a small `Retired/JetsamEvent-*.ips` and the root `ota_patch.txt` successfully. Thus the wireless path and general file transfer work; the Analytics content is the specific failure.
5. Homebrew `idevice_id -n` did not discover the phone even while CoreDevice did. The native remote tunnel path in `pymobiledevice3` did discover it.
6. With `passcodeRequired: false`, both `devicectl device copy from` and `pymobiledevice3 crash pull --native` copied the same 24,989,005-byte Analytics log over Wi-Fi. SHA-256 hashes were identical. The copied file contains battery metrics and is suitable for the existing parser. No cable was attached.
7. A signed Debug build of the unchanged iPhone app was installed and launched over the same wireless CoreDevice connection. `devicectl device copy to` placed a 45-byte invalid probe file in the app's Documents directory; listing confirmed it, and the probe file was removed afterward. This proves wireless Mac-to-iPhone app-container transfer through Xcode, not foreground import by MochiLog.
8. CoreDevice restricts app-group file operations to `Library`, `Documents`, and `tmp`; MochiLog's existing `SharedLogInbox` is at the app-group root. Therefore the existing share-extension inbox could not be used for this no-code staging experiment.
9. An experiment-only Debug receiver now starts a Bonjour browse when MochiLog becomes active. After the user granted local-network permission, the iPhone discovered the Mac's `_mochiprobe._tcp` service, opened a TCP connection, received a 27-byte synthetic probe, and saved it in app Documents. A Mac-side readback exactly matched the source bytes.
10. The same receiver then transferred a 25,000,000-byte synthetic payload, approximately the size of the observed Analytics file. Readback from the iPhone matched the Mac's SHA-256: `eb15128cfa2573cb808d5e13c546a624d272d75cc0b803dddd7f78e3e6510745`. The test files were removed from the app Documents directory after verification. No battery record was imported or changed.

## Repeat the receiver test

Run `python3 scripts/mac_wireless_probe_server.py` on the Mac, then launch the Debug build on the paired iPhone. The first launch needs local-network permission. For the 25 MB test, restart the app with `python3 scripts/mac_wireless_probe_server.py --large` running. The receiver performs only one discovery and transfer per app process. It writes the received payload to `Documents/mac-wireless-receive-probe.txt` or `Documents/mac-wireless-large-probe.bin` and records the byte count and SHA-256 in MochiLog's diagnostic log. It deliberately does not call the import queue. The sender does not need a hard-coded iPhone IP address; Bonjour provides Mac discovery.

Raw test copies and the Python probe environment are under `/tmp/mochilog-wireless-probe*`, outside the repository. The repository contains no copied device logs or hardware identifiers.

## Next gate

Before promising unattended collection, measure whether an unlocked phone remains available over time and whether the Analytics file is readable after it locks. The first test showed permission denial while locked. A released Mac collector must not depend on Xcode's `devicectl`; the independent `pymobiledevice3` proof establishes another possible connection implementation but its GPLv3 licensing and packaged runtime need separate product decisions. The receiver still needs pairing, authentication, per-device identity, manifest/deduplication, retry/resume, background behavior, and an explicit handoff into `SharedImportQueue`. The synthetic transfer proves transport only, not these product behaviors.

## iPhone X / iOS 16.6.1 follow-up

The iPhone X appeared on the same Wi-Fi through `_apple-mobdev2._tcp` discovery. A one-time USB Trust pairing was performed, and the iOS 16 deployment-target Debug build succeeded. Xcode 27 did not offer this phone as a usable run destination: [Apple's Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes) say on-device debugging is supported on iOS 17 and later. The already signed app included the iPhone X in its development profile, so the experiment build was installed using independent device tools (`pymobiledevice3` initially, then `ideviceinstaller` for the updated build). Xcode was not used to install on this phone.

With the cable removed, MochiLog opened on iOS 16.6.1, discovered the Mac by Bonjour, connected over Wi-Fi, received a 27-byte synthetic probe, and saved it to Documents. The saved file was copied back over USB for verification, with SHA-256 `0a2f4da984fcf92222a97ea2badfd59161494240c5928b9f7de63f61ee82253f`, matching the Mac sender. The probe file was then removed. No battery record was imported. The first receiver attempt had begun browsing but received no Bonjour result; the repeat reported browser ready and one result before connecting. The temporary direct-host fallback in that repeat did not run, so the successful test proves Bonjour discovery rather than reliance on a fixed IP.

The iPhone X currently has no `Analytics-*` log visible in its Settings Analytics list or the independent crash-report service. Consequently, this device cannot prove automatic Analytics acquisition. Over USB, `pymobiledevice3` and `idevicecrashreport` listed diagnostic reports without invoking Xcode. After separate device-tool Trust pairing and Wi-Fi enablement, `pymobiledevice3 --mobdev2` could read lockdown information over Wi-Fi but AFC and crash-report service attempts ended with `Connection was terminated abruptly`. The user chose to exclude iOS 16 from the proposed Mac transfer feature, so no further iOS 16 collector work is planned. This does not change MochiLog's existing iOS 16 app support.

## Developer Mode off / iPhone 17

On the iPhone 17 (iOS 27.2), the user turned Developer Mode off and restarted the phone. `pymobiledevice3 amfi developer-mode-status --native` returned `false`. With the phone unlocked and no cable attached, `pymobiledevice3 crash ls --native` still listed the iPhone's own `Retired/Analytics-2026-09-25-090006.ips.ca.synced`; `crash pull --native` downloaded all 24,989,005 bytes over Wi-Fi. Its SHA-256 was `4def5450783dbb7725deac027c23581a5057a64e0941a6ba30b994cadd34ad82`, identical to the copy acquired before Developer Mode was disabled. This establishes that the tested Analytics acquisition route does not require Developer Mode on that device. The receiver app was not retested with Developer Mode off because the installed Debug build cannot run in that state; [Apple documents](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device) that App Store and TestFlight apps are unaffected.

The acquisition used `pymobiledevice3` and macOS's `remoted` service, not `xcrun` or Xcode's `devicectl`. The [tool's own documentation](https://github.com/doronz88/pymobiledevice3/blob/master/docs/guides/ios17-tunnels.md) describes the native route as requiring no Xcode. This Mac still has Xcode installed, however, so a clean Mac without Xcode remains a required release qualification test. An additional run with `DEVELOPER_DIR` set to an invalid path produced a complete file with the same hash, but the helper process was killed after transfer; do not count that run as a clean end-to-end success.
