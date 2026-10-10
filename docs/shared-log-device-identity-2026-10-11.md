# Shared log source identity repair (2026-10-11)

## Confirmed defect

An October 10 iPhone battery log appeared as an iPad record on the receiving iPad. The raw Analytics log contained no hardwareModel. Cloud sharing correctly retained the originating physical-device UUID, but HomeView resolved missing hardware information to the receiving device. That also selected the wrong design capacity. OS text iPhoneOS cannot distinguish an iPhone from an iPad.

## Correction

- A v3 authenticated, encrypted preflight offer includes the originating paired device model, selected by the source UUID, not by the recipient.
- Updated recipients advertise logSourceIdentityVersion=1. Mac and Windows share foreign logs only with recipients that support that identity metadata. Own-device transfers remain compatible with older clients and retain existing pairings.
- The mobile app caches authenticated source model mappings within the current iCloud sharing scope. An unknown or contradictory source requires explicit device selection, never receiver-model inference. Apple Watch logs retain their existing distinct origin and selection route.
- Existing content-derived UUIDv5 records with a verified originating device are corrected in place. Their record ID, physical-device ID, dates, measured capacities and charge cycles are preserved. No delete/reinsert or model majority inference is used.
- Repair events are logged only after a successful durable save. The iOS app running on Mac remains free of repair writes.

## Validation

- Mobile source resolution tests: both cross-device directions, unknown foreign source, metadata contradiction, ordinary direct imports, idempotent repair and exclusion of UUIDv4/manual/Watch records: PASS.
- Mac protocol suite: encrypted preflight metadata, older recipient capability gating, four peers, scopes, revocation and existing transfer/replay tests: PASS.
- Windows protocol suite executed on Windows 11, including DPAPI persistence and the same source metadata/capability cases: PASS.
- Eight-language audit: 1,428 strings, 15 catalogs, 932 literal lookups: PASS.
- Debug 4.0.0 (1052) build/install: iPhone and iPad PASS. iPhone launch and read-only database comparison confirmed the affected record now says iPhone 17 / iPhone18,3, with design capacity 3,692 mAh. Its record/origin IDs, 135 charge cycles, 3,689 nominal and 3,726 raw capacity remained unchanged.
- iPad update was installed, but its subsequent launch and read-only database fetch were blocked by its lock state. Do not treat the remaining iPad check as passed.

Private device databases and original Analytics files stay in ignored Build directories and are not committed.
