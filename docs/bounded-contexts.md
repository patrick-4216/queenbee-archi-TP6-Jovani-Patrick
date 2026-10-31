# Bounded contexts : QueenBee

QueenBee est découpé en **8 bounded contexts**, tracés là où le vocabulaire change de sens (voir le glossaire) : « alerte » ne veut pas dire la même chose pour la santé d'une colonie et pour une panne de passerelle ; « validation » désigne trois choses différentes ; la « ruche » physique n'est pas la « colonie » observée.

## Vue d'ensemble

| # | Contexte | Type | Spécialité la plus concernée | Agrégats |
|---|---|---|---|---|
| 1 | Référentiel ruchers | support | Data | Ruche, Site |
| 2 | Identité et accès | générique | Cyber | Compte |
| 3 | Collecte et supervision | support | Data · Cyber | Mesure, Incident |
| 4 | Prévision | cœur | Data | PrédictionRisque, PrédictionRendement |
| 5 | Santé des colonies | cœur | Dev | Alerte, ScoreSanté |
| 6 | Intervention terrain | cœur | Dev | Visite, Inspection |
| 7 | Production | cœur | Dev | Récolte |
| 8 | Impact et reporting | support | Data | Rapport |

**Arbitrage 9 → 8 :** la supervision d'infrastructure (passerelles, brouillage, déplacements) a d'abord été pensée comme un contexte à part. Elle est fusionnée avec la collecte pour respecter la limite de 8 contextes : les deux relèvent de la même équipe et de la même chaîne de traitement des trames. La distinction reste visible dans le modèle, puisque **Incident** est un agrégat distinct de **Mesure** et n'est jamais appelé « alerte ». Si la supervision grossit, elle pourra devenir un contexte à part.

---

## 1. Référentiel ruchers

- **Responsabilité :** tenir la liste de référence des sites, des ruches, des capteurs et des passerelles, et leurs associations.
- **Type :** support · spécialité la plus concernée : Data
- **Agrégats :** **Ruche** (invariants : identifiant `hive_id` unique et rattachée à un site ; une ruche désactivée ne reçoit plus de mesures) · **Site** (invariant : une passerelle est rattachée à un seul site).
- **Événements publiés :** Site enregistré · Ruche enregistrée (`RucheEnregistrée.v1`) · Passerelle installée · Capteur associé à une ruche · Déplacement déclaré.
- **Événements consommés :** aucun ; le contexte reçoit seulement des identités et rôles (Identité et accès).
- **Cas d'utilisation sources :** UC-AD01 · UC-CY04 (déplacement déclaré)
- **Mots propres à ce contexte :** ruche (objet physique), site apicole, capteur, passerelle, association d'équipement, transhumance.

## 2. Identité et accès

