# Glossaire métier : QueenBee

Ce glossaire fixe le langage omniprésent du projet. Il est aligné sur le mur Event Storming (9 bounded contexts), la context map et le contrat `MesureValidée.v1`. Un mot qui a deux sens dans deux contextes a **deux lignes** (voir la section « Mots à plusieurs sens »).

## Termes par contexte

### Référentiel ruchers (support)

| Terme | Définition validée | Contexte | Dans le code | Source |
|---|---|---|---|---|
| Site apicole | Rucher géographique regroupant des ruches et rattaché à une passerelle. | Référentiel ruchers | `SiteApicole` | UC-CY01 |
| Ruche | Objet physique équipé d'un capteur, identifié par `hive_id` (format `PP-SITE-NNN`). | Référentiel ruchers | `Ruche` | UC-T02 |
| Capteur | Dispositif monté sur une ruche qui mesure poids, températures, humidité et activité acoustique. | Référentiel ruchers | `Capteur` | UC-T02 |
| Passerelle | Relais LoRaWAN d'un site qui reçoit les trames des capteurs et les transmet au central, parfois en différé. | Référentiel ruchers | `Passerelle` | UC-T02, UC-CY01 |
| Association d'équipement | Lien entre une ruche, son capteur, son site et sa passerelle ; le référentiel en est propriétaire. | Référentiel ruchers | `AssociationEquipement` | UC-T02 |
| Transhumance | Déplacement déclaré d'une ruche vers une autre position. | Référentiel ruchers | `Transhumance` | UC-CY04 |

### Identité et accès (générique)

| Terme | Définition validée | Contexte | Dans le code | Source |
|---|---|---|---|---|
| Compte | Identité d'une personne qui utilise QueenBee, avec un état (actif, bloqué, désactivé). | Identité et accès | `Compte` | UC-AD01 |
| Rôle | Ensemble de droits d'une catégorie d'utilisateur (apicultrice, coordinateur, gestionnaire, administrateur). | Identité et accès | `Role` | UC-AD01 |
| Permission par site | Autorisation donnée à un compte pour agir sur un site précis. | Identité et accès | `PermissionSite` | UC-AD01 |
| Authentification | Vérification de l'identité d'un compte à la connexion, avec MFA pour coordinateurs, gestionnaires et administrateurs. | Identité et accès | `Authentification` | UC-T01 |
| Blocage de compte | Verrouillage d'un compte après 5 échecs d'authentification. | Identité et accès | `Compte.bloquer()` | UC-T01 |
| Journal d'audit | Historique des actions administratives et des événements de sécurité. | Identité et accès | `JournalAudit` | UC-AD01 |

### Collecte des mesures (support)

| Terme | Définition validée | Contexte | Dans le code | Source |
|---|---|---|---|---|
| Trame | Message brut reçu de la passerelle, avant tout contrôle. | Collecte des mesures | `Trame` | UC-T02, UC-CY02 |
| Mesure | Relevé d'une ruche (poids, températures, humidité, score acoustique, batterie, position) à une date donnée. | Collecte des mesures | `Mesure` | UC-T02 |
| Mesure validée | Mesure qui a passé tous les contrôles (ruche connue, plage, doublon, rejeu, authenticité) ; c'est l'événement publié `MesureValidée.v1`. | Collecte des mesures | `MesureValidee` | UC-T02, UC-CY02 |
| Horodatage de mesure | Date et heure de production de la mesure (`timestamp` / `occurredAt`), en UTC ; c'est la référence temporelle métier. | Collecte des mesures | `occurredAt` | UC-T02 |
| Date de réception | Date et heure de réception au central (`receivedAt`) ; sert à mesurer le retard. | Collecte des mesures | `receivedAt` | UC-CY01 |
| Mesure tardive | Mesure reçue longtemps après sa production (mode dégradé) ; elle garde sa date d'origine et ne déclenche pas d'alerte « neuve ». | Collecte des mesures | `MesureTardive` | UC-CY01 |
| Doublon | Mesure déjà reçue, identifiée par la clé `hive_id` + `timestamp`. | Collecte des mesures | `Doublon` | UC-CY02 |
| Rejeu | Trame ou événement déjà traité, renvoyé (accidentellement ou par une attaque). | Collecte des mesures | `Rejeu` | UC-CY02 |
| Trame hors plage | Trame dont au moins une valeur dépasse la plage physique valide ; elle est rejetée. | Collecte des mesures | `TrameHorsPlage` | UC-CY02 |
| Capteur silencieux | Capteur dont aucune mesure n'est arrivée depuis deux intervalles de transmission. | Collecte des mesures | `CapteurSilencieux` | UC-T02 |
| Surveillance renforcée | Mode où la cadence passe de 1 mesure / 15 min à 1 mesure / 5 min. | Collecte des mesures | `SurveillanceRenforcee` | UC-T02 |
| Contrat de données | Définition partagée des champs, règles de validation et versionnement d'un événement échangé entre contextes. | Collecte des mesures | `DataContract` | TP5 (Data) |

