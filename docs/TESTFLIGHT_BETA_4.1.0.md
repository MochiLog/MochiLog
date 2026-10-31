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
