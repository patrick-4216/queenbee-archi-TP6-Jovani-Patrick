# ADR-001  Ingestion des mesures : traitement par lots ou en flux ?

- **Statut :** Acceptée
- **Date :** 2026-10-23
- **Contexte :** QueenBee: Data
- **Décision :** Ingestion des mesures en flux, avec cache local en mode dégradé
- **Décideurs :** Équipe Data / Architecture

---

## 1. Contexte

QueenBee collecte des mesures provenant des ruches connectées : poids, températures, humidité et activité acoustique.

Les capteurs transmettent leurs données vers une passerelle LoRaWAN. La passerelle peut transmettre les données au système central lorsque la connexion est disponible. En cas de coupure, le système doit pouvoir fonctionner en mode dégradé avec une mise en cache locale puis une synchronisation lors du rétablissement de la connexion.

Le cahier des charges prévoit environ **400 ruches réparties sur 8 sites**. Pour les mesures de poids, température et humidité, la volumétrie estimée est d'environ **38 400 mesures par jour**, soit environ **27 mesures par minute** sur l'ensemble du réseau. Le CDC précise que le volume reste modeste et que l'enjeu principal est la fiabilité de la collecte en connectivité intermittente.

Le TP demande de choisir entre une ingestion par lots et une ingestion en flux, notamment en fonction de la **latence nécessaire aux alertes**, de la **connectivité intermittente** et de cette volumétrie.

Une autre contrainte importante est la distinction entre :

- `occurredAt` : moment où la mesure a été produite ;
- `receivedAt` : moment où la mesure est reçue au système central.

En mode dégradé, ces deux dates peuvent être fortement différentes. Le contrat `MesureValidée.v1` doit donc conserver ces deux informations.

---

## 2. Problème

Nous devons déterminer comment les mesures doivent être intégrées dans le contexte **Collecte et qualité des données** :

1. **Traitement par lots (batch)** : les mesures sont accumulées puis traitées périodiquement.
2. **Traitement en flux (streaming)** : chaque mesure valide est traitée et publiée dès que possible.

Le choix doit permettre de conserver les données en cas de coupure réseau tout en limitant le délai avant qu'une mesure puisse alimenter les indicateurs et les alertes.

---

## 3. Options envisagées

### Option A — Traitement par lots

Les passerelles accumulent les mesures puis les transmettent périodiquement au système central.

Le pipeline traite ensuite un ensemble de mesures en une seule fois.

**Avantages :**

- architecture relativement simple ;
- traitement efficace de gros volumes ;
- possibilité de regrouper les opérations d'écriture en base ;
- adapté aux traitements analytiques et prédictifs.

**Inconvénients :**

- augmentation de la latence entre la mesure et sa disponibilité ;
- les alertes peuvent être retardées jusqu'au prochain traitement ;
- gestion moins naturelle des événements métier individuels ;
- moins adapté à la publication de `MesureValidée.v1` au fur et à mesure de leur validation.

---

### Option B — Traitement en flux

Chaque mesure reçue est traitée individuellement :

```text
Capteur
   ↓
Passerelle LoRaWAN
   ↓
Cache local si nécessaire
   ↓
Synchronisation
   ↓
Pipeline Data
   ↓
Validation
   ↓
MesureValidée.v1
   ↓
Santé des colonies / Reporting
```

Une mesure valide peut ainsi être publiée dès qu'elle est disponible au niveau central.

**Avantages :**

- faible latence entre réception et traitement ;
- meilleur support des alertes ;
- correspond bien au modèle événementiel du projet ;
- permet de publier `MesureValidée.v1` au fil de l'eau ;
- compatible avec le fonctionnement en mode dégradé grâce au cache local.

**Inconvénients :**

- architecture légèrement plus complexe ;
- nécessité de gérer les doublons et les événements rejoués ;
- nécessité de gérer les retards de transmission ;
- nécessité de conserver l'ordre logique à partir du timestamp plutôt que de supposer que l'ordre de réception est toujours l'ordre de mesure.

---

## 4. Critères de décision

| Critère | Batch | Flux |
|---|---|---|
| Latence des alertes | Faible performance | **Très favorable** |
| Connectivité intermittente | Possible avec buffer | **Très favorable avec cache local** |
| Volumétrie de 38 400 mesures/jour | Très favorable | **Favorable** |
| Publication de `MesureValidée.v1` | Moins naturelle | **Très favorable** |
| Gestion des doublons | Simple mais nécessaire | Nécessaire |
| Complexité technique | Plus faible | Plus élevée |
| Traitement analytique/predictif | **Très adapté** | Possible mais non nécessaire |

La volumétrie seule ne justifie donc pas une architecture batch : le CDC estime environ 27 mesures par minute en fonctionnement normal et indique que le problème principal est plutôt la fiabilité de la collecte en connectivité intermittente.

---

## 5. Décision

**Nous choisissons une ingestion en flux pour les mesures IoT.**

Le contexte **Collecte et qualité des données** traite les mesures dès leur disponibilité au système central.

Après validation, une mesure produit l'événement :

```text
MesureValidée.v1
```

Cet événement est ensuite publié vers les consommateurs concernés, notamment :

- **Santé des colonies et alertes** ;
- **Pilotage et reporting**.

La relation correspondante dans la context map est :

```text
Collecte et qualité des données
        │
        │ PL : MesureValidée.v1
        ▼
Santé des colonies et alertes
```

