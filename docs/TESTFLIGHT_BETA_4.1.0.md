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
