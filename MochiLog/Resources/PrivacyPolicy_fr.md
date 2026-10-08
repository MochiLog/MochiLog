# Politique de confidentialité de MochiLog

## 1. Données traitées

MochiLog traite sur l’appareil les journaux d’analyse iPhone, iPad et Apple Watch choisis par l’utilisateur. Il conserve les mesures de batterie, le modèle, la date, la capacité, la région du produit et des identifiants distinguant les appareils physiques. Les journaux d’origine peuvent contenir d’autres données sur l’appareil et son utilisation. Les réglages et relevés restent normalement sur l’appareil et ne sont pas envoyés automatiquement au développeur.

## 2. Synchronisation et transfert facultatifs

Avec iCloud activé, les relevés sont synchronisés via la base iCloud privée de l’utilisateur entre ses appareils utilisant le même compte Apple. Ils peuvent être transmis à l’Apple Watch jumelée ou exportés et partagés sur demande. Dans la bêta de transfert pour iOS/iPadOS 27 et macOS 27, un Mac jumelé collecte les journaux quand l’appareil mobile est déverrouillé, les garde temporairement et les transmet chiffrés sur le réseau local. Mac et mobile échangent les données de jumelage, l’état et des diagnostics. Les journaux ne vont pas vers un serveur du développeur. L’app Mac contacte GitHub pour les mises à jour; GitHub peut recevoir des informations réseau comme l’adresse IP. La version alpha pour Windows 11 transmet aussi les journaux d’un PC jumelé à MochiLog sous forme chiffrée.

Si Batterie en direct est activée, un ordinateur jumelé lit les cycles et capacités actuels via le service de diagnostic de l’appareil et les transmet chiffrés à l’app mobile. Ces valeurs restent uniquement en mémoire et ne sont pas enregistrées dans l’historique, les relevés de batterie, iCloud ou les journaux de diagnostic du support. Le réglage est désactivé par défaut. Ce traitement est distinct de la collecte et conservation des fichiers Analytics quotidiens. Les conditions et le traitement des données d’un VPN configuré par l’utilisateur, tel que Tailscale, s’appliquent également.

## 3. Assistance

Si l’utilisateur envoie un courriel au support, le développeur reçoit son pseudonyme, son adresse, son message et ses pièces jointes. Le support du transfert Mac joint lors de l’envoi les versions OS/app, le modèle, l’état du transfert, des identifiants, erreurs et événements de diagnostic récents. Ces événements peuvent contenir des noms ou chemins de fichiers. Vérifiez le courriel avant envoi. Les fournisseurs de messagerie traitent le message. Les données sont conservées selon les besoins du traitement et des dossiers nécessaires; les demandes de suppression sont honorées sauf obligation légale.

## 4. Conservation et suppression

Les relevés locaux peuvent être supprimés dans l’app. Désactiver iCloud ne supprime pas automatiquement les données déjà présentes sur iCloud ou un autre appareil. Les journaux en attente et données de jumelage du Mac sont dans Application Support et peuvent rester après la suppression de l’app seule. Contactez le support pour obtenir de l’aide. Sauvegardes et réinstallations influent sur la restauration. Par défaut, les apps Mac et Windows suppriment un journal brut après confirmation de réception par l’app mobile. Si la conservation est activée, les journaux confirmés sont gardés jusqu’à 500 Mo et un mois par défaut (limites modifiables), et peuvent être exportés, renvoyés manuellement ou supprimés. Les journaux en attente sont exclus du nettoyage automatique et de la suppression manuelle.

## 5. Services externes et modifications

MochiLog n’utilise aucun SDK publicitaire, de suivi ou d’analyse d’utilisation tiers. Les pourboires facultatifs de la version App Store utilisent Apple StoreKit. Cloudflare diffuse le site et peut traiter des données réseau comme l’adresse IP. Les modifications seront publiées sur le site et dans l’app avec la date de mise à jour.

## 6. Contact

Questions et demandes de suppression des courriels de support : support@mochilog.ryuya-dev.net.

Revised: 2026-10-07

La vue complète peut traiter en mémoire les métadonnées de fabrication, identifiants de batterie et indicateurs d’état. Les noms et valeurs de l’API sont affichés sans déduire les unités. Ils ne sont ni enregistrés ni joints aux journaux d’assistance et sont transférés chiffrés avec le jumelage existant.


Le partage de journaux PC transmet les journaux d’un autre appareil chiffrés uniquement si les deux sont jumelés au même ordinateur, ont la synchronisation iCloud activée et si le même compte Apple est confirmé. La comparaison utilise une empreinte de l’identifiant CloudKit propre à l’app ; l’Apple ID, l’adresse e-mail et l’identifiant original ne sont pas transmis au PC. Cette empreinte identifie le compte pour comparaison et ne garantit pas l’anonymat. Le consentement est temporaire en mémoire et révoqué à la désactivation de la synchronisation ou au changement de compte. Sans connexion, il peut subsister jusqu’à 15 minutes. L’identité source est conservée. Aucun journal n’est envoyé à un serveur du développeur.
