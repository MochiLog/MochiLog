# Device-initiated OS pairing — 4.0.0 (1042)

Status: implementation and local policy/type checks complete; full app/UI and first OS authorization on a physical device still pending. Do not infer first-time success from the earlier PC-credential-reuse tests.

## Sources and licenses

[StikPair](https://github.com/StikDebug/StikPair) is the behavioral reference requested by the user: publish a pairable host, approve it in Settings, show the six-digit confirmation code, then retain pairing credentials. Its [license](https://github.com/StikDebug/StikPair/blob/main/LICENSE) restricts commercial use. No StikPair source, wrapper, binary or assets are bundled.

Implementation is independently written in Swift using the already bundled MIT [idevice](https://github.com/jkcoxson/idevice) at d32c8189c51c2789496b0768039419c3705498c3. The public FFI APIs are pairable_host_prepare, pairable_host_accept_fd and rp_pairing_file_to_bytes. No extra Python runtime or external tool is introduced.

## Boundaries

- Explicit user action only; never automatically initiate pair-setup after a failed diagnostic read.
- Native SRP random PIN flow, pinless pairing disabled. PIN and key material are absent from debug/support logs.
- IPv4, IPv6 and mapped IPv4 peers are checked against this device's interfaces before the native handshake. A different LAN device is rejected.
- A fresh host name/identity per attempt preserves existing PC trust and earlier on-device trust. The actual name is shown in the app for Settings selection.
- Credentials remain in memory until validated and written to WhenUnlockedThisDeviceOnly Keychain. No exported credential file is needed. Cancellation/failure does not replace the saved credential.
- Socket shutdown interrupts the native worker; only that worker closes its FDs. Stale callbacks are ignored using an attempt token. Bonjour, notifications, background tasks and the PIN are cleaned up.
- BGContinuedProcessingTask is requested only for explicit pairing (maximum five minutes). If unavailable, a bounded UIKit background task is used with a visible limitation. No fake audio, location or indefinite keepalive.
- Existing acquisition remains verify-only, checks UniqueDeviceID against the paired device, and uses separate connections for battery and file reads. Device-local reads pause during pairing and resume with the user's unchanged opt-ins.
- iOS apps running on Mac never register/start this pairing path. PC/iCloud records and pairings are not migrated or reset.

## Verification

scripts/test-local-pairing.sh uses the actual address policy and rejects foreign IPv4/IPv6, including mapped addresses. Targeted iOS 27.1 Swift typecheck passes. The CI UI suite checks on-device setup and current-battery controls without a PC in all eight languages on iPad and iPhone. Physical OS passcode/PIN approval requires the user's action; it cannot be inferred or silently supplied by automation.
