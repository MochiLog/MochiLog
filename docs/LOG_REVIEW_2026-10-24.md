# Runtime review — 2026-10-24

Reviewed the native Mac/Windows snapshots, their October 24 activity archives, and cached iPhone/iPad diagnostic histories without reaggregating runtime objects in PowerShell. Raw data and device identifiers remain in ignored Build directories.

- Both host daily files were saved by Mac shortly after 09:00 JST. iPhone/Watch transfer and duplicate preflight ran when the iPhone connected later. Windows also stored the iPad daily file when its authenticated endpoint became available.
- AFC permission-denied/remote-pairing timeouts recovered on later attempts. A stored current-day file and a partially completed historical listing are separate states; retained unclassified historical candidates do not invalidate the verified current-day file. No longer cooldown was added.
- Repeated authenticated diagnostic chunks generated misleading skipped-offset warnings during file-offer/ACK exchanges. Receivers now compare at most 8 KiB of existing overlap, accept identical retries without further writes, append only a verified missing suffix, and reject conflicts/gaps. The transfer envelope, nonce replay protection, pairing keys and queue ACK rules are unchanged.
- Regression checks cover exact retries, partial overlap, conflicting data, gaps, negative offsets and per-chunk/day size bounds. Existing archive exchange, encryption and multi-device tests remain required.
- At inspection Mac used approximately 48 MiB resident with no active helper; Windows used approximately 244 MiB private committed memory. Cumulative allocated bytes are not retained memory. A snapshot does not prove indefinite absence of leaks.

Formal release targets: mobile 4.0.0 (1060), Mac 1.0.0 (38), Windows 1.0.0. App Store approval and PAL's notarized package are external steps and must be reported by their actual states.
