# Diagnostic viewer changes (1053)

Error metadata and raw archives load off the main actor. Day catalogs and detail pages are stored snapshots; SwiftUI body evaluation performs no archive reads or per-line view construction. Rendered pages retain at most 120 newline delimiters and 48 KiB of UTF-8 text. Copy/export retains the full selected text. Cancellation prevents an older selection from overwriting a newer one. Date grouping uses the current timezone; transmitted log timestamps and archive formats remain unchanged.

The Settings error-log view shares its parent navigation stack. Home presents the same view inside one NavigationStack. iPad widths of at least 700 points show a list and detail panel. The activity-log hub keeps its existing Settings navigation, and refreshing it only reloads stored files.

Verification: Foundation tests cover 108,672 lines, long Unicode combining sequences, exact reassembly, safe date listings, format versions, feature filters, timezone grouping and search. CI runs the same tests before signing. The diagnostic UI workflow also checks a large error fixture in all eight languages on iPhone and iPad, without adding simulators to the resource-constrained development Mac.

Desktop: Mac 0.2.26 and Windows 0.1.24 apply async viewer loading and avoid repeated filesystem reads during status updates. Mac app and DMG are signed and notarized. Windows state.bin was unchanged by the installed update. Native computer-use transport was unavailable during this session; desktop button-click verification is not claimed.

The first CI pass validated iPhone error screens in all eight languages, both devices’ activity-log navigation and native battery-tab changes. Its only failure was the iPad test locating the custom error-log Settings card by an identifier present only on the compact navigation list. The card was visible and reachable in the recorded accessibility tree. The test now uses the card’s translated title on iPad and explicitly selects its fixture. Only that failed case is rerun; signed production code is unchanged.

The targeted retry exposed a second issue: the iPad error-log card’s plain button only hit-tested its rendered text and icons; tapping the card’s center whitespace did not navigate. The sibling activity-log card has longer text covering its center, which explains why its tests passed. Build 1054 adds a rectangular content shape and the shared accessibility identifier to the whole label. Paging moves before the long text, with first/last page shortcuts. UI verification explicitly taps the card center and the last-page button.

Final verification (2026-10-11): the page controls were visibly present in the 1054 recording, but SwiftUI's row identifier masked the child button identifier used by the test. The test now finds the localized spoken label and asserts that the shorter final page actually replaces the first page. This retry changed only UITests and the targeted test script; the signed app source remains `74de817d1042124c58394cb4652bad706aca2bf4`.

- UI run `38110688108`, test source `42f4900a4cd6fdde480a60ebf876a182eee48678`: passed on both iPad and iPhone, with eight language screenshots per device. Japanese screenshots were inspected: the iPad keeps its settings sidebar and list/detail columns; both devices show page 906/906 after the last-page action. Each rendered text is bounded, retains Unicode and has one navigation bar.
- Signed upload `38109331828`: successful; the IPA's app, share extension and Watch bundle are all 4.0.0 (1054). Its compiled MacTransfer strings contain the new page labels in all eight languages.
- TestFlight publication `38113076612`: build VALID, Japanese/English notes saved, both existing internal groups linked and the existing external `main` group in `IN_BETA_TESTING`.
- GitHub prerelease: `v4.0.0-beta.1054`. Mac 0.2.26, Windows 0.1.24 and the website guide are also published.
- Both real mobile devices report build 1054. iPad launch succeeded; iPhone installation succeeded but launch confirmation was unavailable while it was locked. No simulator runtime was downloaded to the development Mac. Existing records, pairing credentials and transfer formats were not modified by this viewer update.

The error-only CI retry skips unrelated, previously passed native protocol probes. Default and broader UI scopes continue to run those probes. iOS 17 UI verification was explicitly skipped because that runtime was not installed on the runner.