### Supervision et sécurité (support)

| Terme | Définition validée | Contexte | Dans le code | Source |
|---|---|---|---|---|
| Incident | Panne ou anomalie d'infrastructure ou de sécurité (passerelle muette, brouillage, déplacement non déclaré, intégrité des données). Ce n'est **pas** une alerte. | Supervision et sécurité | `Incident` | UC-CY01 à CY04 |
| Battement de cœur | Signal régulier d'une passerelle prouvant qu'elle fonctionne ; absent depuis 15 min, il ouvre un incident. | Supervision et sécurité | `Heartbeat` | UC-CY01 |
| Mode dégradé | Fonctionnement sur cache local quand la passerelle ou le réseau est indisponible, avec resynchronisation ensuite. | Supervision et sécurité | `ModeDegrade` | UC-CY01 |
| Brouillage | Taux anormal de trames perdues sur un canal, avec proposition de changement de canal. | Supervision et sécurité | `Brouillage` | UC-CY03 |
| Incident d'intégrité | Rejets répétés de trames hors plage ou rejouées ; le CDC l'appelle « alerte d'intégrité ». | Supervision et sécurité | `IncidentIntegrite` | UC-CY02 |
| Déplacement non déclaré | Position GPS hors tolérance sans transhumance déclarée ; notification prioritaire au coordinateur et à l'administrateur. | Supervision et sécurité | `DeplacementNonDeclare` | UC-CY04 |

### Prévision (cœur)

| Terme | Définition validée | Contexte | Dans le code | Source |
|---|---|---|---|---|
| Modèle de prédiction | Système qui calcule risques et rendements à partir des mesures validées et de la météo ; système externe vu depuis QueenBee. | Prévision | `ModelePrediction` | UC-A02, UC-A03 |
| Prédiction de risque | Résultat du modèle : type de risque, niveau de confiance, ruche et date concernées. | Prévision | `PredictionRisque` | UC-A02 |
| Niveau de confiance | Valeur numérique dans [0 ; 1] attachée à une prédiction. | Prévision | `confiance` | UC-A02 |
| Rendement prédit | Volume de miel attendu pour une ruche et une saison. | Prévision | `PredictionRendement` | UC-A03 |
| Donnée météo | Information récupérée auprès d'OpenWeatherMap pour enrichir les prédictions. | Prévision | `DonneeMeteo` | CDC §6 |

### Santé des colonies (cœur)

