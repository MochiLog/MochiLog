# PC pairing diagnostics and support exports (2026-11-13)

## Evidence and scope

A support report containing one iOS diagnostic JSON and two daily combined logs did not contain a PC QR pairing failure, although the user reported a timeout. App pairing was not complete, so no PC reports had been received. The reported incident time was the email submission time; investigation covered all supplied events.

Three attachments alone do not prove that event categories were lost. DiagnosticLogArchive already saved versioned feature files and the complete daily compatibility stream. However, the support composer attached only that daily stream. More importantly, QR preparation/confirmation errors could reach the UI without entering either stream. Previously missing events cannot be reconstructed retrospectively.

The reporter's original timeout is not conclusively attributed to a particular network or server failure. Do not claim that this incident is resolved based solely on the new tests.

## Changes

- Mobile records QR scanning and camera setup/runtime failures, validation stages, model/identity conflicts, protocol/session correlation, challenge/confirmation exchange, proof validation, record relinking and credential storage failures. Keychain failures retain the numeric OSStatus.
- The transport records a random attempt ID, stage, route index/count, allowed cellular policy, path state, connect/send milestones, timeout phase and received byte count, fallback, elapsed time and cancellation. It does not record QR contents, PINs, keys, proofs or payloads.
- Mac and Windows record invitation creation and bounded per-session handshake outcomes. Public session IDs correlate both sides. These diagnostics do not weaken authentication, replay protection or credential storage.
- A separate framing defect was reproduced: the old pairing receiver waited for TCP EOF even when a complete newline-delimited response was available. It now finishes at the newline, rejects oversized/truncated frames, observes cancellation and retains route fallback. This reproduction does not establish the cause of the original report.
- Support exports snapshot original feature files and complete daily streams for the selected incident day and two previous days, plus diagnostic JSON. Export work runs off the UI thread. Mobile includes locally cached diagnostics for every paired computer.
- A schema-1 `mochilog-support-manifest.json` lists included, missing, empty, unreadable and budget-omitted files and unavailable remote sources. A locally missing feature directory is explicit. Empty placeholder attachments are not generated.
- The snapshot budget is 12 MiB / 96 payload files plus the small manifest. Copies use 64 KiB chunks and fixed initial file sizes. Symbolic files/day directories are skipped. PC support copies files; mobile only loads the bounded prepared attachments into MessageUI.
- Mac support is available before app pairing. A failure to pair no longer makes that support entry unusable.

## Compatibility and limits

The wire protocol, QR versions, saved pairing keys and daily archive byte offsets are unchanged. Existing pairings do not require replacement. Daily streams remain append-only.

Remote diagnostic exchange intentionally still uses the complete daily compatibility stream; it does not recreate the sender's physical category files on the receiver. The manifest distinguishes that situation from missing diagnostics. A phone that never completed app pairing cannot export PC data it never received; export from that PC separately.

This patch changes attachment generation, not an email provider's size limits or the delivery behavior of third-party mail clients. The automated export tests do not send mail.

## Verification

- `bash scripts/test-pairing-support.sh`: fragmented complete response while the peer stays open, timeout phase, fallback, cancellation, oversized/truncated frames and secret-free transport logs; split/daily export, missing source/day manifest, symbolic file rejection and budget limits.
- Full Debug iOS simulator build, including Watch target, with Xcode 27.2 RC. No signing, installation or distribution is performed by this check.
- Equivalent export and handshake coverage lives in the Mac and Windows companion repositories. No private support attachments are checked in.