- **Responsabilité :** gérer les comptes, les rôles, les permissions par site, l'authentification et la traçabilité des actions administratives.
- **Type :** générique · spécialité la plus concernée : Cyber
- **Agrégats :** **Compte** (invariants : bloqué après 5 échecs d'authentification ; rôles limités aux sites assignés).
- **Événements publiés :** Compte créé · Rôle attribué · Compte désactivé · Authentification réussie · Authentification échouée · Compte bloqué (5 échecs).
- **Événements consommés :** aucun.
- **Cas d'utilisation sources :** UC-AD01 · UC-T01
- **Mots propres à ce contexte :** compte, rôle, permission par site, authentification, MFA, journal d'audit.

## 3. Collecte et supervision

- **Responsabilité :** recevoir les trames des capteurs, les contrôler, publier les mesures validées, et surveiller l'état de l'infrastructure (passerelles, canaux, positions).
- **Type :** support · spécialité la plus concernée : Data et Cyber
- **Agrégats :** **Mesure** (invariants : clé `hive_id` + `timestamp` unique ; une mesure hors plage n'est jamais publiée) · **Incident** (invariants : clos seulement après rétablissement constaté ; tout incident est journalisé).
- **Événements publiés :** Mesure validée (`MesureValidée.v1`) · Trame rejetée (hors plage ou rejeu, `TrameRejetée.v1`) · Mesure tardive reçue · Passerelle hors ligne détectée · Mode dégradé activé · Passerelle rétablie · Brouillage détecté · Déplacement non déclaré détecté · Incident d'intégrité déclaré · Indicateurs de qualité calculés (`IndicateursQualité.v1` : mesures reçues, rejetées, doublons, disponibilité des passerelles).
- **Événements consommés :** Ruche enregistrée et Déplacement déclaré (de Référentiel ruchers) ; trames brutes des capteurs via les passerelles LoRaWAN (système externe, ACL).
- **Cas d'utilisation sources :** UC-T02 · UC-CY01 · UC-CY02 · UC-CY03 · UC-CY04
- **Mots propres à ce contexte :** trame, mesure, mesure validée, doublon, rejeu, hors plage, mesure tardive, mode dégradé, battement de cœur, incident.

## 4. Prévision

- **Responsabilité :** transformer les mesures validées et la météo en prédictions de risque et de rendement. Le CDC donne des signaux indicatifs à affiner (chute de poids supérieure à 0,5 kg en moins de 2 h, activité quasi nulle pendant plus de 24 h, canicule externe) ; ils ne sont pas des seuils définitifs.
- **Type :** cœur · spécialité la plus concernée : Data
- **Agrégats :** **PrédictionRisque** (invariants : confiance dans [0 ; 1] ; rattachée à une ruche et une date) · **PrédictionRendement** (invariant : une prédiction vise une ruche et une saison).
- **Événements publiés :** Risque d'essaimage détecté · Risque d'affaiblissement détecté (`RisqueDétecté.v1`) · Prédiction de rendement calculée (`PrédictionRendementCalculée.v1`).
- **Événements consommés :** Mesure validée (de Collecte et supervision) · Récolte validée (de Production) ; données météo d'OpenWeatherMap (ACL).
- **Cas d'utilisation sources :** UC-A02 · UC-A03
- **Mots propres à ce contexte :** modèle de prédiction, prédiction de risque, niveau de confiance, rendement prédit.

## 5. Santé des colonies

- **Responsabilité :** gérer le cycle de vie des alertes de colonie, de la levée à la résolution, avec l'escalade après 48 h. Les seuils d'alerte sont configurés par l'administrateur, par type de ruche et par site (CDC, rôle Administrateur) ; ce contexte les applique mais ne les invente pas.
- **Type :** cœur · spécialité la plus concernée : Dev
- **Agrégats :** **Alerte** (invariants : une alerte résolue n'accepte plus aucune transition ; la résolution exige une prise en charge et une inspection identifiée) · **ScoreSanté** (invariant : calculé uniquement à partir de mesures validées).
- **Événements publiés :** Alerte levée (`AlerteLevée.v1`) · Alerte prise en charge · Alerte escaladée (`AlerteEscaladée.v1`) · Alerte résolue · Alerte annulée · Score de santé recalculé · Apicultrice notifiée.
- **Événements consommés :** Risque détecté (de Prévision) · Mesure validée (de Collecte et supervision, pour le score) · Inspection synchronisée (de Intervention terrain).
- **Cas d'utilisation sources :** UC-A02 (et UC-A01 pour la résolution)
- **Mots propres à ce contexte :** colonie, risque, essaimage, seuil de risque, score de santé, alerte, prise en charge, escalade, notification.

## 6. Intervention terrain

- **Responsabilité :** planifier et assigner les visites, enregistrer les inspections (même hors ligne), synchroniser et résoudre les conflits.
- **Type :** cœur · spécialité la plus concernée : Dev
- **Agrégats :** **Visite** (invariants : assignée à une seule personne ; date future à la planification) · **Inspection** (invariants : rattachée à une ruche existante ; une synchronisation n'écrase jamais silencieusement une version plus récente).
- **Événements publiés :** Visite planifiée · Visite assignée · Inspection enregistrée hors ligne · Inspection synchronisée (`InspectionSynchronisée.v1`) · Conflit de synchronisation détecté · Anomalie constatée · Coordinateur notifié.
- **Événements consommés :** Alerte levée et Alerte escaladée (de Santé des colonies) · Ruche enregistrée (de Référentiel ruchers) ; inspections issues de l'application mobile (ACL).
- **Cas d'utilisation sources :** UC-A01 · UC-C01
- **Mots propres à ce contexte :** visite, visite anticipée, inspection, inspection hors ligne, anomalie constatée, synchronisation, conflit de synchronisation.

## 7. Production

- **Responsabilité :** enregistrer les récoltes, les comparer à la prédiction, valider ou investiguer les écarts.
- **Type :** cœur · spécialité la plus concernée : Dev
- **Agrégats :** **Récolte** (invariants : volume positif ; une récolte validée ne change plus ; un écart signalé exige un commentaire).
- **Événements publiés :** Récolte déclarée · Écart de rendement calculé · Coopérative notifiée · Écart mis en investigation · Récolte validée (`RécolteValidée.v1`).
- **Événements consommés :** Prédiction de rendement calculée (de Prévision) · Ruche enregistrée (de Référentiel ruchers).
- **Cas d'utilisation sources :** UC-A03 · UC-C02
- **Mots propres à ce contexte :** récolte, écart de rendement, seuil d'écart, investigation, validation (récolte), coopérative.

## 8. Impact et reporting

- **Responsabilité :** consolider les indicateurs multi-sites et produire les rapports d'impact pour les bailleurs.
- **Type :** support · spécialité la plus concernée : Data
- **Agrégats :** **Rapport** (invariants : période cohérente, début < fin ; il ne contient que les sites autorisés au demandeur).
- **Événements publiés :** Indicateurs consolidés · Période de rapport choisie · Rapport d'impact généré · Rapport envoyé au bailleur.
- **Événements consommés :** Récolte validée (de Production) · Alerte résolue (de Santé des colonies) · Indicateurs de qualité calculés (`IndicateursQualité.v1`, de Collecte et supervision).
- **Cas d'utilisation sources :** UC-G01 · UC-G02
- **Mots propres à ce contexte :** indicateur, période de rapport, rapport d'impact, bailleur, site (axe de comparaison).

---

## Flux entre contextes (base de la context map)

Chaque ligne est un événement qui traverse une frontière : l'amont le publie, l'aval le consomme. Les types de relation sont une proposition à reporter dans `context-map.md`.

| Amont (publie) | Aval (consomme) | Événement ou échange | Relation proposée |
|---|---|---|---|
| Référentiel ruchers | Collecte et supervision | `RucheEnregistrée.v1`, Déplacement déclaré | U/D · OHS + PL |
| Référentiel ruchers | Intervention terrain, Production | `RucheEnregistrée.v1` | U/D · OHS + PL |
| Collecte et supervision | Santé des colonies | `MesureValidée.v1` | U/D · PL |
| Collecte et supervision | Prévision | `MesureValidée.v1` | U/D · PL |
| Collecte et supervision | Impact et reporting | `IndicateursQualité.v1` | U/D · PL |
| Prévision | Santé des colonies | `RisqueDétecté.v1` | U/D · PL |
| Prévision | Production | `PrédictionRendementCalculée.v1` | U/D · PL |
| Production | Prévision | `RécolteValidée.v1` (retour d'apprentissage) | Partnership (boucle de rétroaction) |
| Production | Impact et reporting | `RécolteValidée.v1` | U/D · PL |
| Santé des colonies | Intervention terrain | `AlerteLevée.v1`, `AlerteEscaladée.v1` | Partnership |
| Intervention terrain | Santé des colonies | `InspectionSynchronisée.v1` | Partnership |
| Santé des colonies | Impact et reporting | Alerte résolue | U/D · PL |
| Identité et accès | Tous les autres contextes | identité, rôles, permissions (JWT) | U/D · OHS |
| Systèmes externes | Collecte, Prévision, Terrain | trames, météo, inspections hors ligne | ACL |

Santé et Terrain forment une paire de contextes qui évoluent ensemble (alerte → inspection → résolution) : c'est un Partnership, plutôt que deux relations U/D croisées. Il en va de même pour Prévision et Production.

## Règles de délimitation

- Chaque événement et chaque agrégat appartient à **un seul** contexte (par exemple « Alerte prise en charge » n'est plus dupliqué dans Intervention terrain : c'est Santé qui le publie).
- Un contexte ne modifie jamais l'agrégat d'un autre : il publie un événement, et l'autre réagit par une politique (par exemple, Inspection synchronisée → Santé résout l'alerte).
- **Collecte et supervision** est seul responsable de la validité d'une mesure ; les consommateurs ne la revalident pas.
- **Santé des colonies** est seule propriétaire du mot « alerte ». Les pannes d'infrastructure sont des *incidents*.
- **Référentiel ruchers** est propriétaire des associations ruche–capteur–site–passerelle.
- **Identité et accès** ne publie pas de données métier : il fournit identités et rôles.

## Systèmes externes (hors contextes)

| Système | Relié à | Protection |
|---|---|---|
| Capteurs + passerelles LoRaWAN | Collecte et supervision | ACL : traduction de la trame brute en mesure |
| OpenWeatherMap | Prévision | ACL |
| Modèle de prédiction | Prévision | ACL si exécuté hors de la plateforme |
| Service de notification (push, SMS, e-mail) | Santé, Intervention terrain, Production, Collecte et supervision | ACL : demande d'envoi |
| Application mobile terrain | Intervention terrain | ACL : format hors ligne vers le modèle Terrain |

## Points à trancher (voir `points-chauds.md`)

- Qui est propriétaire des associations ruche–capteur–passerelle : Référentiel seul, ou aussi Collecte ?
- Quel contexte orchestre les notifications, ou faut-il un service dédié ?
- Reporting consomme-t-il des événements ou des indicateurs préagrégés ?