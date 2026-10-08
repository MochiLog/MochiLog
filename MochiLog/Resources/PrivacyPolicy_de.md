# MochiLog Datenschutzerklärung

## 1. Verarbeitete Daten

MochiLog verarbeitet vom Nutzer ausgewählte Analyselogs von iPhone, iPad und Apple Watch auf dem Gerät. Gespeichert werden Batteriedaten, Modell, Datum, Kapazität, Produktregion und Kennungen zur Unterscheidung einzelner Geräte. Ursprüngliche Logs können weitere Geräte- und Nutzungsdaten enthalten. Einstellungen und Aufzeichnungen bleiben grundsätzlich auf dem Gerät. Sie werden nicht automatisch an den Entwickler gesendet.

## 2. Optionale Synchronisierung und Übertragung

Bei aktivierter iCloud-Synchronisierung werden Aufzeichnungen über die private iCloud-Datenbank des Nutzers zwischen Geräten desselben Apple Accounts synchronisiert. Daten können an die gekoppelte Apple Watch übertragen oder vom Nutzer exportiert bzw. geteilt werden. In der Mac-Übertragungsbeta für iOS/iPadOS 27 und macOS 27 sammelt ein gekoppelter Mac Logs nur bei entsperrtem Mobilgerät, speichert sie vorübergehend und überträgt sie verschlüsselt im lokalen Netzwerk. Mac und Mobilgerät tauschen Kopplungsdaten, Status und Diagnosen aus. Die Logs gehen nicht an einen Entwicklerserver. Bei Updateprüfungen kontaktiert die Mac-App GitHub; dabei können Netzwerkdaten wie die IP-Adresse anfallen. Die Windows-11-Begleitapp (Alpha) überträgt Logs von einem gekoppelten PC ebenfalls verschlüsselt an MochiLog.

Wenn Live-Batterie aktiviert ist, liest ein gekoppelter Computer aktuelle Ladezyklen und Kapazitätswerte aus dem Diagnosedienst des Geräts und überträgt sie verschlüsselt an die mobile App. Diese Werte bleiben nur im Arbeitsspeicher und werden nicht als Verlauf, Batterieeinträge, iCloud-Daten oder Support-Diagnoseprotokolle gespeichert. Die Einstellung ist standardmäßig aus. Dies ist getrennt von der Erfassung und Aufbewahrung täglicher Analytics-Dateien. Bei einem vom Nutzer eingerichteten VPN wie Tailscale gelten auch dessen Bedingungen und Datenverarbeitung.

## 3. Support

Wenn der Nutzer eine Support-E-Mail sendet, erhält der Entwickler Spitzname, E-Mail-Adresse, Nachricht und Anhänge. Der Mac-Transfer-Support fügt beim Senden OS- und App-Version, Modell, Übertragungsstatus, Gerätekennungen, Fehler und jüngste Diagnoseereignisse hinzu. Diese können Dateinamen oder Pfade enthalten. Prüfen Sie die E-Mail vor dem Versand. E-Mail-Anbieter verarbeiten die Nachricht. Supportdaten werden für die Bearbeitung und notwendige Dokumentation aufbewahrt; Löschanfragen werden erfüllt, soweit keine gesetzliche Aufbewahrungspflicht besteht.

## 4. Speicherung und Löschung

Lokale Aufzeichnungen können mit den Löschfunktionen der App entfernt werden. Das Deaktivieren von iCloud löscht bereits dort oder auf anderen Geräten gespeicherte Daten nicht automatisch. Wartende Logs und Kopplungsdaten liegen im Application-Support-Ordner des Mac und können nach dem Löschen der App verbleiben. Bei Fragen zur Löschung helfen wir über den Support. Backups und Neuinstallation beeinflussen die Wiederherstellung. Standardmäßig löschen die Mac- und Windows-Apps ein Roh-Log nach der Empfangsbestätigung durch die Mobil-App. Wird die Aufbewahrung aktiviert, bleiben bestätigte Logs standardmäßig bis zu 500 MB und einen Monat gespeichert (beides anpassbar) und können exportiert, manuell erneut gesendet oder gelöscht werden. Unbestätigte Logs sind von automatischer Bereinigung und manuellem Löschen ausgenommen.

## 5. Externe Dienste und Änderungen

MochiLog nutzt keine Werbe-, Tracking- oder Drittanbieter-Nutzungsanalyse-SDKs. Freiwillige Trinkgelder der App-Store-Version verwenden Apple StoreKit. Cloudflare liefert die Website aus und kann dabei Netzwerkdaten wie IP-Adressen verarbeiten. Änderungen dieser Erklärung werden auf der Website und in der App mit Aktualisierungsdatum veröffentlicht.

## 6. Kontakt

Fragen und Anfragen zur Löschung von Support-E-Mails: support@mochilog.ryuya-dev.net.

Revised: 2026-10-09

Die vollständige Akkuansicht kann auch Herstellungsdaten, Akku-Kennungen und Statuskennzeichen im Arbeitsspeicher verarbeiten. Originalnamen und Werte der API werden ohne angenommene Einheiten angezeigt. Sie werden nicht gespeichert oder Supportprotokollen beigefügt und mit der bestehenden Kopplung verschlüsselt übertragen.


Die PC-Protokollfreigabe überträgt Protokolle anderer Geräte verschlüsselt nur, wenn beide mit demselben Computer gekoppelt sind, iCloud-Synchronisierung aktiviert ist und derselbe Apple Account bestätigt wurde. Ein Hash der app-spezifischen CloudKit-Benutzer-ID dient zum Abgleich; Apple ID, E-Mail und ursprüngliche Benutzer-ID werden nicht an den Computer gesendet. Der Hash ist ein Account-Kennzeichen, keine Anonymitätsgarantie. Die Zustimmung wird befristet im Computerspeicher gehalten und bei deaktivierter Synchronisierung oder Account-Wechsel widerrufen. Ohne Verbindung kann die letzte Zustimmung bis zu 15 Minuten bestehen bleiben. Die Identität des Quellgeräts bleibt erhalten. Protokolle gehen nicht an einen Entwicklerserver.

Die optionale Erfassung auf dem Gerät authentifiziert sich über ein lokales VPN bzw. einen Reflektor beim Diagnosedienst dieses Geräts. OS-Kopplungsdaten liegen im gerätespezifischen Schlüsselbund und werden ausdrücklich über eine verschlüsselte, authentifizierte PC-Verbindung übernommen oder vom Nutzer importiert. Schlüssel und Analyseprotokolle werden nicht an einen Entwicklerserver gesendet. Zwischendateien werden nach erfolgreichem Import gelöscht. Aktuelle Werte anderer Geräte am selben PC werden nur bei bestätigter iCloud-Synchronisierung auf beiden Geräten und gleichem Apple Account geteilt; die Werte werden nicht im Verlauf, in iCloud oder in Diagnoseprotokollen gespeichert. Automatische PC-Updateprüfungen sind standardmäßig aus und verbinden sich bei Aktivierung mit GitHub. Die Datenschutzbedingungen des VPN-Dienstes gelten ebenfalls.
