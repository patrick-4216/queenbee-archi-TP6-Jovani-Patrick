# Analyse de menaces STRIDE — QueenBee

## 1. Périmètre et hypothèses

L'analyse couvre le parcours capteur → passerelle → broker → plateforme Data → API centrale → application mobile/portail analytics, ainsi que les bases. QueenBee comprend 8 sites, 400 ruches et des utilisateurs répartis sur trois pays. Les sites peuvent être isolés et synchroniser leurs données après une coupure.

Les mesures de sécurité ci-dessous sont des choix de conception à mettre en œuvre et à tester ; elles ne signifient pas que tous les contrôles sont déjà déployés.

## 2. Zones de confiance

| Zone | VLAN / emplacement | Niveau de confiance | Éléments | Contrôles principaux |
|---|---|---|---|---|
| Z1 — IoT | VLAN 40, réseau du site | Faible | Capteurs et liaison LoRaWAN | Identité par équipement, contrôle de trame, limitation radio, séparation réseau. |
| Z2 — DMZ locale | VLAN 10 | Faible | Passerelle exposée et terminaison VPN | Certificat machine, pare-feu entrant restrictif, VPN site-à-site, mises à jour signées. |
| Z3 — LAN applicatif | VLAN 20 | Moyen | Cache edge et services locaux | Segmentation, accès minimaux, chiffrement du cache, file persistante. |
| Z4 — Management | VLAN 30 | Élevé | Administration et supervision | MFA, bastion, RBAC, journalisation, accès nominatif. |
| Z5 — Central / cloud | Hébergement central | Élevé sous réserve des contrôles | API, broker, plateforme Data, PostgreSQL/PostGIS, entrepôt, portail analytics | TLS 1.3, VPN, chiffrement au repos, sauvegardes chiffrées, contrôle d'accès et audit. |
| Z6 — Services tiers | Internet / fournisseurs | Faible à externe | Météo, push/email, identité fédérée éventuelle | TLS, secrets stockés hors code, scopes minimaux, validation des réponses et reprise sur erreur. |

## 3. Flux à protéger

| Flux | Source → destination | Données / protocole | Frontière traversée |
|---|---|---|---|
| F1 | Capteurs → passerelle | Trames LoRaWAN : hive_id, mesures, timestamp, position | Z1 → Z2 |
| F2 | Passerelle → broker central | Trames mises en cache, MQTT/AMQP sur VPN/TLS | Z2/Z3 → Z5 |
| F3 | Broker → plateforme Data | Événement `MesureValidée.v1`, AMQP/TLS | Z5 interne |
| F4 | Plateforme Data ↔ PostgreSQL/PostGIS | Mesures, référentiels, positions, SQL/TLS | Z5 interne |
| F5 | Plateforme Data → entrepôt analytique | Faits, dimensions et agrégats, SQL/TLS | Z5 interne |
| F6 | Application mobile → API centrale | Inspections, récoltes, JWT, HTTPS/JSON | Réseau mobile → Z5 |
| F7 | API centrale → fournisseur push/email | Identifiant destinataire et contenu de notification, HTTPS/API | Z5 → Z6 |
| F8 | Administrateur → API / management | Comptes, rôles, seuils, HTTPS + MFA | Z4 → Z5 |
| F9 | Fournisseur météo → plateforme Data | Données météo, HTTPS/JSON | Z6 → Z5 |

## 4. Tableau des menaces STRIDE

