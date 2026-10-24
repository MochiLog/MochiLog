# 4.0.0 (1061): multi-file import and Series 3 references

## Multi-file sharing

The batch importer is an **Action extension** (`com.apple.ui-services`). In the
system share sheet, select **MochiLog（複数ファイル）** from the lower actions area.
The ordinary MochiLog app icon in the upper row is the document-opening route;
it is not the dedicated batch importer. The action's current maximum is 100 files.

The activation dictionary used the unsupported key
`NSExtensionActivationRuleVersion`. It now uses Apple's documented
`NSExtensionActivationDictionaryVersion = 2`, preserving action placement and
the existing file limit. This corrects the provider-matching configuration;
it does not establish that the typo caused the reviewer's particular symptom.
The in-app guide now explains the correct action, Done, and reopening MochiLog
in all eight languages.

Verified on an isolated iPhone Duo / iOS 27.1 simulator, using a separate UIKit
host and the actual extension/app. Eight synthetic files, with repeated
basenames and `.ips`, `.ips.ca.synced`, `.log`, `.txt` extensions, were shared
through the OS sheet. The extension reported **8 of 8 received**. After Done
and opening MochiLog, the app reported **8 saved, 0 duplicates, 0 manual
selections, 0 errors**. Real user records were not used.

Unsigned simulator builds do not have an App Group container. For a faithful
test, build with simulator code signing enabled (`CODE_SIGNING_ALLOWED=YES`,
`CODE_SIGN_IDENTITY=-`); a post-build ad-hoc signature alone does not insert the
simulator's embedded entitlements. Do not mistake that test setup failure for
a shipping App Group failure.

The small, readable host is `Tests/ShareMenuProbe/Host.swift`; build it with
`bash scripts/build-share-menu-probe.sh`. It is not a shipping application target.

## Apple Watch Series 3

| Identifier | Bundled name | Reference capacity |
| --- | --- | ---: |
| Watch3,1 | Apple Watch 3 (38mm) Cellular | 279 mAh |
| Watch3,2 | Apple Watch 3 (42mm) Cellular | 352 mAh |
| Watch3,3 | Apple Watch 3 (38mm) | 262 mAh |
| Watch3,4 | Apple Watch 3 (42mm) | 342 mAh |

The old identifier mapping was also incorrect. The 42 mm Cellular reference was
279 mAh; the 38 mm Cellular reference was 262 mAh. The new 352 mAh value is
documented for the A1850 cell in
[iFixit's replacement-part catalog](https://www.ifixit.com/products/apple-watch-42-mm-series-3-cellular-replacement-battery).
See also the [Series 3 battery catalog](https://www.ifixit.com/Parts/Apple_Watch_Series_3/Batteries)
and [DeviceKit's identifier mapping](https://github.com/devicekit/DeviceKit/blob/master/Source/Device.generated.swift).

## Migration boundaries

All migration implementations live under `MochiLog/Migrations/`. The existing
Core Data and SwiftData runners have been relocated there; the storage classes
only call them. `Migration_v3_WatchSeries3Capacity.swift` owns the shared
correction rule and the two native persistence implementations.

Only exact old references for the two canonical Cellular names are corrected.
Explicitly edited device profiles, other saved capacities and GPS variants are
left unchanged. Automatic diagnosis is recalculated from the unchanged measured
capacity. Record IDs, physical device IDs, dates, names, model codes, cycle
counts and measured capacities are not rewritten. In particular, legacy model
codes are not guessed from the corrected mapping: old manual selection may
already have stored the wrong code.

Initial completion uses the existing per-storage migration flags. The same
idempotent migration also checks fetched records, so imports and records arriving
later from iCloud are repaired after the initial completion flag. Failed saves
roll back and do not mark migration complete. The iOS app on Mac does not mutate
records through this migration. No database or CloudKit schema change is needed.

## Regression verification

- `bash scripts/test-device-library.sh`: all four variants, exact old values,
  idempotency, unrelated values and explicit profile overrides.
- `python3 scripts/check-share-extension.py`: action registration, correct
  activation dictionary key and the 100-file bound.
- `bash scripts/test-shared-log-inbox.sh`: eight files, colliding names,
  atomic publication, interrupted import recovery and original-file preservation.
- `bash scripts/test-batch-log-parser.sh`: multiple valid inputs, nonbattery
  logs and malformed input.
- `bash scripts/test-record-migrations.sh SIMULATOR_UDID`: actual Core Data and
  SwiftData in-memory persistence, repeated migration, later arrivals, unchanged
  identities/measurements and a real Core Data validation failure with rollback.
  Three native tests passed on iOS 27.1. This exercises the iOS 16 storage code
  path on that runtime; it is not an iOS 16 device test.
- `python3 scripts/audit-localizations.py`: 1,456 strings / 15 catalogs / eight
  languages, including placeholder compatibility and 960 literal lookups.
- Existing cloud-sharing and source-identity tests also passed.

## Store handling

At the user's request, the 4.0.0 review submission was withdrawn. The API
confirmed `DEVELOPER_REJECTED`; the previously selected build was 1060.
Withdrawal run: [40114300082](https://github.com/MochiLog/MochiLog/actions/runs/40114300082).
The fix is built as 4.0.0 (1061). Existing store artwork, including inner and
outer iPhone Duo screenshots, must be preserved. Japanese/English public notes
retain the complete 4.0.0 feature list and add the two user-visible fixes.
The user presses the review-submission button after the replacement is verified.
