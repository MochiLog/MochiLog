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
   and submits external beta review if Apple requires it.
5. Confirm VALID processing, note languages, internal/external states and group
   assignment. Report an external review wait as pending, not as availability.

Do not use the App Store release workflow to create this TestFlight version.
Store metadata remains under `fastlane/metadata/`; the beta workflow does not
select a new App Store build, submit App Review or expire earlier beta builds.

The native migration suite passed for the baseline application. The beta build
workflow runs the normal regression checks and distribution signing again.
Heavy builds stay on CI to avoid adding local simulator/build caches.

## Confirmed distribution

Results are recorded here after build processing and distribution verification.