| Terme | Définition validée | Contexte | Dans le code | Source |
|---|---|---|---|---|
| Colonie | Population d'abeilles vivant dans une ruche, dont on évalue la santé. | Santé des colonies | `Colonie` | UC-A02 |
| Risque | Menace sur une colonie : essaimage, affaiblissement, etc. | Santé des colonies | `TypeDeRisque` | UC-A02 |
| Essaimage | Départ d'une partie de la colonie pour former un nouvel essaim. | Santé des colonies | `RisqueEssaimage` | UC-A02 |
| Seuil de risque | Valeur de référence au-delà de laquelle une mesure signale un risque. | Santé des colonies | `SeuilRisque` | UC-A02 |
| Score de santé | Indicateur synthétique de l'état d'une colonie. | Santé des colonies | `ScoreSante` | UC-A02 |
| **Alerte** | Objet métier créé quand un risque touche une **colonie** ; il a un type de risque, une confiance et un cycle de vie : levée, prise en charge, résolue ou escaladée. | Santé des colonies | `Alerte` | UC-A02 |
| Prise en charge | Engagement d'une apicultrice ou d'un apiculteur à traiter l'alerte. | Santé des colonies | `Alerte.assigner()` | UC-A02 |
| Escalade | Passage au niveau supérieur d'une alerte sans prise en charge après 48 h. | Santé des colonies | `Alerte.escalader()` | UC-A02 |
| Résolution | Clôture d'une alerte après une inspection ; plus aucune transition n'est ensuite permise. | Santé des colonies | `Alerte.resoudre()` | UC-A02, UC-A01 |
| Fausse alerte | Alerte annulée par le coordinateur (état `ANNULÉE`, option du TP Dev). | Santé des colonies | `Alerte.annuler()` | UC-A02 |
| Notification | Message envoyé à une personne pour l'informer. Ce n'est pas l'alerte : une alerte peut exister sans notification reçue (apicultrice hors ligne). | Santé des colonies | `Notification` | UC-A02 |

### Intervention terrain (cœur)

| Terme | Définition validée | Contexte | Dans le code | Source |
|---|---|---|---|---|
| Visite | Intervention planifiée sur une ou plusieurs ruches et assignée à une personne. | Intervention terrain | `Visite` | UC-C01 |
| Visite anticipée | Visite avancée à cause d'une alerte. | Intervention terrain | `VisiteAnticipee` | UC-A02 |
| Inspection | Observation faite sur place : état visuel, reine, comportement, photo. | Intervention terrain | `Inspection` | UC-A01 |
| Inspection hors ligne | Inspection enregistrée sans réseau et stockée localement jusqu'à la synchronisation. | Intervention terrain | `InspectionHorsLigne` | UC-A01 |
| Anomalie constatée | Situation inhabituelle relevée lors d'une inspection ; le coordinateur est notifié. | Intervention terrain | `AnomalieConstatee` | UC-A01 |
| Synchronisation (terrain) | Envoi au central des inspections faites hors ligne, au retour du réseau. | Intervention terrain | `Synchronisation` | UC-A01 |
| Conflit de synchronisation | Version locale et version centrale d'une inspection qui divergent. | Intervention terrain | `ConflitSynchro` | UC-A01 |

### Production (cœur)

| Terme | Définition validée | Contexte | Dans le code | Source |
|---|---|---|---|---|
| Récolte | Volume de miel déclaré pour une ruche, à une date. | Production | `Recolte` | UC-A03 |
| Écart de rendement | Différence en % entre la récolte déclarée et le rendement prédit. | Production | `ecartRendement` | UC-A03 |
| Seuil d'écart | Pourcentage d'écart (20 % proposé) au-delà duquel coopérative et coordinateur sont notifiés. | Production | `SeuilEcart` | UC-A03 |
| Investigation d'écart | Examen d'une récolte dont l'écart est suspect, avec commentaire obligatoire. | Production | `Recolte.signalerEcart()` | UC-C02 |
| Validation (récolte) | Acceptation de la déclaration par le coordinateur après comparaison aux poids mesurés. | Production | `Recolte.valider()` | UC-C02 |
| Coopérative | Groupe de producteurs qui reçoit la notification d'une récolte déclarée. | Production | `Cooperative` | UC-A03 |

### Impact et reporting (support)

