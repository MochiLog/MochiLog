# 4.0.0 beta 1059 distribution — 2026-10-19

This maintenance beta publishes the formatted source described in [CODE_FORMATTING.md](CODE_FORMATTING.md). The upload source is `099f8068e59b81eb7eb2508126d844813ea8d4f5` on `experiment/mac-log-transfer`.

- [Signed Release build and TestFlight upload](https://github.com/MochiLog/MochiLog/actions/runs/39141704112): succeeded.
- [TestFlight notes and existing tester groups](https://github.com/MochiLog/MochiLog/actions/runs/39142493185): succeeded.
- Apple processing is `VALID`; both internal and external states are `IN_BETA_TESTING`. The build is not expired.
- Japanese and English build notes are saved. Automatic notification is enabled. Access was verified for both existing internal groups and the existing external group; no new testers were invited.
- The downloaded CI IPA contains version `4.0.0` / build `1059` in the iPhone app, embedded Watch app and share extension. Its Xcode build is `27A266a`.
- The iPhone was also updated to the development build `1059`, built locally with Xcode `27A9275`, and launched successfully. This development installation is distinct from the signed TestFlight distribution.

Keep API keys, provisioning files, downloaded packages and raw distribution logs outside Git. Local verification evidence is in the ignored `Build/beta-release-1059/` directory.
