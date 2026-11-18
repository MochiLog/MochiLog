# Import regression checks

`bash scripts/test-shared-import.sh` compiles the production queue, text reader and date parser on macOS, with a minimal settings/UI-model stub. It checks cold-launch buffering, exclusive consumption, arrival during processing, duplicate delivery, retries, presentation preferences, UTF-8/UTF-16/Shift-JIS decoding, missing inputs and old/new timestamp formats.

`Fixtures/` contains synthetic analytics data, not exported user logs. The valid fixture has a timestamp without fractional seconds, exercising the regression where these timestamps were previously rejected.

Build the app and embedded Watch app using a destination, without overriding the SDK for every target:

```sh
xcodebuild -project MochiLog.xcodeproj -scheme MochiLog -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

On an isolated simulator with iCloud disabled, import the valid fixture with three different dates, a fourth copy with the first date, and the invalid fixture. Expect 3 saved, 1 duplicate, and 1 error. Repeat on a compact phone, iPad mini, a large iPad and with accessibility text sizes. Relaunch and verify the saved records persist. Test both a terminated app and an already running app.

The containing app uses `UISceneDelegate` for both `connectionOptions.urlContexts` and `scene(_:openURLContexts:)`. No share extension is involved. Simulator `openurl` exercises delivery to the main app; a physical-device check from Files and Settings Analytics is still needed to verify each source app's multi-selection behavior.

## Launch after upgrading from the SwiftUI app lifecycle

Keep `MochiLog Main Scene` and its UIKit delegate declared in `Info.plist`, with the same configuration name returned by the app delegate. The manifest alone is insufficient: on 2026-11-18, an in-place upgrade reproduced restoration of an older `SwiftUI.AppSceneDelegate` even with this manifest. A UIKit-only entry point then traps when that scene saves its restoration state.

To check this migration, launch a version using the former SwiftUI `App` lifecycle, then install the current app over it without uninstalling or clearing its data. Verify the home screen and existing records load, then terminate and relaunch. Also background and foreground the app and check that URL imports still reach the queue. A clean install alone does not exercise the saved-session migration.

Historical check (2026-09-08): on a connected iPhone 17, the failing session archive referenced `SwiftUI.AppSceneDelegate`; after installing the named UIKit configuration, that session referenced `MochiLog Main Scene`. Launching through Xcode reached `HomeView.onAppear` and loaded 158 existing records. This single-device result did not cover every saved-session upgrade path.

The 2026-11-18 fix keeps a SwiftUI `App` entry point and adapts the existing UIKit delegates. `SceneWindowHost` creates a window only for directly restored UIKit sessions; SwiftUI owns its own windows. SwiftUI URL callbacks and UIKit URL contexts both feed the existing import queue. No session archive, preference suite, record store or pairing is deleted.

Run `python3 scripts/test-scene-lifecycle.py`. It compiles the production entry point/window host with synthetic delegates and creates disposable iPhone/iPad simulators. It checks legacy SwiftUI updates, UIKit updates, fresh installs, a negative control that actually crashes in `AppSceneDelegate.stateRestorationActivity`, and recovery of that crashed installation without uninstalling. Each passing case checks one window, unchanged record bytes/preferences, foreground/background/relaunch cycles, and warm/cold URLs sent by another installed app. The sender uses `UIApplication.open`; some simulator versions silently refuse `simctl openurl` with a LaunchServices scheme-approval error.

`MochiLogUITests/SceneLifecycleTests/testHomeSurvivesBackgroundAndRelaunch` checks the full app with in-memory records and iCloud disabled. It verifies the home screen through repeated background/foreground transitions and relaunch. It does not replace the synthetic in-place upgrade tests or verification of the next signed distribution on a physical device.

### Real file imports before distribution

`SceneLifecycleTests.testRealFileImportPersistsAfterRelaunch` opens synthetic analytics files through `XCUIApplication.open`, then checks the record detail and counts after terminating and relaunching the real app. It uses a persistent local store with iCloud/automatic collection disabled; it does not use the in-memory home fixture.

Run it only on disposable import simulators. Place two valid fixtures with different dates in that app's App Group container (outside `SharedLogInbox` so they do not auto-import). Configure the UI test runner's `MOCHI_IMPORT_TEST_URLS` environment as JSON mapping each simulator UDID to the two absolute file paths. The test uses `SIMULATOR_UDID` to select its inputs. Without this explicit fixture map it skips. `simctl get_app_container DEVICE net.ryuya-dev.MochiLog groups` provides the group container path. Do not point this test at a person's existing records.

## Chart and overview regression checks

Run `bash scripts/test-charts.sh` for the production date/window and downsampling helpers. The fixtures cover inclusive 7/14-day windows, leap years and DST, old-only datasets, unordered context neighbors, sparse previous/next navigation, 2-year navigation round trips, automatic windows across month boundaries, preserving extrema/latest points, and edits that keep the same record ID and date. The script runs in Asia/Tokyo and America/Los_Angeles.

`LanguageAndLayoutTests.testRefreshedOverviewScreens` and `testRefreshedOverviewAtAccessibilitySize` capture Home, Analytics and Settings at normal and largest accessibility text sizes. Use the import-fixture simulators described above; on an empty installation the test opens sample data. iCloud is disabled by launch arguments for these UI checks.

## Performance regression checks

`bash scripts/test-log-dates.sh` measures 3,000 mixed timestamp parses and verifies fractional seconds, time zones, legacy formats, invalid input and concurrent callers. A local optimized macOS run measured 1.540 s before formatter reuse and 0.697 s after; this is a date-parser microbenchmark, not end-to-end import timing or device FPS.

Home/summary/statistics group records once per view input instead of filtering the full array for every row/card. Statistics find the latest record in linear time. Detail views generate share images only when requested. Store cache inputs must already be descending by log date, as supplied by both persistent stores' fetch descriptors.

## Editable device library

`bash scripts/test-device-profiles.sh` uses the production profile catalog and store with an isolated UserDefaults suite. It verifies persistence, retention of original standard/custom values, restoring values, duplicate/name/board validation and conflicts after standard definitions change. It simulates a manually added model later appearing in standard data and tests adopting the standard values without losing the initial manual values.

`LanguageAndLayoutTests.testDeviceProfileEditAndRestore` runs against synthetic simulator records with iCloud disabled. It changes iPhone 15 Pro design capacity, saves, applies it to existing records, restores the original profile and reapplies it. Real-device installation does not apply edits to user records.

Profile overrides are local to each installation. Standard dictionaries remain immutable. Existing-log updates modify only model name and design capacity in one persistent-store save; errors roll back. Model identifiers, IDs, measured values and dates are preserved. The editor shows the matching count and saved values before applying; restoring profile defaults is separate from updating logs. Matching historical names/identifiers are retained across edits.

### Reduced rendering and device sections

`testReducedEffectsOverview` launches with `-renderingMode reduced` and checks Home, Analytics and Settings. `testDeviceCategoriesAndGeneralSettings` checks the five device categories and cross-category search on iPhone/iPad.

Rendering Quality has Automatic, Reduced Effects and Standard modes. Reduced Effects omits custom shadows, makes loading surfaces opaque, avoids forced chart drawing groups and stops the decorative import pulse. It does not reduce stored log precision or chart input data. Automatic uses Low Power Mode, serious/critical thermal state or <=4 GiB physical memory as a conservative budget heuristic; this is not a GPU benchmark. On-device FPS/GPU-time measurements are still needed to quantify gains on older hardware.

### Independent iPad chart ranges and Auto

`testChartRangeIndependence` changes the health and cycle ranges independently on iPad and verifies retention after rotation; on iPhone it verifies the single shared control. Real iPad cycle settings use a separate `cycleChartRange` preference, while sample settings stay temporary. Statistics continue to use the health chart period.

`test-charts.sh` also covers Auto following new records, device-filtered historical records, future dates, empty input, ranges longer than three years, calendar boundaries and time-of-day/DST boundaries in Tokyo and Los Angeles. Auto ends at the latest nonfuture log and includes the earliest eligible log; saved manual presets remain manual.

### Record explanation defaults

`bash scripts/test-record-info.sh` checks fresh installs, migration from older settings, version/build updates and preserving a user's ON setting within the same release. `testRecordInfoSettingPersists` simulates an older release marker, verifies OFF on launch, then verifies that enabling the toggle survives a normal relaunch. The independent marker is `recordInfoDefaultsRelease` so other version migrations cannot consume this reset.

### Multiple logs from Settings sharing

The document Open In route on the tested iOS 27 iPhone delivered one URL after selecting roughly eight logs. An on-device receipt diagnostic confirmed this. `MochiLogShareExtension` receives every attachment from every `NSExtensionItem`, copies provider files before their callback returns and publishes the completed batch into the app group. Choose **Import to MochiLog**, tap Done and open the app to process the batch. The extension does not use unsupported app-opening APIs.

`bash scripts/test-shared-log-inbox.sh` verifies eight same-named files, no partial visibility, restart recovery, acknowledgment, failure retention and preservation of provider originals. `bash scripts/test-batch-log-parser.sh` verifies seven synthetic valid logs plus one log without battery measurements and differentiates malformed battery JSON. Real imported logs are not checked into the repository.

The on-device failed log contained no battery capacity/cycle fields. Its UI error now says so explicitly. Debug receipts record filename/count only. Failed extension copies stay in `SharedLogInbox/Review` in the app group; normal source files are untouched.
