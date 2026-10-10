# Shared log source identity repair (2026-10-11)

## Confirmed defect

An October 10 iPhone battery log appeared as an iPad record on the receiving iPad. The raw Analytics log contained no hardwareModel. Cloud sharing correctly retained the originating physical-device UUID, but HomeView resolved missing hardware information to the receiving device. That also selected the wrong design capacity. OS text iPhoneOS cannot distinguish an iPhone from an iPad.

## Correction

- A v3 authenticated, encrypted preflight offer includes the originating paired device model, selected by the source UUID, not by the recipient.
- Updated recipients advertise logSourceIdentityVersion=1. Mac and Windows share foreign logs only with recipients that support that identity metadata. Own-device transfers remain compatible with older clients and retain existing pairings.
- The mobile app caches authenticated source model mappings within the current iCloud sharing scope. An unknown or contradictory source requires explicit device selection, never receiver-model inference. Apple Watch logs retain their existing distinct origin and selection route.
- Existing content-derived UUIDv5 records with a verified originating device are corrected in place. Their record ID, physical-device ID, dates, measured capacities and charge cycles are preserved. No delete/reinsert or model majority inference is used.
- A consent-scoped encrypted policy response supplies source model metadata even when every log has already been delivered. This lets existing records be repaired without retransferring their bodies; one validated model batch causes at most one refresh.
- Repair events are logged only after a successful durable save. The iOS app running on Mac remains free of repair writes.

## Validation

- Mobile source resolution tests: both cross-device directions, unknown foreign source, metadata contradiction, ordinary direct imports, idempotent repair and exclusion of UUIDv4/manual/Watch records: PASS.
- Mac protocol suite: encrypted preflight metadata, older recipient capability gating, four peers, scopes, revocation and existing transfer/replay tests: PASS.
- Windows protocol suite executed on Windows 11, including DPAPI persistence and the same source metadata/capability cases: PASS.
- Eight-language audit: 1,428 strings, 15 catalogs, 932 literal lookups: PASS.
- Debug 4.0.0 (1052) build/install: iPhone and iPad PASS. iPhone launch and read-only database comparison confirmed the affected record now says iPhone 17 / iPhone18,3, with design capacity 3,692 mAh. Its record/origin IDs, 135 charge cycles, 3,689 nominal and 3,726 raw capacity remained unchanged.
- iPad updated/launched and read-only database comparison: PASS. The October 10 record is now iPhone 17 / iPhone18,3 with design capacity 3,692 mAh, unchanged record/origin IDs and measured values. Total records remain 122, including the separately identified Watch record. The affected iPad row was also corrected via iCloud from the source device; this is not by itself proof of a two-peer policy repair.
- iPad authenticated policy response was received without any log body (one currently active consented source). Mac/Windows protocol tests separately verify inclusion of already-delivered foreign sources and exclusion of unconsented peers.
- iPhone final update installed, but its last launch was blocked by lock state. Its earlier 1052 database comparison passed; final policy run awaits unlock.

Private device databases and original Analytics files stay in ignored Build directories and are not committed.

## Distribution

- Signed CI build/upload 38074518363: success, app / Watch app / share extension all 4.0.0 (1052), source 7ed7f59.
- GitHub beta source tag v4.0.0-beta.1052 published with Japanese/English notes.
- Mac v0.2.25 and Windows v0.1.23 prereleases published; both real PC installations verified.
- Web guide deployed with Japanese/English compatibility and in-place repair guidance.
- TestFlight notes/distribution job 38075149334: success. Build 1052 is VALID and unexpired; both internal and external states are IN_BETA_TESTING. Japanese/English notes and existing tester groups were confirmed by the release job.
- Final iPad activity logs confirm authenticated identity policy responses from both updated Mac and Windows without requesting a log body.
