# Contrat de données: `MesureValidée.v1`

## 1. Objet

L’événement `MesureValidée.v1` représente une mesure provenant d’une ruche connectée, après validation par le contexte **Collecte et qualité des données**.

Cet événement constitue le **Published Language** utilisé pour transmettre une mesure fiable aux contextes consommateurs.

La mesure contient les données décrites dans le format 6.5 du cahier des charges : identification de la ruche et du site, horodatage, position GPS, poids, températures, humidité, activité acoustique et batterie.

---

## 2. Propriétaire et consommateurs

### Contexte propriétaire

**Collecte et qualité des données**

Responsabilités :

- recevoir les mesures IoT ;
- vérifier l’identification de la ruche ;
- contrôler les plages physiques ;
- détecter les doublons et les rejeux ;
- gérer les mesures reçues en différé ;
- valider les mesures ;
- publier `MesureValidée.v1`.

### Consommateurs

| Contexte consommateur | Utilisation de `MesureValidée.v1` |
|---|---|
| **Santé des colonies et alertes** | Calcul des indicateurs de santé, détection des risques et déclenchement des alertes |
| **Pilotage et reporting** | Consolidation des indicateurs, suivi de la couverture et production des rapports |
| **Prédiction / traitement Data** | Préparation des données nécessaires aux traitements prédictifs |

Le contexte **Collecte et qualité des données** reste propriétaire de la signification et du contrat de la mesure.

---

# 3. Contrat du payload

Les champs correspondent au format 6.5 du cahier des charges.

> **Important :** le cahier des charges ne fournit pas toutes les plages physiques. Les plages indiquées comme « proposition » sont donc des règles techniques à faire valider par le métier ou l’équipe Data/IoT.

| Champ | Type | Unité | Plage valide | Obligatoire | Règle de validation |
|---|---|---|---|---|---|
| `hive_id` | string | — | Format `PP-SITE-NNN` | Oui | La ruche doit exister dans le référentiel. Sinon, la trame est rejetée. |
| `site_id` | string | — | Site connu du référentiel | Oui | Le site doit exister et être associé à la ruche. |
| `timestamp` | string ISO 8601 UTC | — | `<= maintenant + 5 min` | Oui | L’horodatage doit être valide et en UTC. Avec `hive_id`, il constitue la clé de déduplication. |
| `position_lat` | number | degré | `-90` à `+90` | Oui | La latitude doit être dans une plage géographique valide. |
| `position_lon` | number | degré | `-180` à `+180` | Oui | La longitude doit être dans une plage géographique valide. |
| `weight_kg` | number | kg | `0` à `120` *(proposition)* | Oui | Une valeur hors plage est rejetée. Une variation brutale doit être conservée comme signal possible d’anomalie et non confondue automatiquement avec une erreur. |
| `temp_internal_c` | number | °C | `0` à `60` *(proposition)* | Oui | Valeur numérique et comprise dans la plage physique configurée. |
| `temp_external_c` | number | °C | `-30` à `60` *(proposition)* | Oui | Valeur numérique et comprise dans la plage physique configurée. |
| `humidity_pct` | number | % | `0` à `100` | Oui | La valeur doit être comprise entre 0 et 100 %. |
| `acoustic_activity_score` | number | score | `0` à `1` *(si score normalisé)* | Oui | Le score doit être compris entre 0 et 1. L’audio brut n’est jamais transmis. |
| `battery_pct` | number | % | `0` à `100` | Oui | La valeur doit être comprise entre 0 et 100 %. |

### Remarque sur les plages physiques

Le TP fournit explicitement comme exemple une plage `0–120 kg` pour `weight_kg`, mais demande de compléter les autres plages. Les autres valeurs ci-dessus constituent donc une **proposition de validation technique** et devront être confirmées avec le métier ou le matériel réellement choisi.

---

# 4. Enveloppe de l’événement

Chaque événement est transporté avec une enveloppe permettant son identification, son versionnement et sa traçabilité.

| Champ | Type | Description |
|---|---|---|
| `eventId` | UUID/string | Identifiant unique de l’événement |
| `type` | string | Type de l’événement : `MesureValidée` |
| `version` | integer | Version du contrat |
| `occurredAt` | string ISO 8601 UTC | Date/heure associée à l’événement de mesure |
| `receivedAt` | string ISO 8601 UTC | Date/heure de réception au système central |
| `producer` | string | Contexte ayant produit l’événement |
| `payload` | object | Données validées de la mesure |

### Différence entre `occurredAt` et `receivedAt`

`occurredAt` correspond à la date de la mesure.

`receivedAt` correspond à la date de réception au système central.

