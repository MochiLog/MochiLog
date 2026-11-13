# 4.0.2 release verification — 2026-11-13

The user authorized a patch release after TestFlight distribution and thorough debugging, followed by App Review submission. This branch starts at the shipped 4.0.1 source and contains the three November 13 PC pairing/support commits from main. Main remains the independent 4.1.0 beta development line; the signed device-catalog updater is not introduced by this patch.

## Candidate

- Main app, share extension and Watch: 4.0.2 (1069), subject to the live build-number check before upload.
- Japanese/English TestFlight and App Store notes describe user-visible pairing/reconnection, clearer errors and interrupted log transfers. No implementation detail or desktop-only change appears in the App Store release notes.
- The existing committed store assets include both Duo poses (8 images per language), iPhone/iPad/Watch (4 per language each), plus header/search artwork. Upload/readback verification is required for the new store draft.
- Deterministic native checks: 25 passed, covering pairing transport/support ZIP, cloud sharing and errors, identity, selected-record deletion, diagnostic archive/viewer, on-device pairing boundary, current values, manual/shared imports, device profiles, languages, dates, record preferences, Watch payloads, chart logic, store submission safeguards and bundled licenses.

## Pending distribution gate

Initial App Store Connect inspection returned HTTP 403, FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED. The account holder was asked to review the required Apple agreement. No build upload, TestFlight distribution or App Review submission has been completed at this point. Do not treat local build success as publication.

UI, migration, archive/export and final distribution evidence will be appended after verification. Raw responses, private logs, signed binaries, profiles and credentials remain in ignored local build folders.
