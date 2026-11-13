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

## Final local verification

- Xcode 27.2 RC produced a signed Release archive and fastlane export. All three bundles report **4.0.2 (1069)**; deep/strict verification passes, distribution profiles disable get-task-allow, no test bundle is present and the main app uses **Production CloudKit**.
- Final IPA: **16,282,942 bytes**, SHA-256 `b48402c74c421fd30de6603827cb3e0a5fa28ab90b66ff1c64fc5a41b1395131`. The actual signed IPA contains all eight translations of the new messages.
- A final audit additionally found the support-ZIP preparation catch displaying raw OS errors. The UI now uses a short translated message; the stage and original error domain/code remain in diagnostics. The final signed candidate includes this change.
- iPhone: six UI cases passed, including automatic collection, multiple deletion and large error logs in eight languages, current values, receive controls and localized sharing.
- iPad: collection progress/resume and dated diagnostics in eight languages, PC settings within the settings pane, current values, localized sharing and advanced-page navigation passed.
- Native Duo: detail rotation/sharing, duplicate review, current values and dark Home/Analytics/Settings passed. The synthetic 800x1120 layout harness also passed on iPad. It is now explicitly skipped on phone-class devices: its fixed canvas exceeds the Duo outer display and is not a hinge test. This does not replace the separate native Duo checks.
- Two stale automation expectations were repaired: grouped record controls are located by stable identifiers rather than a standalone device-name label, and PC settings are reached through Automatic Log Collection. Both repaired cases passed on iPad. An unsigned simulator-runner launch was killed before tests connected; rebuilding its ordinary ad-hoc simulator signature resolved that infrastructure failure. These test changes do not alter the shipped app.
- Ten real Core Data/SwiftData migration cases passed, including repeat execution, late/older cloud replicas and save-failure rollback/retry. No persistence model or migration behavior is changed by this patch.
- All 40 committed device screenshots (including both Duo poses) and four header/search assets passed offline count/dimension/RGB checks. They still require upload and readback for a 4.0.2 draft.

## Distribution status and resume

The attempted TestFlight upload stopped at Apple API authorization with the same required-agreement error. No upload completed. App Review has not been submitted, and no existing TestFlight build was expired. The final IPA was rebuilt after the user-facing support-message polish; only the final hash above is the release candidate.

After the account issue is resolved, inspect live versions/build numbers first. Upload this exact verified candidate through fastlane, then publish the 4.0.2 Japanese/English TestFlight notes and existing groups with `scripts/testflight-release.rb`. Confirm VALID and actual external availability. Do not bypass the normal external-TestFlight gate in `scripts/submit-appstore-review.rb`.

After the distributed build's final release-environment check, prepare/select 4.0.2 (1069), upload all screenshot groups and creative assets with STORE_VERSION=4.0.2, verify their exact order/localization/version references, then use the already-authorized App Review submit mode. The candidate's local simulator checks do not prove the reporter's network topology, physical Local Network permission state, or end-to-end Production iCloud sync.

Raw build, test, export, signature, upload and asset evidence is retained under ignored `build/release-4.0.2/` in the release worktree. The Xcode GUI remained at its required-system-components setup, so the UI runs were automated simulator runs, not a successful on-screen Device Hub handoff. No physical-device installation or user-record mutation was performed in this release preparation.
