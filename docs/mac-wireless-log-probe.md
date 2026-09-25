# Wireless Analytics log access probe (2026-09-25)

Status: **wireless Analytics acquisition and app-launch Mac-to-iPhone reception confirmed**. This is a research note and an experiment-only receiver, not a product implementation.

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