Le choix du flux ne signifie pas que toutes les données doivent être transmises immédiatement depuis les ruches. La passerelle conserve un **cache local en cas de coupure** puis synchronise les mesures lorsque la connexion est rétablie.

Le CDC prévoit explicitement le fonctionnement dégradé avec cache local et synchronisation différée. Il fixe également une cible de synchronisation de **moins de 2 minutes pour un jour de données après reconnexion**.

---

## 6. Gestion du mode dégradé

En cas de perte de connexion :

1. la passerelle continue à recevoir les mesures ;
2. les mesures sont conservées localement ;
3. chaque mesure conserve son `timestamp` d'origine ;
4. lors du rétablissement de la connexion, les mesures sont synchronisées ;
5. le pipeline applique les règles de déduplication et de validation ;
6. seules les mesures valides produisent `MesureValidée.v1`.

Il est donc essentiel de ne pas confondre :

```text
timestamp / occurredAt
        =
date réelle de la mesure
```

avec :

```text
receivedAt
        =
date de réception au système central
```

Une mesure reçue tardivement ne doit pas être considérée comme une nouvelle mesure temps réel simplement parce qu'elle vient d'être reçue.

---

## 7. Gestion des doublons et des rejoués

L'utilisation du flux implique de traiter explicitement les duplications.

La clé de déduplication retenue pour `MesureValidée.v1` est :

```text
hive_id + timestamp
```

Une mesure déjà traitée avec cette clé ne doit pas être publiée une seconde fois.

Les règles détaillées sont définies dans :

```text
docs/specialite/data-contrat-mesure-validee.md
```

Le TP demande explicitement que le contrat précise les règles de déduplication, de rejet et de versionnement.

---

## 8. Pourquoi ne pas choisir le batch pour l'ensemble du système ?

Le traitement par lots reste pertinent pour certains traitements de QueenBee, notamment les traitements analytiques et prédictifs.

Le choix de cette ADR concerne principalement **l'ingestion des mesures et leur publication comme événements métier**.

Il ne signifie donc pas que tous les traitements Data doivent être réalisés en streaming.

L'architecture retenue est ainsi hybride :

```text
                 ┌─────────────────────┐
                 │     Capteurs IoT    │
                 └──────────┬──────────┘
                            ↓
                    Passerelle LoRaWAN
                            ↓
                     Cache local
                    si coupure réseau
                            ↓
                       Pipeline
                            ↓
                       Validation
                            ↓
                  MesureValidée.v1
                     ↙          ↘
                    ↓            ↓
               Santé         Reporting
                    │
                    ↓
                 Alertes


        Traitements analytiques / prédictifs
                         ↓
                    Batch / ETL
```

Cette séparation permet de privilégier la réactivité pour les alertes tout en conservant le batch lorsqu'il est adapté aux traitements analytiques.

---

## 9. Conséquences positives

- Les mesures validées peuvent être publiées sans attendre un lot complet.
- Les alertes peuvent exploiter les nouvelles mesures dès leur disponibilité centrale.
- Le contrat événementiel `MesureValidée.v1` est cohérent avec l'architecture Event Storming.
- Le fonctionnement en mode dégradé est conservé.
- La solution reste adaptée à la volumétrie prévue.
- Les traitements prédictifs peuvent continuer à utiliser des traitements batch lorsque nécessaire.

---

## 10. Conséquences négatives

- L'architecture d'ingestion est plus complexe qu'un simple traitement batch.
- Il faut gérer les doublons et les rejoués.
- Il faut distinguer l'ordre de mesure (`timestamp`) de l'ordre de réception (`receivedAt`).
- Les consommateurs doivent être capables de recevoir des événements éventuellement en retard après une période de coupure.
- Le monitoring du pipeline devient important pour détecter les retards de synchronisation.

---

## 11. Points de vigilance

Le CDC présente deux indications de fréquence qui ne sont pas parfaitement alignées :

- la section de volumétrie indique **1 mesure / 15 min** en fonctionnement normal et **1 mesure / 5 min** en surveillance renforcée ;
- le résumé du cas d'utilisation UC-T02 mentionne **30 min ou immédiatement en cas de dépassement de seuil**.

**Cette ADR ne tranche pas cette fréquence métier.** La fréquence devra être harmonisée dans le dossier final avec le choix retenu pour le contrat de données et le simulateur.

---

## 12. Références

- `TP5_Event_Storming_QueenBee_enonces.pdf`
  - Livrable Data et amorce de l'ADR : traitement par lots ou en flux.
  - Contrat `MesureValidée.v1` et distinction `occurredAt` / `receivedAt`.

- `QUEENBEE_CDC_COMMUN_M1.pdf`
  - Fréquences et volumétrie des mesures.
  - Connectivité intermittente, cache local et synchronisation différée.

---

## 13. Résumé de la décision

> **QueenBee utilise une ingestion en flux pour les mesures IoT validées.**
>
> Les passerelles utilisent un cache local en cas de coupure réseau. Après synchronisation, les mesures sont validées, dédupliquées puis publiées sous la forme de `MesureValidée.v1`.  
> Les traitements analytiques et prédictifs peuvent rester réalisés en batch lorsque cela est plus pertinent.

**Décision finale : FLUX pour l'ingestion, BATCH pour les traitements analytiques/predictifs lorsque nécessaire.**