Cette distinction est importante en **mode dégradé** : une passerelle peut conserver localement plusieurs mesures puis les transmettre lorsque la connexion est rétablie.

Une mesure peut donc avoir :

```text
occurredAt = 08:15
receivedAt = 08:41
```

Les traitements d’alerte doivent utiliser `occurredAt` pour respecter la chronologie réelle des mesures et ne pas considérer automatiquement une mesure ancienne comme une nouvelle mesure.

---

# 5. Exemple JSON

```json
{
  "eventId": "6f1c2a9e-5b7d-4c1e-9a3f-2d8e0b4c7a11",
  "type": "MesureValidée",
  "version": 1,
  "occurredAt": "2027-03-14T08:15:00Z",
  "receivedAt": "2027-03-14T08:41:12Z",
  "producer": "Collecte et qualité des données",
  "payload": {
    "hive_id": "SN-CASA-014",
    "site_id": "SN-CASA",
    "timestamp": "2027-03-14T08:15:00Z",
    "weight_kg": 34.2,
    "temp_internal_c": 34.8,
    "temp_external_c": 27.1,
    "humidity_pct": 58,
    "acoustic_activity_score": 0.72,
    "battery_pct": 91,
    "position_lat": 12.5833,
    "position_lon": -16.2833
  }
}
```

---

# 6. Règles de validation

Une mesure n’est publiée comme `MesureValidée.v1` qu’après validation.

Les contrôles suivants sont effectués :

1. La ruche existe dans le référentiel.
2. Le site existe.
3. La ruche est associée au site indiqué.
4. Le timestamp respecte le format ISO 8601 UTC.
5. Le timestamp ne doit pas être supérieur à `maintenant + 5 minutes`.
6. Les valeurs numériques respectent leurs plages physiques.
7. Les coordonnées GPS sont valides.
8. La mesure n’est pas un doublon.
9. La trame n’est pas un rejeu déjà traité.
10. La mesure est authentifiée conformément aux règles de sécurité du système.

Une mesure qui échoue à un contrôle n’est pas publiée comme `MesureValidée.v1`.

Elle est rejetée et journalisée afin de permettre une analyse ultérieure.

---

# 7. Déduplication

## Clé de déduplication

La clé métier de déduplication est :

```text
hive_id + timestamp
```

Exemple :

```text
SN-CASA-014 + 2027-03-14T08:15:00Z
```

Une même mesure reçue plusieurs fois après une resynchronisation de la passerelle ne doit donc être publiée qu’une seule fois.

## Rejeu avec le même `eventId`

Si un événement possède un `eventId` déjà traité, il est considéré comme un rejeu.

Le système :

- ne republie pas l’événement ;
- ne crée pas de nouvelle mesure ;
- journalise le rejeu.

## Même clé mais contenu différent

Si deux trames possèdent le même :

```text
hive_id + timestamp
```

mais des valeurs différentes, le système considère la situation comme une anomalie de cohérence.

La seconde trame n’est pas automatiquement acceptée.

Elle est rejetée ou placée en quarantaine et journalisée pour investigation.

---

# 8. Traitement des valeurs hors plage

Une trame contenant au moins une valeur hors de sa plage physique valide est rejetée.

Exemple :

```text
humidity_pct = 145
```

La trame ne doit pas produire de `MesureValidée.v1`.

Le système doit :

1. rejeter la trame ;
2. journaliser la raison du rejet ;
3. conserver les informations nécessaires à l'analyse ;
4. déclencher une alerte d'intégrité si les rejets deviennent répétitifs pour une même ruche ou passerelle.

Cette règle répond notamment au cas d'utilisation **UC-CY02 — Détection d'une falsification ou d'un rejeu de données capteur**.

---

# 9. Fréquence des mesures

Pour le contrat Data, la fréquence retenue est celle indiquée explicitement dans l'énoncé du TP :

| Situation | Fréquence |
|---|---|
| Fonctionnement normal | 1 mesure toutes les 15 minutes |
| Surveillance renforcée | 1 mesure toutes les 5 minutes |

En surveillance renforcée, la fréquence augmente temporairement afin de disposer de données plus rapprochées lorsqu'une anomalie ou un risque nécessite une observation plus fine.

### Activité acoustique

Le cahier des charges précise que le signal acoustique brut n'est jamais transmis.

Le traitement acoustique est effectué localement sur la passerelle :

- fonctionnement normal : 1 échantillon de 10 secondes toutes les 30 minutes ;
- surveillance renforcée : 1 échantillon toutes les 10 minutes ;
- seules les features compactes sont transmises ;
- l'audio brut n'est jamais envoyé.

---

