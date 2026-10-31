# DeviceLibrary correction — 4.0.0 (1063)

## Scope and data safety

- Correct the 20 reviewed model-name, board and SoC references. Preserve the explicit saved Watch name when repairing old representative identifiers.
- Adopt the Apple EU Product Information Sheet rated capacities for the eight reviewed iPad models. Exact names and old/new values are listed in `MochiLog/Migrations/README.md`.
- Put versioned corrections and both persistence adapters under `Migrations/DeviceLibrary/`. The v5 capacity migration matches the saved name and exact previous reference; manual profile history, measurements, identities and dates are retained.
- Check later imports and old cloud replicas through the same entry point. Corrected values do not match the old-value predicates, preventing repeated or reversed corrections.
- Recompute the reference-based diagnosis only when a raw measurement exists. Failed saves roll back and do not mark the migration complete.
- No persistence attributes were added or renamed. No CloudKit schema deployment is required for this change.

## Verification

- Pure catalog and manual-profile tests passed locally, including all eight capacity corrections and unaffected references.
- Baseline CoreData/SwiftData migration CI [40126491595](https://github.com/MochiLog/MochiLog/actions/runs/40126491595): six tests passed with no failures.
- Full suite including the iPad upgrade, repeat pass, old replica, custom value, no-raw-data case and save-failure rollback: [40127540645](https://github.com/MochiLog/MochiLog/actions/runs/40127540645), **10 tests passed, 0 failures**.
- The combined audit retains all 605 rows and 37 difference/history rows. The 20 metadata fixes, eight iPad capacities and earlier Duo correction are marked corrected. Source conflicts remain explicitly separate.
- The existing workbook was updated in place. Both tables, filters, freeze panes and conditional formatting were preserved; affected values, formulas and rendered layout were verified.

## Distribution procedure

The user authorized App Review submission on 2026-10-25, **after TestFlight**.

1. Pass the migration suite before uploading 4.0.0 (1063).
2. Use the signed `ios.yml` build with `upload_to_testflight=true` and build number `1063`.
3. Inspect the resulting Release IPA and publish the Japanese/English TestFlight notes to the existing groups.
4. Wait for external TestFlight availability. Select the same VALID build for the editable 4.0.0 store version.
5. Verify committed localized metadata, both Duo poses, iPhone/iPad/Watch screenshots and header/search artwork.
6. Invoke `appstore-release.yml` in explicit `submit` mode. Its default remains read-only inspection. Preparation/verification never submit a review.

The submission helper checks the current selected build, external TestFlight state and exact version-only review items. It preserves unrelated submissions, reuses a matching draft and verifies the resulting state. Six local safeguards tests passed.

Public notes describe corrected incorrect values in battery/device information without naming specific corrected models or discussing migration internals. Final distribution states are recorded below only after confirmation.

## Confirmed distribution

- [Signed build and upload 40128726763](https://github.com/MochiLog/MochiLog/actions/runs/40128726763) succeeded from `9e099b5710c852c78af0e4de2b3386df08eb6965`. Application and migration-test sources match the verified `8822f80` revision; subsequent changes before packaging only prepared release tooling/documentation.
- The Release IPA is 16,106,933 bytes, SHA-256 `8778dabf69cf259e321dd0eab91ff1c8a5fd6daf60337accf483f12cdd643b1a`. Deep/strict signature verification passed. Main app, share extension and Watch app all report 4.0.0 (1063), distribution profiles disable `get-task-allow`, and no test bundles are present. The main app's signed CloudKit entitlement targets Production.
- [TestFlight distribution 40129466590](https://github.com/MochiLog/MochiLog/actions/runs/40129466590) succeeded first. Build processing is `VALID`, `expired=false`; internal and external states are both `IN_BETA_TESTING`. Existing `iOS16`, `iCloud同期` and external `main` groups are assigned; automatic notifications are enabled. Japanese/English notes are published.
- [Store preparation 40129631202](https://github.com/MochiLog/MochiLog/actions/runs/40129631202) selected the same VALID build 1063 and saved the exact committed localized notes/descriptions.
- [Store verification and submission 40129719047](https://github.com/MochiLog/MochiLog/actions/runs/40129719047) verified all 40 screenshots, including eight Duo images per locale, plus four header/search assets. Only the requested 4.0.0 version was submitted.
- Apple confirmed both the review submission and app version as **`WAITING_FOR_REVIEW`**. Submission ID: `2984d66e-853b-4e75-bc86-dc15524b85c1`. This is a submitted review, not an approval or public release.
- AltStore PAL remains on its approved package until Apple's corresponding 4.0.0 notarized package is available and validated.

## iPad mini (A20 Pro) addition — 2026-11-01

- Add Wi-Fi `iPad19,1` / `J510AP` / `A3595` and Cellular `iPad19,2` / `J511AP` / `A3596`, `A3597`, with the A20 Pro SoC and a 4,900mAh reference capacity. Both variants share one standard selectable device profile.
- Capacity evidence: [Apple EU specifications and product information sheets](https://www.apple.com/ie/ipad-mini/specs/) list 4,900mAh for both variants. Identifiers and boards were checked against AppleDB source [Wi-Fi](https://github.com/littlebyteorg/appledb/blob/db24da70be6f7e7c305c7c871948d1051e903b34/deviceFiles/iPad/iPad19%2C1.json) and [Cellular](https://github.com/littlebyteorg/appledb/blob/db24da70be6f7e7c305c7c871948d1051e903b34/deviceFiles/iPad/iPad19%2C2.json).
- The user confirmed retaining the A17 Pro reference at 5,034mAh. Existing correction migrations and manual reference capacities remain intact. This is an additive catalog update, so no new record migration or CloudKit schema change is required.
- Battery calculations use mAh. The app does not store Wh reference values; no Wh-to-mAh conversion is introduced. The supplied 18.7Wh and Apple's specifications-page 18.9Wh are not used interchangeably in calculations.
- Apply the same catalog change to App Store 4.0.1 and TestFlight 4.1.0. Distribution results are recorded after verification.

### Verified builds and distribution

- Catalog changes and regression checks are committed as `2f373b5`. Main is 4.1.0 (1067); the same product changes are on `release/4.0.1` as 4.0.1 (1066). Keep release version metadata separate from main.
- Device-library and profile regression suites passed, including both new identifiers, boards, model numbers, catalog ordering, the unchanged A17 Pro reference, and persistence of a custom capacity. Share-extension registration, bundled licenses and release-tool safeguard checks also passed.
- Xcode 27.2 RC (27B48) ran the live-battery opt-in/layout and localized-record sharing checks on iPhone 17, iPad Pro M4 and iPhone Duo simulators: six successful test runs. Device Hub also displayed the new profile with 4,900mAh, A20 Pro and both identifiers/boards.
- Both signed Release exports passed deep/strict signature checks. Main app, share extension and Watch app have matching marketing/build versions, distribution profiles with `get-task-allow=false`, and no test bundles. The main app's CloudKit entitlement targets Production.
- 4.0.1 (1066): 16,139,797-byte IPA, SHA-256 `6daebcd3cabb432f195cacfbe4df42db3b5e7633c19efae1d1db7c5595315604`.
- 4.1.0 (1067): 16,139,811-byte IPA, SHA-256 `4d5b3a80c95814302bf75d95fde0103fbf7cb976481949af35350266924d7440`.
- Both uploads are VALID and not expired. Existing internal `iOS16`, `iCloud同期` and external `main` groups are assigned, automatic notifications are enabled, and Japanese/English notes are saved. Build 1067 is IN_BETA_TESTING internally and externally. Build 1066 is IN_BETA_TESTING internally and WAITING_FOR_BETA_REVIEW externally at verification time.
- App Store 4.0.1 selects build 1066. Preparation and read-only verification succeeded for the localized metadata, 40 screenshots (including both Duo poses) and four header/search assets. Final App Review submission was explicitly authorized by the user on 2026-11-01 and completed as recorded below.
- The screenshot uploader now rotates only stale placements belonging to the editable version when Apple's ten-image group limit prevents adding all replacements first. Six focused tests cover slot limits, preserving desired assets and rejecting foreign/unresolved version relationships. A separate API check confirmed that public 4.0.0 remains READY_FOR_DISTRIBUTION with all 40 original screenshots and four creative assets unchanged.
- Local evidence is under ignored `build/release-20261101/`, `build/release-4.0.1-1066/` and `build/testflight-1067/`. Do not commit credentials or raw API responses.

### App Review submission — 2026-11-01

- The user explicitly authorized submitting 4.0.1 (1066). All selected-build, localized metadata and artwork verification passed again immediately before submission.
- The normal helper requires the identical build in external TestFlight. Build 1066 was still awaiting external beta review, while 4.1.0 (1067), with identical `MochiLog/` and `Tests/` sources on main and `release/4.0.1`, was already externally IN_BETA_TESTING. For this explicitly authorized submission, an ignored one-off runner verified both source equivalence and the live 1067 distribution state, then accepted the internally testing 1066 with its external beta review already submitted. All other exact-build, draft ownership, single-version, concurrency and final-state guards were retained. The ordinary workflow's strict default was not changed.
- Apple's submission validation identified one unanswered age-rating attribute: `socialMedia`. The editable app-info declaration was updated to `false`, reflecting the app's absence of social-media features. The API confirmed that all other rating answers remained unchanged. The public app-info declaration was not edited.
- Submission **`bb45f764-b2e8-47f2-ad65-1f94ce71e4ce`** contains only App Store 4.0.1 and selects build **1066**. Apple confirmed **WAITING_FOR_REVIEW**; this is submission, not approval or public availability. Release type is **AFTER_APPROVAL**.
- Local submission evidence, including Apple's detailed validation response and independent final readback, is under ignored `build/release-20261101/`. No credentials or raw API responses are committed.
