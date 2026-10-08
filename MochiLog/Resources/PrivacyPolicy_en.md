# MochiLog Privacy Policy

## 1. Data processed

MochiLog processes iPhone, iPad, and Apple Watch analytics logs selected by the user on the device. It stores battery records, model, date, capacity, product region, and identifiers used to distinguish physical devices. Original analytics logs may contain other device and usage information. Settings and records are generally stored on the user’s device. Analytics logs and records are not automatically sent to the developer.

## 2. Optional sync and transfer

If iCloud sync is enabled, records are synchronized through the user’s private iCloud database between devices using the same Apple Account. Records may be sent to the paired Apple Watch app. Exports, file sharing, and imports use data selected by the user. In the Mac transfer beta for iOS/iPadOS 27 and macOS 27, a paired Mac collects and temporarily stores analytics logs while the mobile device is unlocked, then sends them in encrypted form to MochiLog on the same local network. The Mac and mobile device exchange pairing data, transfer status, and diagnostics. Mac transfer does not send logs to a developer server. The Mac app contacts GitHub to check for updates; GitHub may receive network information such as the IP address. The Windows 11 companion alpha also sends logs from a paired PC to MochiLog using encrypted transfer.

If Live Battery is enabled, a paired computer reads current cycle count and capacity fields from the device diagnostics service and sends them encrypted to the mobile app. These current values are held only in memory and are not stored as history, battery records, iCloud data or support diagnostic logs. The setting is off by default. This is separate from collection and retention of daily Analytics files. If communication uses a VPN such as Tailscale configured by the user, that service’s terms and data handling also apply.

## 3. Support requests

If the user sends a support email, the developer receives the nickname, email address, message, and attachments supplied. Mac transfer support attaches OS and app versions, model, transfer status, device identifiers, errors, and recent diagnostic events from the mobile device and Mac when the user sends the email. Events may include filenames or file paths. Review the email before sending it. The user’s and developer’s email providers process the message. Support information is retained as needed to handle the request and keep necessary records; deletion requests are honored except where retention is required by law.

## 4. Storage and deletion

Records on the mobile device can be deleted with the app’s deletion controls. Turning off iCloud sync does not automatically delete records already stored in iCloud or on another device. Pending logs and pairing information on the Mac are stored in Application Support and may remain after deleting only the app. Contact support for help deleting Mac data. Reinstallation, OS backups, and iCloud settings affect what remains or can be restored. By default, the Mac and Windows companions delete a raw log after the mobile app acknowledges it. If retention is enabled, acknowledged logs are kept up to 500 MB and one month by default (both adjustable), and can be exported, manually resent, or deleted. Pending unacknowledged logs are excluded from automatic cleanup and manual deletion.

## 5. External services and changes

MochiLog does not use advertising, tracking SDKs, or third-party usage analytics SDKs. Optional tips in the App Store version use Apple StoreKit. Cloudflare serves the website and may process network information such as IP addresses when the site is visited. If this policy changes, the website and in-app documents will be updated with the revision date.

## 6. Contact

For policy questions or requests to delete support emails, contact support@mochilog.ryuya-dev.net.

Revised: 2026-10-09

The full-field battery view can also handle manufacturing metadata, battery identifiers and status flags in memory. It shows original API names and values without guessing units. These fields are not saved or attached to support logs and use encrypted transfer with the existing pairing.


PC log sharing can deliver another device’s logs encrypted only when both devices are paired with the same computer, have iCloud sync enabled, and the same Apple Account is confirmed. Matching uses a hash derived from an app-scoped CloudKit user ID; the Apple ID, email and original user ID are not sent to the computer. This hash is an account-matching identifier, not a guarantee of anonymity. Consent is held temporarily in computer memory and revoked when sync is disabled or the account changes. If a device cannot communicate, revocation is not immediate and the last consent may remain for up to 15 minutes. Records retain the source device’s identity. Logs are not sent to a developer server.

Optional on-device acquisition authenticates to this device’s diagnostic service through a local VPN/reflector route. OS pairing credentials are held in device-only Keychain and explicitly reused over an encrypted authenticated PC connection or imported by the user. Keys and analytics files are not sent to a developer server. Staged files are removed after successful import. Current readings from another device using the same PC are shared only with confirmed iCloud sync enabled on both devices and the same Apple Account; readings are not saved to history, iCloud or diagnostic logs. PC automatic update checks are off by default and connect to GitHub when enabled. The data practices of your VPN service also apply.

On iOS/iPadOS 27 or later, explicit approval in Settings can create this device’s OS pairing credential in the app without importing a file from a computer. The confirmation code is shown only during pairing in the app, system task UI and authorized notifications; it is not included in diagnostics or support attachments. Cancellation or completion ends notifications and the listener. Credentials remain in device-only Keychain and are not sent to another device or a developer server.
