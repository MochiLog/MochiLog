# 4.1.0 TestFlight beta

The first build is 4.1.0 (1064), based on the verified 4.0.0 (1063) application.
Only version/build metadata and TestFlight notes change. The App Store 4.0.0
review continues with the previously submitted build.

## Future beta updates

1. Keep all main, share-extension and Watch target versions in sync in
   `MochiLog.xcodeproj/project.pbxproj`. Use a fresh build number for each upload.
2. Update `fastlane/testflight/ja.txt` and `en-US.txt` for the changes testers
   should check. Both first lines must be the exact marketing version, such as
   `4.1.0`. The publishing script validates both files before changing any notes.
3. Commit and push, then run the **iOS Build** workflow with
   `upload_to_testflight=true` and the new build number.
4. After the signed build/upload succeeds, verify the resulting Release IPA and
   run **Publish TestFlight notes and groups** with mode `publish`, marketing
   version `4.1.0` and the same build number. This uses the existing tester groups
   and submits external beta review if Apple requires it. The workflow's version
   field defaults to `4.1.0`; keep the build number specific to the uploaded build.
5. Confirm VALID processing, note languages, internal/external states and group
   assignment. Report an external review wait as pending, not as availability.

Do not use the App Store release workflow to create this TestFlight version.
Store metadata remains under `fastlane/metadata/`; the beta workflow does not
select a new App Store build, submit App Review or expire earlier beta builds.

The native migration suite passed for the baseline application. The beta build
workflow runs the normal regression checks and distribution signing again.
Heavy builds stay on CI to avoid adding local simulator/build caches.

## Confirmed distribution

