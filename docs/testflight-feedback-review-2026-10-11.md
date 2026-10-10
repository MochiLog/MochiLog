# TestFlight feedback review — 2026-10-11

Reviewed all 2 screenshot submissions and 11 crash submissions via App Store Connect; obtained the 4 crash logs available from the official API. Original feedback/stack traces remain in ignored Build directories. Tester names, emails and raw device identifiers are not included here.

| Report | Build | Evidence and current disposition |
| --- | --- | --- |
| 2026-01-15, iPad Air M2: detail scrolling stutters | 1.1.2 (40) | Current record detail uses lazy layout and rendering preferences. No current reproduction or frame-timing comparison on the reporting device; unresolved performance report, not claimed fixed. |
| 2025-12-28, iPhone: one record disappears when changing chart range | 1.0 (20) | Current health/cycle charts explicitly draw PointMark for individual records; date-window and sparse-data regressions passed in Tokyo and Los Angeles. Code covers the reported condition; exact tester visual reproduction is not claimed. |
| 2026-10-07 and 2026-10-06, three available Mac crash traces | 4.0.0 (1028) | All crash at address zero in DonationManager.checkDistribution(). Matches weak-linked MarketplaceKit on iOS-app-on-Mac. Commit 89c5c8d already bypasses AppDistributor.current on isiOSAppOnMac. These are historical reports predating that fix. |
| 2026-09-21, iPad sharing crash | 3.2.0 (1013) | Charts categorical foreground scale nil unwrap. Matches the chart domain/localized device and sharing renderer fixes already carried in 3.2.2 and beta (df3c04f / 972ebaa and their backports). No need to reapply an identical change. |
| Remaining 7 crash submissions | 1028, 1029, 56, 48, 20 | Crash log API returns 404. Comments include selecting iPhone among Watch/iPhone and entering Analytics; without traces these cannot be conclusively assigned to a fix. Do not mark all feedback resolved just because its build is old. |

No feedback was deleted or replied to. There are no submitted crash reports newer than 1029 in the reviewed list; this is not proof that newer builds are crash-free.

API reference: https://developer.apple.com/documentation/appstoreconnectapi/beta-feedback-crash-submissions
