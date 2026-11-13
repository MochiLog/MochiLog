# PC timeout audit and ZIP support exports (2026-11-13)

## Evidence boundary

The supplied report names error -1001, but does not establish its error domain or the exact screen/stage. In Foundation, NSURLErrorDomain/-1001 is URLError.timedOut. A number alone does not prove a network permission or firewall problem.

All supplied November 12/13 events were examined; the email submission time was not treated as the failure time. The diagnostic JSON says app pairing is not complete and there are no confirmed/unconfirmed files or pending acknowledgement. The daily logs contain connection-stop events, but no PC QR handshake, PC connection start/request-send, or -1001. The on-device OS pairing attempt in the same logs is a separate flow. Missing historical handshake events cannot be reconstructed.

The release/4.0.1 source branch was also checked: it contains the same 10-second QR exchange and 6/20-second transfer-connect guards. DeviceCatalogUpdater is absent there; its HTTPS timeout belongs to current 4.1.0 development and cannot explain this 4.0.1 report.

Consequently, the reporter's original cause is still unconfirmed. No reporter settings, firewall, VPN, pairing or records were changed. No support mail was sent.

## Where -1001 can originate

| Path | Deadline / behavior | Evidence |
| --- | --- | --- |
| QR challenge and confirmation | App-created URLError.timedOut after 10 seconds **per route**, covering connection, send and waiting for a newline-delimited response | Source + actual local TCP tests |
| PC file transfer while connecting | App-created timeout after 6 seconds for direct routes or 20 seconds for the Bonjour endpoint; the guard stops applying once TCP is ready | Source |
| Ready PC transfer with no first byte / stalled body | Previously no client idle deadline; could wait without producing -1001. Now a separate 25-second progress deadline logs the phase and advances the route | Source + actual deadline runtime tests |
| Pairing revocation retry | Uses PairingTransport, so may time out; failure is retained for retry rather than shown as a fresh QR error | Source |
| Device catalog HTTPS update (4.1.0 development only) | URLSession request timeout 15 seconds, resource timeout 30 seconds; independent of PC pairing and absent from the reported 4.0.1 source branch | Source |
| Current battery / reuse of OS pairing from PC | LiveBatteryTransport uses 30/8/5-second deadlines depending on caller and reports its own Failure.unavailable, rather than creating URLError(-1001) | Source |
| On-device diagnostics | Native library has its own timeout/error handling; it is distinct from the PC QR exchange | Source |

After trying several routes, the visible error can reflect only the last route's failure. Earlier failures need the per-route diagnostic events; the final -1001 alone cannot identify them.

## Conditions that can lead to the QR deadline

| Condition | Distinction / verification |
| --- | --- |
| No TCP connection: stale IP, network separation, Mac sleeping/offline, silent firewall drop, unusable VPN route | The ten-second deadline can expire in connecting/preparing/waiting. These network conditions are possible causes, not individually reproduced on the reporter's machine |
| iPhone Local Network access denied or permission alert unresolved | Apple documents NWConnection waiting and a localNetworkDenied path reason. The app's own deadline can then mask the underlying wait as -1001. Simulator/Terminal tests do not validate a real iPhone's permission state |
| Mac firewall blocks incoming traffic | Separate from Local Network privacy. Not tested by changing the user's firewall |
| TCP accepts, but the peer sends nothing | Reproduced: -1001, waiting-for-response, zero bytes |
| Peer sends bytes but never finishes the newline frame | Reproduced: -1001, waiting-for-response, nonzero receivedBytes |
| Complete valid response arrives while TCP stays open | Previously reproduced false timeout from waiting for EOF; fixed in the preceding patch and tested again |
| Server work is delayed after connect | Serial server processing and synchronous credential/disk persistence are potential delay points. A silent/delayed responder reproduces the client symptom, but no Keychain prompt or storage delay was reproduced on the reporter's Mac |
| App goes to the background during the handshake | A suspended task may resume after a deadline/session has expired. Scene changes during pairing are now recorded; this was not reproduced on the reporter's phone |
| Listener failed while UI could still create QR | Found in source. Mac now withholds QR unless its listener is ready and advertises the actual bound port; offline-listener regression test passes |

