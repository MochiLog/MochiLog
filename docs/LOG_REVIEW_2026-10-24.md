# Runtime review — 2026-10-24

Reviewed the native Mac/Windows snapshots, their October 24 activity archives, and cached iPhone/iPad diagnostic histories without reaggregating runtime objects in PowerShell. Raw data and device identifiers remain in ignored Build directories.

- Both host daily files were saved by Mac shortly after 09:00 JST. iPhone/Watch transfer and duplicate preflight ran when the iPhone connected later. Windows also stored the iPad daily file when its authenticated endpoint became available.
- AFC permission-denied/remote-pairing timeouts recovered on later attempts. A stored current-day file and a partially completed historical listing are separate states; retained unclassified historical candidates do not invalidate the verified current-day file. No longer cooldown was added.
- Repeated authenticated diagnostic chunks generated misleading skipped-offset warnings during file-offer/ACK exchanges. Receivers now compare at most 8 KiB of existing overlap, accept identical retries without further writes, append only a verified missing suffix, and reject conflicts/gaps. The transfer envelope, nonce replay protection, pairing keys and queue ACK rules are unchanged.
- Regression checks cover exact retries, partial overlap, conflicting data, gaps, negative offsets and per-chunk/day size bounds. Existing archive exchange, encryption and multi-device tests remain required.
- At inspection Mac used approximately 48 MiB resident with no active helper; Windows used approximately 244 MiB private committed memory. Cumulative allocated bytes are not retained memory. A snapshot does not prove indefinite absence of leaks.

Formal release targets: mobile 4.0.0 (1060), Mac 1.0.0 (38), Windows 1.0.0. App Store approval and PAL's notarized package are external steps and must be reported by their actual states.

## Release verification

- Mobile: 4.0.0 (1060), built and uploaded by [CI 40093425728](https://github.com/MochiLog/MochiLog/actions/runs/40093425728) from `f596b90`. The application, Watch, share extension, shared sources and Xcode project on main still match that successful release build. Later changes are store artwork, metadata, documentation and capture tooling.
- Main's 16 Foundation regression scripts and eight-language catalog audit passed. Open-Duo Japanese/English UI capture tests also passed. A screenshot API returning black window crops was corrected in the capture tooling; actual active-display captures were checked visually and composed without altering the application UI.
- [Final App Store verification 40103214556](https://github.com/MochiLog/MochiLog/actions/runs/40103214556) checked selected VALID build 1060, exact committed descriptions/release notes, and current-version ordered placements: each locale has 8 Duo screenshots (4 open + 4 closed), 4 iPhone, 4 iPad and 4 Watch screenshots. All 40 images are active. The version remains PREPARE_FOR_SUBMISSION. Review submission belongs to the user.
- App Store and TestFlight notes contain 28 mobile-facing bullets per language after the October 25 wording correction. Internal implementation, duplicate-sync protection, support diagnostics and PC-only features are excluded from the mobile release notes. Technical findings stay in this document.
- CloudKit Development/Production schemas match all 27 stored record properties and their expected types/indexes; see [the schema check](CLOUDKIT_RELEASE_CHECK_2026-10-24.md). No schema deployment, private-record reset or permission change was needed.
- Mac: 1.0.0 (38), [successful CI 40093323039](https://github.com/MochiLog/MochiLog-Mac/actions/runs/40093323039), source `b6e1baa`. App/DMG signing, Apple notarization/stapling, Gatekeeper and public Sparkle feed/archive signatures passed. DMG SHA-256: `d617719c499fbbcb51a6afdd27a42e417ad4ac318686e9347632d83123f55943`.
- Windows: 1.0.0, [successful CI 40093349512](https://github.com/MochiLog/MochiLog-Windows/actions/runs/40093349512), source `bd850fd`. Protocol tests, 15 Python tests, installer/uninstaller and standalone collector checks passed. Installer SHA-256: `db6a73c462239d5178d3c879f163ac358e249217ebc4bbb78adfcbb811bed78a`. The installer remains unsigned; no signing certificate is configured. Both current and legacy updater filenames publish the same verified installer.
- Both PCs were updated without losing their saved pairing identities. Mac authenticated traffic from iPhone/iPad was observed after installation. Windows installation/version/pairing preservation was checked; a fresh post-installation encrypted iPad transfer was not confirmed during the final attempt. Watch hardware installation was not part of this final verification.
- Mac and Windows 1.0.0 and the mobile 4.0.0 source release are public on GitHub. The public website advertises PC 1.0.0 and explicitly describes mobile App Store review preparation. Mobile 1060 is available internally in TestFlight; external beta review was not submitted.
- AltStore PAL still serves approved 3.2.2. Publish 4.0.0 only after Apple approval and validation of the corresponding alternative distribution package. Do not replace the ADP with the App Store IPA.
- The dedicated Duo simulator and its generated build cache were removed after capture. Real device state, diagnostic archives, submitted IPA and release evidence were retained.

## Store artwork and mobile-only notes — October 25 follow-up

- Added Japanese/English product-page headers (3840×1646) and search artwork
  (3840×2560), matching the dark green store screenshot treatment. Search uses
  the complete, unmodified Analytics capture with sample records. Source captures
  and the native generator are committed; see [the artwork guide](STORE_CREATIVE_ASSETS.md).
- Measured safe areas from Apple's official templates. Previewed both surfaces
  with iPhone, the open Duo inner display and iPad, checking Japanese/English
  text and cropping. Enlarged the central artwork after the first small-card
  preview. Header/search images are active on both locales of the editable draft.
- [Creative upload 40104903789](https://github.com/MochiLog/MochiLog/actions/runs/40104903789)
  registered the final four images. Creative replacement scopes references to the
  exact draft localization and surface, preserving the other DEFAULT_PROFILE
  surface, screenshots and public-version placements. Previous library images
  remain available for recovery if a replacement request fails.
- Removed PC storage management, startup/tray/update behavior and Mac-only fixes
  from the mobile notes, and removed PC-side manual-send wording. Mobile PC
  integration features remain. [Metadata preparation 40105285055](https://github.com/MochiLog/MochiLog/actions/runs/40105285055)
  saved the 28-item Japanese/English notes; [TestFlight notes 40105287963](https://github.com/MochiLog/MochiLog/actions/runs/40105287963)
  and the mobile GitHub release body match. Mac/Windows release bodies retain
  their own platform-specific features.
- [Final verification 40105365195](https://github.com/MochiLog/MochiLog/actions/runs/40105365195)
  passed for VALID build 1060, exact localized metadata, all 40 ordered screenshots
  and all four creative placements matched to committed image hashes. The store
  remains PREPARE_FOR_SUBMISSION; no App Review or external beta review was submitted.
- Browser proof images and API verification inventories remain in the ignored
  `build/release-2026-10-24/` evidence directory. The downloaded 101 MiB Photoshop
  template sources were removed after measuring their safe areas. No simulator or
  application rebuild was needed for this artwork/metadata follow-up.