| Flux | STRIDE | Menace concrète | Mesures de réduction précises | Risque résiduel |
|---|---|---|---|---|
| F1 | S — Usurpation | Un faux capteur injecte des mesures attribuées à une ruche réelle. | Identité unique par équipement ; association capteur/ruche dans le référentiel ; authentification de la passerelle et liste d'équipements autorisés ; rotation/révocation des clés. | Compromission physique d'un capteur légitime toujours possible. |
| F1 | T — Falsification | Une trame est modifiée ou rejouée sur le réseau radio. | MAC/signature lorsque le matériel le permet ; compteur de séquence ; contrôle d'horodatage ; déduplication `hive_id + timestamp` ; validation des plages physiques avant publication. | Un capteur compromis peut émettre des valeurs fausses mais plausibles. |
| F2 | D — Déni de service | Coupure VPN, brouillage radio ou rafale de retransmissions sature la synchronisation. | Cache local persistant ; backoff exponentiel ; limitation de débit ; priorisation des alertes critiques ; surveillance du heartbeat et de la taille de file ; reprise automatique. | Une coupure longue ou un brouillage physique peut retarder les données. |
| F2 | I — Divulgation | Les trames ou les identifiants de ruches sont interceptés pendant le transfert. | VPN site-à-site WireGuard/IPsec ; TLS ; chiffrement du cache local ; minimisation des données personnelles ; ACL réseau. | Métadonnées de trafic et disponibilité radio restent observables. |
| F3 | E — Élévation de privilège | Un compte de service Data publie un événement ou accède à un topic non autorisé. | Identité distincte par service ; ACL par topic ; secrets courts/rotatifs ; permissions lecture/écriture minimales ; isolation des comptes de traitement. | Une vulnérabilité dans un service autorisé peut compromettre ses propres flux. |
| F4 | T — Falsification | Un pipeline altère une mesure ou associe la position à la mauvaise ruche. | Transactions SQL ; validation de schéma ; contraintes FK ; journal de rejets ; contrôles de cohérence géographique PostGIS ; tests de données. | Une erreur métier de transformation peut produire une donnée valide techniquement mais erronée. |
| F4 | I — Divulgation | Un analyste lit des données personnelles ou la localisation des bénéficiaires sans nécessité. | RBAC par rôle et site ; vues SQL minimisées ; chiffrement au repos ; comptes nominatifs ; audit des lectures sensibles. | Un utilisateur autorisé peut photographier ou recopier des informations affichées. |
| F5 | R — Répudiation | Un gestionnaire conteste la génération ou la modification d'un rapport d'impact. | Journal d'audit append-only avec utilisateur, action, horodatage UTC, période et filtres du rapport ; empreinte du PDF ; centralisation dès reconnexion. | Une compromission des droits d'administration des journaux peut affaiblir la preuve. |
| F6 | S — Usurpation | Un attaquant utilise un compte apiculteur ou un JWT volé pour envoyer de fausses inspections. | MFA pour les rôles à privilèges ; expiration/rotation des JWT ; blocage après 5 échecs ; révocation de session ; vérification du rattachement ruche/site côté serveur. | Le compte d'un apiculteur peut être compromis par hameçonnage ou téléphone volé. |
| F7 | I — Divulgation | Le contenu d'une notification révèle des informations personnelles ou opérationnelles. | N'envoyer qu'un message minimal (« nouvelle alerte disponible ») ; lien authentifié vers l'application ; TLS ; secrets fournisseur en coffre ; masquage des adresses dans les logs. | Le fournisseur tiers traite les métadonnées de livraison. |
| F8 | E — Élévation de privilège | Un coordinateur modifie des rôles ou des seuils hors de son périmètre. | RBAC avec permissions par site ; MFA ; séparation des fonctions ; validation côté serveur ; journal d'audit non modifiable par l'administrateur métier. | Une erreur de configuration des rôles reste possible. |
| F9 | T — Falsification | Une réponse météo altérée influence les prédictions de santé ou de rendement. | TLS ; validation du schéma, de l'unité, de la plage et de la fraîcheur ; provenance et horodatage ; fallback sur dernière donnée fiable ; indicateur de qualité. | Une source météo peut fournir une prévision erronée sans être compromise. |

## 5. Priorisation

1. **Priorité critique : F1/F2 — intégrité et disponibilité des mesures.** Une donnée falsifiée peut déclencher une mauvaise décision apicole ; une coupure doit activer le cache local et la reprise.
2. **Priorité élevée : F6/F8 — comptes et privilèges.** Les actions doivent être attribuables et limitées au site de l'utilisateur.
3. **Priorité élevée : F4/F5 — confidentialité et traçabilité.** Les données des bénéficiaires et les rapports destinés aux bailleurs nécessitent minimisation, contrôle d'accès et audit.

## 6. Risques résiduels et validation

- Le cache local protège contre les coupures, mais pas contre la destruction physique ou le vol de la passerelle : chiffrer le disque et tester une restauration.
- La signature ne garantit pas qu'une mesure est vraie : comparer les valeurs aux plages physiques, détecter les dérives et permettre une inspection terrain.
- Les alertes calculées à partir de données tardives doivent être distinguées des alertes temps réel conformément à ADR-002.
- Tester une coupure de site, la reprise du VPN, la retransmission d'un lot et le rejet d'un doublon/rejeu ; vérifier que les journaux sont centralisés après reconnexion.
- Vérifier que les sauvegardes quotidiennes sont chiffrées et que les objectifs RTO < 8 h et RPO < 24 h sont démontrables.