| Terme | Définition validée | Contexte | Dans le code | Source |
|---|---|---|---|---|
| Indicateur | Valeur consolidée (rendement, colonies à risque, couverture réseau) pour un site ou un pays. | Impact et reporting | `Indicateur` | UC-G01 |
| Période de rapport | Intervalle de dates choisi par le gestionnaire pour un rapport. | Impact et reporting | `PeriodeRapport` | UC-G02 |
| Rapport d'impact | Document PDF d'indicateurs, téléchargé ou envoyé au bailleur. | Impact et reporting | `RapportImpact` | UC-G02 |
| Bailleur | Financeur qui reçoit les rapports d'impact. | Impact et reporting | `Bailleur` | UC-G02 |

### Transverse

| Terme | Définition validée | Contexte | Dans le code | Source |
|---|---|---|---|---|
| Apicultrice / apiculteur | Personne qui inspecte les ruches, déclare les récoltes et prend en charge les alertes. | Tous | `Apiculteur` | UC-A01 à A03 |
| Coordinateur | Personne qui planifie les visites, valide les récoltes et suit les anomalies d'une région. | Tous | `Coordinateur` | UC-C01, C02 |
| Gestionnaire | Personne qui consulte les indicateurs et produit les rapports. | Tous | `Gestionnaire` | UC-G01, G02 |
| Administrateur | Personne qui gère comptes, rôles et permissions. | Tous | `Administrateur` | UC-AD01 |
| Événement métier | Fait significatif exprimé au passé (« Mesure validée », « Alerte levée »). | Tous | nom de l'événement | TP5 |
| Bounded context | Périmètre où un modèle et son vocabulaire ont un sens précis. | Architecture | — | TP5 |
| Context map | Représentation des relations typées entre bounded contexts. | Architecture | — | TP5 |

## Mots à plusieurs sens

- **« Alerte »** : deux sens, **deux termes**.
  - *Alerte* (Santé des colonies) : risque sur une colonie, avec prise en charge, résolution et escalade ; destinataire : l'apicultrice.
  - *Incident* (Supervision et sécurité) : panne ou anomalie d'infrastructure ou de sécurité, avec détection et rétablissement ; destinataires : coordinateur et administrateur.
  - **Décision :** le mot « alerte » est réservé à la colonie. Les « alertes » du CDC côté infrastructure (alerte de site, d'intégrité, de brouillage, prioritaire) sont nommées *incidents* ou *notifications* dans le modèle. Raison : cycles de vie, personnes et règles différents.
- **« Validation »** : trois sens, un par contexte.
  - *Validation (mesure)* : contrôle automatique, dans Collecte des mesures.
  - *Validation (récolte)* : acceptation par le coordinateur, dans Production.
  - *Authentification* : vérification d'identité, dans Identité et accès (le mot « validation » n'y est pas utilisé).
- **« Ruche » / « Colonie »** : la *ruche* est l'objet physique équipé d'un capteur (Référentiel) ; la *colonie* est la population dont on suit la santé (Santé des colonies).
- **« Site »** : *site apicole* dans le Référentiel (lieu physique avec passerelle) ; dans Impact et reporting, le site est un axe de comparaison des indicateurs.
- **« Seuil »** : *seuil de risque* (Santé des colonies) et *seuil d'écart* (Production) ont des propriétaires et des valeurs différents.
- **« Synchronisation »** : *synchronisation terrain* (inspections de l'application mobile) dans Intervention terrain ; *resynchronisation* d'une passerelle après coupure dans Supervision.
- **« Notification »** : toujours un message d'information ; elle n'est jamais une alerte, un incident ou un événement métier.

## Conventions

- Les événements métier sont au passé ; les commandes à l'impératif.
- Les noms de code sont des conventions de nommage, pas la preuve qu'une classe existe déjà.
- Les valeurs non fixées par le CDC (plages physiques, retard maximal de 24 h, seuil de 20 %, seuil de 3 rejets par heure) sont des propositions, listées dans `points-chauds.md`.