- [Signed build/upload 40198618051](https://github.com/MochiLog/MochiLog/actions/runs/40198618051) succeeded from `4b9c785eae8ae186aa3732c532e1022827e3c613`, using Xcode 27.1. All normal build-workflow regression checks passed.
- The Release IPA is 16,106,930 bytes, SHA-256 `da28af2477ca9e2ae1de741a547924885c7b1a4db1a43f346739bada90ac2cb8`. Deep/strict signature verification passed. Main app, share extension and Watch app all report 4.1.0 (1064). Distribution profiles disable `get-task-allow`, no test bundles are present, and the main app's signed CloudKit entitlement targets Production.
- [TestFlight publishing 40199637603](https://github.com/MochiLog/MochiLog/actions/runs/40199637603) succeeded. Apple processing is `VALID`, `expired=false`, internal state `IN_BETA_TESTING`. Existing internal `iOS16` and `iCloud同期` groups and external `main` group are assigned; notifications are enabled.
- Japanese/English build notes were published (117/231 characters). The first build is the baseline for upcoming 4.1.0 improvements.
- External beta review was submitted successfully. Apple's confirmed state is **`WAITING_FOR_BETA_REVIEW`**, so external availability remains pending Apple's review.
- [Read-only store verification 40199733645](https://github.com/MochiLog/MochiLog/actions/runs/40199733645) confirmed that App Store 4.0.0 remains `WAITING_FOR_REVIEW`, selects build 1063 with `expired=false`, and retains the exact committed Japanese/English store notes. No App Store 4.1.0 version was created.

## Xcode 27.2 update — 2026-10-27

- Build **4.1.0 (1065)** was built locally from `c1f5db9` using Xcode 27.2 RC (27B48). Product functionality is unchanged; version/build metadata and Japanese/English testing notes were updated.
- The iPhone 17 and iPad Pro M4 simulators, both on iOS/iPadOS 27.2 (24B114), passed the live-battery opt-in/layout and localized-record sharing UI checks: four successful test runs. Device-library regression checks, multi-file share-extension registration and bundled license checks also passed.
- The signed Release archive and fastlane IPA export succeeded. All three bundles (main, share extension and Watch app) report 4.1.0 (1065), `DTXcode=2720`, distribution signing and `get-task-allow=false`. The main app's signed CloudKit entitlement is Production. Deep/strict signature verification passed; no test bundles are included.
- IPA size: **16,139,054 bytes**. SHA-256: `bc1fb1cc4c61e448794e2278aacfe9e77d2a9b386d35fadb61681d623114cf91`.
- fastlane uploaded the verified IPA. Apple processing is **VALID**, `expired=false`. Japanese and English TestFlight notes were saved (87/173 characters).
- Existing internal groups `iOS16` and `iCloud同期` and external group `main` all have confirmed build access. Automatic notifications are enabled. The external beta-review request succeeded and Apple's resulting state is **IN_BETA_TESTING**; internal state is also **IN_BETA_TESTING**.
- Debug simulator windows were shown through Xcode 27.2's Device Hub after its first-launch system-component installation was authorized. Both simulator apps were left running for inspection.
- Local build/test/export/upload/verification evidence is under ignored `build/testflight-1065/`. Credentials and raw device data are not part of the repository. App Store release metadata and review submission were not changed.

For a local export from an existing signed archive, fastlane's `build_app` action uses `skip_build_archive:true`, `export_method:app-store` and an explicit export-options plist. Set the plist method to `app-store-connect` and include all three bundle IDs in `provisioningProfiles`; automatic profile detection alone found only the share extension in this environment. Keep `manageAppVersionAndBuildNumber=false` so Apple receives the verified build numbers.

## iPad mini (A20 Pro) support — 2026-11-01

- Build **4.1.0 (1067)** includes the additive iPad mini (A20 Pro) catalog entry: Wi-Fi and Cellular identifiers, board IDs, model numbers, SoC and 4,900mAh reference. The user confirmed retaining iPad mini (A17 Pro) at 5,034mAh. No persistence schema or new migration is needed.
- The same product change is prepared for App Store 4.0.1 (1066) on `release/4.0.1`. Main retains 4.1.0 version metadata. Japanese/English TestFlight notes describe the new model and ask testers to check imports, names/capacity, automatic collection and iCloud sync.
- Xcode 27.2 RC produced the signed Release archive and IPA. All three bundles report 4.1.0 (1067), distribution signing and disabled `get-task-allow`; Production CloudKit and deep/strict signature verification passed, with no test bundles present.
- IPA size: **16,139,811 bytes**. SHA-256: `4d5b3a80c95814302bf75d95fde0103fbf7cb976481949af35350266924d7440`.
- Catalog/profile regression suites and share-extension/license checks passed. Two UI smoke tests each passed on iPhone 17, iPad Pro M4 and Duo simulators, for six successful runs. The new profile was also inspected in Device Hub.
- Upload processing is **VALID**, `expired=false`. Existing internal `iOS16` and `iCloud同期` groups and external `main` group are assigned. Japanese/English notes are published and automatic notifications are enabled. Both internal and external states are **IN_BETA_TESTING**.
- Evidence is under ignored `build/testflight-1067/` and `build/release-4.0.1-1066/`; App Store preparation and its separate final submission status are documented in `DEVICE_LIBRARY_RELEASE_2026-10-25.md`.

## Independent device-data updates — 2026-11-01

- **4.1.0 (1068)** adds automatic, signed device-reference updates. The UI under Advanced Settings → Device Library → Device data updates provides an opt-out, manual check, data revision and last successful check time, translated into all eight app languages. New-model imports can refresh the same data before saving. Manual edits remain active; downloaded data never rewrites saved records or supplies executable migration rules.
- Implementation and local archive source: `ee56833`. The main app, share extension and Watch app all report 4.1.0 (1068). Xcode 27.2 RC produced the signed Release archive/export; deep/strict signature verification passed, distribution profiles disable `get-task-allow`, the main CloudKit entitlement is Production, and no test bundles are included.
- IPA: **16,224,821 bytes**, SHA-256 `ef9705c3f70e9ffa74ce16c2c582f61f5e4c4a1357ee6057a65efb1ceb21e0ed`.
- Initial revision `2026110101` contains 121 profiles, matching the bundled catalog, and is published at the fixed GitHub raw URL. A fresh download passed Ed25519 verification and exactly matches the reviewed JSON. Private signing material is retained only in the Mac's Keychain. Tool source and data are maintained in the MochiLog Organization; [operation instructions](DEVICE_CATALOG_UPDATES.md) describe data-only publication and rollback by a higher revision.
- [Device catalog CI 41226719619](https://github.com/MochiLog/MochiLog/actions/runs/41226719619) passed signature/source matching, cache/tamper/retry/manual-setting tests and existing library/profile regressions. Share-extension and bundled-license checks passed locally.
- iPhone 17 and iPad Pro M4 simulators each passed the eight-language catalog-settings test: 16 language/device combinations. Both downloaded caches exactly matched the published envelope. Existing category/general-settings smoke tests also passed on both devices, followed by four successful regression runs for localized record sharing and device-profile editing/restoration.
- The first UI test exposed command-line preference values being interpreted as strings; the updater now reads Boolean preferences through UserDefaults' Boolean accessor. Final UI results passed after that correction. Unknown-model retry timing is also persisted so app restarts cannot bypass it.
- Device Hub displayed the new Japanese settings page on the opened Duo simulator, including automatic checks on, revision, localized last-check time and the successful result. The desktop UI window was left visible for inspection.
- The opened Duo then also passed the eight-language settings test, bringing catalog UI coverage to **24 language/device combinations** across iPhone, iPad and Duo. The revision assertion accepts future valid data editions instead of hard-coding today's revision. An additional injected-download test confirmed that a previously unknown model becomes resolvable after an authenticated update, and that a subsequent tampered response preserves both the active profiles and last-good cache.
- App policy text is updated in all eight languages to disclose GitHub catalog requests and the automatic-check opt-out. Web Japanese/English disclosure was updated in `MochiLog-Web` commit `f645b41`, deployed as Worker version `ed3b2bcb-f498-47f6-bc2b-4cb5fdb06d87`, and checked through both public locale URLs.
- fastlane uploaded the verified IPA. Apple's processing state is **VALID**, `expired=false`; **internal and external states are both IN_BETA_TESTING**. Existing internal `iOS16` and `iCloud同期` groups and external `main` are assigned. Japanese/English notes and beta descriptions are verified; automatic notifications are enabled. No App Store 4.1.0 review was submitted.
- Local evidence: ignored `build/device-catalog-verification/` and `build/testflight-1068/`. Credentials and raw API/device responses remain outside version control.

## Pairing/support fixes consolidated into 4.1.0 — 2026-11-14

The user canceled the separate 4.0.2 release and chose 4.1.0 for distribution. Build 1069 was expired in TestFlight. Apple rejected deletion of the existing update draft, so the editable draft was renamed to 4.1.0 and its old build relationship was removed. No 4.0.2 store version remains. Earlier 4.0.1 and 4.1.0 builds were preserved.

Main already contained the pairing/support changes alongside the signed catalog updater; they were not cherry-picked a second time. Source `a3db7b0` prepares **4.1.0 (1070)** across the main app, share extension and Watch app, and combines the Japanese/English release and testing notes. App Store notes describe only user-visible mobile changes.

The signed Release archive/export passed deep/strict code-signature verification. All three distribution bundles report 4.1.0 (1070), Xcode 2720, no get-task-allow; the main CloudKit entitlement is Production and no test bundle is included. The actual IPA includes the short support-export error in all eight languages. Size: **16,368,111 bytes**, SHA-256 `c3bc7a7542340ffac28c788486d85be2e03a3657b76f53e6d3f7df5f5df17acc`.

Catalog signature/cache/rollback/manual-setting and device-profile checks, pairing/slow-progress/route/error/settings/ZIP checks, all eight language catalogs, tester-group assignment and review-submission safeguards passed. The first combined runner referenced a nonexistent final test filename; the corrected full runner passed. This was a harness invocation error, not a product failure.

Archive took 57.6 seconds, export 31.8 seconds and fastlane upload 65.8 seconds, using the existing local build cache. UI results, Apple's distribution states and store verification are recorded below after completion. Ignored local evidence is under `build/testflight-1070/`.

### Final distribution and review submission

- The signed IPA above was accepted by Apple as **VALID**, `expired=false`. Japanese/English testing notes are published. Existing internal groups `iOS16` and `iCloud同期` and external `main` all have confirmed access, notifications are enabled, and **both internal and external states are IN_BETA_TESTING**.
- On iPhone 17 and iPad Pro M4 simulators, six selected UI tests passed with zero failures. Catalog settings were exercised in all eight languages on both devices (16 language/device combinations); automatic-collection controls were exercised in eight languages on iPhone. iPad settings-pane navigation and localized record sharing on both devices passed. iPhone run: 509.2 seconds; iPad run: 181.7 seconds. No new product change was needed.
- The actual TestFlight Mac installation was updated from 4.0.2 to **4.1.0 (1070)**. The installed wrapper metadata matches. The app opened the preserved Home records and the native settings panes; its catalog-update page showed revision 2026110101, a successful current-data result, and a new last-check time after a manual check. PC collection controls remain hidden in the Mac-hosted iOS app. No personal history, pairings or synchronization preferences were manually changed. This does not establish a new QR pairing or a fresh multi-device iCloud round trip on physical iPhone/iPad hardware.
- The App Store draft selects the same VALID build. All localized metadata and fresh 4.1.0 image references passed readback: 40 ordered device images including Duo inner/outer poses, plus four header/search assets. Assets from the previous draft were replaced only within this editable version; approved 4.0.1 was not changed.
- After the UI checks and external TestFlight availability were confirmed, the already-authorized App Review submission completed: **4.1.0 (1070), WAITING_FOR_REVIEW**, submission `4e85a20d-88e2-4d06-b4a2-010efd6a5631`. General App Store publication remains subject to Apple's review; release type is AFTER_APPROVAL.
- The canceled **4.0.2 (1069)** now reports **EXPIRED for both internal and external testing**. The App Store version list contains 4.1.0 rather than a 4.0.2 draft. The old release journal is marked superseded. Earlier valid builds were not expired.
- Final logs: `publish.log`, `ui-iphone.log`, `ui-ipad.log`, `store-verify.log`, `store-submit.log` and `status-builds.json` under ignored `build/testflight-1070/`. Original reporter-specific network conditions remain unverified; detailed diagnostics in this release are intended to make any recurrence attributable.

### App Store publication confirmed — 2026-11-15

The user requested the PC distribution update and general App Store publication after debugging. The existing 4.1.0 (1070) submission had already passed review: App Store Connect reports READY_FOR_DISTRIBUTION / READY_FOR_SALE, and the public Japanese lookup returns 4.1.0 with currentVersionReleaseDate 2026-11-14T15:56:48Z (November 15, 00:56 JST). The published version is the same signed build whose simulator, protocol and Mac-hosted TestFlight checks are recorded above. No new mobile binary was necessary or uploaded for this request; the 4.0.2 build remains expired.

The PC 1.0.1 distribution follow-up and its actual machine checks are documented separately in the Mac and Windows repositories. A customer-reply draft must describe connection improvements without claiming the reporter's original network failure was conclusively reproduced or resolved.
