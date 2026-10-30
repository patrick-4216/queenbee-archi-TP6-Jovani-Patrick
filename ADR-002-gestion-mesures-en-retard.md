# ADR-002: Gestion des mesures reçues en retard

## Statut

Acceptée

## Contexte

QueenBee collecte des mesures provenant des ruches et des passerelles LoRaWAN. La connectivité des sites pouvant être intermittente, les données peuvent être mises en cache localement puis synchronisées ultérieurement avec le système central.

Le cahier des charges indique que le fonctionnement en mode déconnecté avec synchronisation différée doit être supporté. Il précise également que la synchronisation après reconnexion doit permettre de transmettre jusqu’à une journée de données en moins de 2 minutes.

Le contrat de l’événement `MesureValidée` distingue deux dates :

- `occurredAt` : date à laquelle la mesure a été produite ;
- `receivedAt` : date à laquelle la mesure a été reçue par le système central.

Le sujet précise qu’en mode dégradé, `receivedAt` peut être plusieurs heures après `occurredAt`. Il faut donc déterminer quelle date doit être utilisée pour l'analyse des mesures et le déclenchement des alertes.

La volumétrie prévue est d'environ **38 400 mesures par jour** pour le poids, la température et l'humidité. Le cahier des charges précise que l'enjeu principal n'est pas le stockage mais la fiabilité de la collecte en connectivité intermittente, avec cache local, synchronisation différée et déduplication.

## Décision

Nous conservons les deux informations temporelles et nous utilisons **`occurredAt` comme référence temporelle métier de la mesure**.

`receivedAt` est conservé uniquement pour représenter le moment de réception au niveau central et permettre la traçabilité du retard de transmission.

Une mesure reçue en retard est donc traitée avec sa date réelle de mesure et non comme une nouvelle mesure temps réel.

### Règles retenues

1. `occurredAt` correspond à la date de production de la mesure.
2. `receivedAt` correspond à la date de réception par le système central.
3. Les traitements métier et les séries temporelles utilisent `occurredAt`.
4. `receivedAt` est utilisé pour mesurer le délai de transmission et superviser la synchronisation.
5. Une mesure reçue tardivement ne doit pas être considérée comme une nouvelle mesure au moment de sa réception.
6. La clé de déduplication reste `hive_id + timestamp`.
7. Une mesure déjà reçue ne doit pas être recréée lors d'une synchronisation ultérieure.
8. Les mesures reçues après une période de coupure doivent être intégrées à l'historique avec leur date d'origine.
9. Les alertes basées sur une mesure retardée doivent être distinguées d'une alerte temps réel : la plateforme ne doit pas interpréter une ancienne mesure comme une situation observée à l'instant présent.
10. Le retard de réception doit rester observable afin de détecter une dégradation de la connectivité ou une saturation de la file de synchronisation.

## Gestion du retard maximal

Le TP demande explicitement de fixer un retard maximal accepté pour une mesure.

Le cahier des charges ne fournit cependant pas de valeur précise pour cette durée.

**Choix proposé pour le projet : 24 heures.**

Une mesure dont `occurredAt` est antérieur de plus de 24 heures à sa réception est placée en quarantaine ou rejetée selon la règle d'exploitation retenue.

Cette valeur de 24 heures est donc une **décision d'architecture proposée par l'équipe**, et non une valeur explicitement imposée par le CDC.

Le RPO du système étant inférieur à 24 heures, cette valeur constitue un choix cohérent pour le projet, mais elle devra être validée avec les responsables métier.

## Conséquences sur les alertes

Une mesure reçue en retard peut contenir une valeur anormale alors que la situation réelle a déjà évolué.

Par conséquent :

- les calculs historiques utilisent `occurredAt` ;
- les traitements peuvent recalculer les indicateurs historiques concernés ;
- une alerte temps réel ne doit pas être déclenchée uniquement parce qu'une ancienne mesure vient d'être reçue ;
- le délai entre `occurredAt` et `receivedAt` doit être disponible pour permettre au contexte Santé des colonies et alertes de prendre une décision adaptée.

Exemple :

```text
occurredAt = 08:15
receivedAt = 14:41

La mesure correspond à l'état de la ruche à 08:15.
Elle ne représente pas l'état de la ruche à 14:41.
```

## Options étudiées

### Option 1 — Utiliser uniquement `receivedAt`

La mesure est considérée comme actuelle au moment où elle arrive au système central.

**Avantages :**
- traitement simple ;
- logique d'ingestion facile à comprendre.

**Inconvénients :**
- perte de la chronologie réelle des mesures ;
- risque de fausses alertes ;
- historique temporel incorrect ;
- incompatible avec le fonctionnement déconnecté.

### Option 2 — Utiliser uniquement `occurredAt`

Toutes les analyses sont basées sur la date de production de la mesure.

**Avantages :**
- chronologie métier correcte ;
- historique cohérent ;
- adapté aux séries temporelles.

**Inconvénients :**
- perte de l'information sur le délai de transmission ;
- difficulté à superviser les problèmes de synchronisation.

### Option 3 — Conserver `occurredAt` et `receivedAt`

Les deux dates sont conservées avec des rôles différents.

**Avantages :**
- historique métier fiable ;
- traçabilité du délai de transmission ;
- meilleure supervision ;
- compatible avec le mode dégradé et la synchronisation différée.

**Inconvénient :**
- nécessite de bien distinguer les deux notions dans les traitements.

## Décision retenue

**Option 3 : conserver `occurredAt` et `receivedAt`.**

`occurredAt` est la référence temporelle métier.

`receivedAt` est la référence temporelle technique de réception.

Cette décision permet de conserver l'historique réel des mesures tout en surveillant les retards de synchronisation.

## Conséquences

### Positives

- Conservation de la chronologie réelle des mesures.
- Compatibilité avec le mode dégradé.
- Détection des problèmes de synchronisation.
- Réduction du risque de fausses alertes.
- Conservation d'une trace du délai de transmission.

### Négatives

- Les traitements doivent gérer deux dates.
- Le moteur d'alertes doit distinguer une mesure récente d'une mesure ancienne reçue tardivement.
- La gestion des mesures hors fenêtre nécessite une règle de rejet ou de quarantaine.

## Lien avec le contrat `MesureValidée`

Le contrat de données conserve les champs :

```json
{
  "occurredAt": "2027-03-14T08:15:00Z",
  "receivedAt": "2027-03-14T08:41:12Z"
}
```

`occurredAt` correspond à la date de la mesure tandis que `receivedAt` correspond à sa réception au central.

L'événement reste publié sous la forme :

```text
MesureValidée.v1
```

Le contexte **Collecte et qualité des données** reste responsable de la validation et de la publication de l'événement.

## Lien avec le Context Map

La mesure validée est publiée par :

**Collecte et qualité des données**

et consommée notamment par :

**Santé des colonies et alertes**

via le Published Language :

```text
PL : MesureValidée.v1
```

La gestion du retard est donc appliquée avant et pendant la consommation de cet événement.

## Points à vérifier

- Valider avec le métier si le seuil de 24 h est approprié.
- Vérifier le comportement exact du moteur d'alertes lorsqu'une mesure ancienne arrive.
- Tester une coupure réseau puis une synchronisation différée.
- Vérifier la déduplication lors de la retransmission d'une journée de données.
- Vérifier que les mesures restent ordonnées selon `occurredAt` et non selon `receivedAt`.

## Référence

Cette ADR répond à la question du TP concernant l'utilisation de `occurredAt` et `receivedAt` lorsque les mesures sont reçues plusieurs heures après leur production en mode dégradé.