# Mac log transfer: device identity and recovery

This document describes the experiment. It does not change record storage or enable automatic imports.

## Separate the identities

- `modelIdentifier` (for example `iPhone18,3`) identifies a model, not one physical device.
- The Mac's paired-device UDID identifies the source of a copied log. Keep it in the Mac's local registry; do not put it in CloudKit records or the transfer payload.
- `physicalDeviceID` is a random UUID assigned to one physical device in MochiLog. New battery records carry this ID. It is independent of the Mac's IP address, the installation, and the model name.
- A Mac installation stores a durable mapping `paired UDID -> physicalDeviceID`, plus the expected model and a user-visible label. Transfer manifests use `physicalDeviceID` and a per-file content hash.

## Pairing and reinstall

The user selects a currently connected device in the Mac app, then scans a short-lived QR code in MochiLog on that device. The app sends its pairing request to the Mac. The Mac checks that the selected UDID is still connected and binds its `physicalDeviceID` to the app. If the Mac already knows that UDID, it reuses the same `physicalDeviceID` after an iPhone app reinstall. A new UUID is created only for a genuinely new device or after an explicit user decision to replace an unrecoverable mapping.

The iPhone stores the received `physicalDeviceID` in its local device registry and on each new record. A Keychain copy may help recover it, but must not be the only recovery path: Keychain survival across app deletion is not a documented guarantee. `identifierForVendor` is not a substitute because it may change after all vendor apps are removed. When iCloud sync is enabled, records with the ID are synced as normal record data. When sync is disabled (including iOS 16, which does not support MochiLog's record sync), the ID and records remain local only; no cloud account is required for pairing.

## UUID continuity is separate from record recovery

The UUID answers **which device** a record belongs to. It does not back up the record. If the iPhone app is deleted while record sync is off, loss of local record history is expected. Re-pairing with the same Mac restores the identity mapping, not those deleted records. A record-backup feature is not required for this experiment.

If iCloud was enabled, then disabled, and the app is reinstalled, the cloud can later provide only the records previously uploaded. Re-pair to the Mac's existing `physicalDeviceID` before importing queued logs. If cloud sync is enabled again, records bearing that ID join the same device history. Never infer that a same-model cloud record is from the paired device without evidence.

If both the app's local state and the Mac registry are gone while cloud sync was disabled, the previous UUID cannot be recovered automatically. A new UUID is acceptable when no old records remain. If older cloud records are later restored, present a deliberate choice to link this device to that existing identity or keep it separate; do not silently merge same-model histories.

## Existing records

Existing records have no `physicalDeviceID`. Add an optional field first and leave legacy records unassigned. Offer user-assisted linking when there is ambiguity, especially when two physical devices share a model. New imports must compare individual device IDs rather than use the current date-and-model-name duplicate check. If the importer encounters an ambiguous legacy record for the same day, hold it for review instead of deleting or overwriting either record.

## Validation cases

1. Two same-model iPhones paired with the Mac and imported on the same date remain distinct.
2. iPhone app reinstall with sync off (or on iOS 16), Mac registry present: same ID is reclaimed; deleted local records are not promised to return.
3. iPhone app reinstall after sync was switched off: cloud retains only the earlier prefix. Re-pairing claims its previous ID so that any later cloud import attaches to the same device.
4. Mac IP changes and Bonjour is unavailable: QR/manual endpoint recovery does not change either device ID.
5. Mac registry loss, iPhone local data loss, and sync off: the app asks for a manual choice and does not claim recovery.