# 10. Mode dégradé et retard maximal

Les sites peuvent fonctionner avec une connectivité intermittente.

Lorsqu'une passerelle ne peut plus transmettre les données :

1. les mesures sont conservées localement ;
2. la passerelle continue la collecte ;
3. les données sont transmises lorsque la connexion est rétablie ;
4. les timestamps d'origine sont conservés ;
5. les mesures déjà traitées sont dédupliquées lors de la resynchronisation.

### Retard maximal accepté

Pour `MesureValidée.v1`, on retient **24 heures** comme limite opérationnelle proposée.

Une mesure reçue avec un retard inférieur ou égal à 24 h peut être intégrée au stockage et aux traitements historiques.

Cependant, elle ne doit pas être considérée comme une mesure temps réel pour déclencher une nouvelle alerte.

Une mesure reçue au-delà de 24 h est considérée comme trop ancienne pour le traitement opérationnel temps réel et doit être placée en quarantaine ou rejetée selon la politique retenue.

> **Décision à confirmer avec BeeAfrica :** le CDC décrit le fonctionnement en différé et la nécessité de ne perdre aucune donnée, mais ne fixe pas explicitement une valeur de 24 h. Cette valeur est donc une proposition d'architecture.

---

# 11. Gestion des alertes avec les mesures différées

Une mesure reçue en retard conserve son `timestamp` d'origine.

Exemple :

```text
Mesure :
timestamp  = 08:15
receivedAt = 14:30
```

Le contexte Santé ne doit pas interpréter cette mesure comme une nouvelle mesure à 14:30.

Il doit utiliser :

```text
timestamp = 08:15
```

pour les analyses temporelles.

Cela permet de distinguer :

- une anomalie réellement apparue à 08:15 ;
- une donnée arrivée tardivement à 14:30.

La politique exacte de déclenchement ou de rattrapage des alertes sur données tardives devra être précisée dans une décision d'architecture ultérieure.

---

# 12. Versionnement

La version actuelle du contrat est :

```text
MesureValidée.v1
```

## Évolution compatible

Une évolution compatible peut ajouter un champ optionnel sans modifier la signification des champs existants.

Exemple :

```json
{
  "new_optional_field": "..."
}
```

Les consommateurs existants doivent continuer à fonctionner sans utiliser ce champ.

## Évolution incompatible

Une modification incompatible doit produire une nouvelle version majeure.

Exemples :

- suppression d'un champ obligatoire ;
- changement du type d'un champ ;
- changement de la signification d'un champ ;
- changement incompatible de l'unité.

Dans ce cas :

```text
MesureValidée.v2
```

est publié.

Les versions doivent pouvoir être distinguées par le champ :

```json
"version": 2
```

Un consommateur qui ne supporte pas la version reçue ne doit pas interpréter silencieusement le message avec une ancienne version du contrat.

---

# 13. Résumé des règles du contrat

| Règle | Décision |
|---|---|
| Propriétaire | Collecte et qualité des données |
| Événement | `MesureValidée` |
| Version | `v1` |
| Déduplication | `hive_id + timestamp` |
| Rejeu même `eventId` | Ignoré + journalisé |
| Même clé avec contenu différent | Rejet/quarantaine + journalisation |
| Trame hors plage | Rejet + journalisation |
| Timestamp futur | Maximum `maintenant + 5 min` |
| Timestamp | ISO 8601 UTC |
| Fréquence normale | 1 / 15 min |
| Surveillance renforcée | 1 / 5 min |
| Mode dégradé | Cache local puis synchronisation |
| Retard maximal proposé | 24 h |
| Audio brut | Jamais transmis |
| Versionnement | `MesureValidée.v1`, puis nouvelle version en cas de rupture |
| Données tardives | Timestamp original conservé |

---

# 14. Lien avec la Context Map

La relation entre les contextes doit être représentée sur la context map par une flèche de type **Published Language** :

```text
Collecte et qualité des données
        |
        | PL : MesureValidée.v1
        v
Santé des colonies et alertes
```

Le même événement peut être consommé par le contexte de **Pilotage et reporting** ainsi que par les traitements Data nécessaires à la prédiction.

---

# 15. Décisions restant à valider

Les points suivants doivent être confirmés avant la version finale :

- validation métier des plages physiques des capteurs ;
- valeur définitive du retard maximal accepté ;
- comportement exact des alertes sur données reçues tardivement ;
- politique de quarantaine des trames suspectes ;
- stratégie de compatibilité entre versions ;
- comportement en cas de conflit entre deux mesures ayant le même `hive_id + timestamp`.

Ces décisions pourront alimenter les points chauds et les ADR de la séance suivante.