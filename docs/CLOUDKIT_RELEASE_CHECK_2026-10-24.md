# CloudKit release check — 2026-10-24

Checked the CloudKit Console for `iCloud.net.ryuya-dev.MochiLog` against main’s `CurrentBatterySchema.BatteryRecord` in `MochiLog/Services/SwiftDataStore.swift`.

- Both Development and Production contain `CD_BatteryRecord` and the standard `Users` type.
- Every one of the 27 stored model properties exists in Production with the expected CloudKit type. This includes `CD_physicalDeviceID`, `CD_recordID`, `CD_productSku` and `CD_manufactureDate`.
- The complete BatteryRecord field and single-field-index listings match between Development and Production: 27 model properties, Core Data’s `CD_entityName`, and six system metadata fields (34 total).
- No schema deployment, reset, record edit or permission change was needed or performed.
- The SwiftData schema remains `1.0.0` and retains the `BatteryRecord` entity name. Newly added optional fields do not require older clients to populate them.

This confirms schema availability for release. It does not claim that every user’s private database contains the same records or that all clients have finished synchronization. Existing sync diagnostics and regression tests check that separately.

Console: [Production BatteryRecord fields](https://icloud.developer.apple.com/dashboard/database/teams/FZ35ZF3CZV/containers/iCloud.net.ryuya-dev.MochiLog/environments/PRODUCTION/types/CD_BatteryRecord/fields). Private local evidence is retained under the ignored release-check build directory; it contains schema metadata only, not user records.