Apple's Local Network rules are directional: outgoing TCP from iPhone requires access, and Bonjour publication/browsing/resolution require access. Merely listening for/accepting TCP on Mac does **not** itself require that privilege. Do not conflate a denied Bonjour operation with a proven blocked inbound TCP listener.

PIN mismatch, expired/replaced QR session, wrong model/identity, malformed or oversized frames and authentication-proof failure are separate rejection paths. With a responsive server they normally close/reject the exchange or fail validation, rather than intrinsically creating -1001. Delay or packet loss can coexist with them, so a failure number alone remains insufficient.

## Additional fixes from the investigation

- QR challenge tries the next route after an unrelated endpoint closes. Confirmation retains the existing fail-on-empty-response behavior, avoiding repeatedly submitting a wrong PIN to the same computer through different interfaces.
- Framed replies must match the expected type, session and authentication proof before a route wins. A non-MochiLog/incorrect peer no longer prevents a later valid route from being tried.
- Add an exact-host Bonjour fallback after direct QR address hints. The public key/session proof still pins the host; no authentication check is removed. This recovers changed addresses and can use IPv6 without an IPv4 hint.
- Retain the validated route and try it first during confirmation instead of repeating every failed address.
- Mac QR address priority matches its Wi-Fi-aware service advertisement; Windows also prioritizes Wireless80211 before taking its limited address hints.
- Record controlled route kind, rejected frames, active/inactive/background scene changes, listener readiness and bounded server response-write errors. Payloads, PINs, private keys and proofs stay out of logs.
- A separate progress deadline covers ready file transfers. Any arriving bytes extend it, so a slow transfer can exceed 25 seconds in total. Stop/route failure/completion cancel the deadline.

## ZIP support export

Email attachments are now **one** mochilog-support.zip, containing the bounded prepared snapshots and the existing manifest. The files retain their category/date/version names. Missing/empty/limited sources are still explicit in the manifest. Nothing scans a live directory into the ZIP.

Swift uses pinned ZIPFoundation 0.9.20, already used on mobile and now bundled/licensed on Mac. Windows uses System.IO.Compression. The archive input is limited to 100 files / 16 MiB (the snapshot export remains 96 files / 12 MiB plus manifest), with 64 KiB buffers, flat safe entry names, symbolic-file rejection and partial-output cleanup. Creation runs off the UI thread. Windows' existing mailto fallback opens the saved ZIP for manual attachment when the mail composition API is unavailable.

A Foundation forUploading prototype was rejected during testing: it produced leading-slash ZIP entries in the system temporary directory. Production uses the pinned ZIP library with explicit flat names instead.

## Verification and remaining checks

- `bash scripts/test-pairing-support.sh`: real local TCP silence/partial-frame timeouts, complete frame before EOF, validated route fallback, challenge EOF fallback, retained winning route, exact-host Bonjour without IPv4 hints, truncation/oversize/cancellation/secret exclusion; idle deadline survives slow progress, expires once after a stall and cancels cleanly.
- `bash scripts/test-support-archive.sh`: ZIP construction, byte limits, symbolic inputs, cleanup; Python zipfile independently opens the ZIP, validates CRC, compares all UTF-8 entry bytes and confirms unrelated files were excluded. Both cached and fresh dependency-fetch paths were run.
- Mac protocol suite includes ready-listener QR gating, actual-port advertisement, authentication/replay/archive compatibility and one-ZIP support before pairing.
- Full mobile simulator/Watch, Mac Release and physical-host Windows Release builds and Windows support/protocol tests pass. Tests generate synthetic data; no production pairing or battery record is changed.
- Real reporter-specific iPhone permission, Mac firewall/VPN topology, Mac server version/status and a repeat of the failing operation remain unverified. The simulator does not implement Local Network privacy. Updated paired logs from both sides are needed to attribute this particular incident.

## Primary references

- [Apple: Local Network privacy (TN3179)](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
- [Apple: Firewall connections](https://support.apple.com/en-euro/guide/mac-help/mh34041/27/mac/27)
- [Apple: URLError.timedOut](https://developer.apple.com/documentation/foundation/urlerror/code/timedout)
- [Tailscale: overlapping LAN subnet routes](https://tailscale.com/docs/reference/troubleshooting/network-configuration/lan-traffic-overlapping-subnets)
