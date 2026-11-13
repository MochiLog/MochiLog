# Settings snapshots and plain-language PC errors (2026-11-13)

## User-facing messages

PC QR pairing, discovery, file-transfer connection failures, manual-address changes and unpair persistence failures use short localized messages: what happened and one next action. Do not append system error descriptions, domains, diagnostic IDs or phase names to those messages. Eighteen error keys are translated in all eight existing languages.

The mobile failure model distinguishes a connection deadline, a connected computer not replying, an incomplete reply, explicit local-network denial, general network-policy restrictions, offline/unreachable routes, refused/reset connections, unverified pairing, rejected pairing, invalid PIN format, wrong-device QR, occupied listener port, invalid address, received-data validation and persistence failures. An unrecognized error remains unknown: a raw `-1001` from an arbitrary domain is not treated as a Foundation timeout. NWError POSIX/DNS associated codes are normalized before classification.

Detailed events retain the stable ML-PC diagnostic ID, phase, original domain/code, received byte count, per-route attempt information and passive path observations. Do not log QR contents, PINs, proofs, keys or payloads. Authentication, replay checks and existing pairing identity are unchanged. General policy-denied errors do not assert that Local Network is disabled; that specific guidance requires an explicit NWPath localNetworkDenied observation.

## Support ZIP contents

The one-ZIP support export now includes a separate, pretty-printed `mochilog-*-settings.json` for the local app and available remote settings snapshots. These accompany diagnostic JSON, dated/category logs and the existing missing/empty/limited manifest. The incident day and two preceding days are still exported. Settings describe capture time, not the incident time: capture timestamp, timezone, app/OS version and process ID are explicit. Swift network observations also identify the process instance. Remote data retains its original capture time.

An optional `settingsSnapshot` is exchanged inside the existing authenticated diagnostic report. Old peers ignore the new field; if a peer has not supplied it, or it was omitted to meet the report limit, the manifest states that it is unavailable. Do not fabricate remote settings. Pairing is not required for a local support export. The 8 KiB snapshot bound, existing 16 KiB wire-report cap, ZIP file/byte caps, safe flat names and symbolic-file rejection remain enforced. Report-budget fallback removes optional settings rather than extending the protocol limit.

## Permission evidence

- iPhone/iPad: camera authorization, cellular-data restrictions, notification authorization and background-refresh availability use their public read APIs. Capture does not request permission. iOS-on-Mac avoids initializing cellular APIs.
- Local Network has no general public permission-query API. The snapshot says unknown and separately records recent actual NWPath denial/interface/cost observations with timestamps and process instance IDs. A satisfied path or listening socket is not a global permission grant. Older observations may predate the current process.
- Analytics-sharing status, Developer Mode and other VPN apps are not probed by the settings export; unavailable values remain unknown.
- Mac: login-item status comes from SMAppService when running in an app bundle. Firewall rule status stays unknown; no TCC/firewall database or shell query is made.
- Windows: explicitly named app preferences and the current token are read in C#. Run-key registration is separate from unknown startup approval; firewall rules stay unknown. No PowerShell aggregation or arbitrary registry dump is used.

Settings are an allowlist of relevant toggles, retention limits and counts. They exclude raw preferences/registry state, credentials, pairing files, addresses, account details and private keys. They do not load the Mac pairing state/Keychain merely to generate a settings report. Network observation storage is bounded to eight entries / 8 KiB and protected by a lock. The shared Swift diagnostic models explicitly opt out of default main-actor isolation for safe background Network callbacks.

## Validation

The Swift settings tests cover persistent bounded observations, unknown versus explicit denial, original domain/code classification, unique diagnostic IDs, no secret preference dump and old-peer extraction. Actual local TCP tests cover no response versus partial response, framed completion without EOF, fallback, cancellation and bounds. Mac protocol tests open the actual support ZIP and check that a ready listener still leaves Local Network permission unknown. Existing authentication, replay, ACK, cloud-sharing and diagnostic archive tests remain enabled.

Physical permission-denial UI and the original reporter's network topology are not established by these tests. Historical missing QR events cannot be reconstructed; the reporter's original cause remains unconfirmed.

Reference: [Apple TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy).

### Completed checks

- Mobile: `bash scripts/test-pairing-support.sh` passed; full Xcode 27.2 RC iOS Simulator build including Share Extension and Watch passed.
- Mac: `bash scripts/test-transfer-protocol.sh` passed; full Xcode 27.2 RC Release build passed.
- Windows physical host: support export tests and full protocol suite (including the new settings test) passed; WinUI Release x64 build passed, zero errors. Existing analyzer/WinRT warnings remain. Formatting check passed for changed C# sources.
- Both Swift catalogs contain all 18 new error keys in all 8 languages; no system domain, -1001 or diagnostic ID is embedded in those messages.
- No production pairing/records, firewall settings or permissions were changed. No installer/device update, release upload or support email was sent in this verification.
