# ADR-004 · Stocker les mesures temporelles dans PostgreSQL partitionné

- **Statut :** proposée
- **Date :** 2026-10-30
- **Auteurs :** Jovani et Patrick
- **Spécialité :** Data Science
- **Élément du C4 :** conteneurs « Base opérationnelle » et « Entrepôt analytique » ; flux Plateforme de données → Base opérationnelle.

## Contexte

QueenBee doit historiser les mesures de 400 ruches réparties sur 8 sites. La section 6.4 du cahier des charges estime environ **38 400 mesures quotidiennes** de poids, température et humidité, auxquelles s'ajoutent environ **19 200 estimations acoustiques quotidiennes**. Le volume estimé est d'environ 10 Mo/jour avec métadonnées, soit environ 300 Mo/mois. La charge moyenne est donc modérée ; l'enjeu majeur reste la fiabilité de la collecte, le fonctionnement déconnecté, la déduplication et la qualité des données.

Le cahier des charges impose **PostgreSQL avec PostGIS** pour les données géographiques et demande le support des séries temporelles (section 7.2). Le système doit conserver l'historique complet, permettre des requêtes analytiques et respecter une cible de requêtes SQL analytiques inférieure à 200 ms dans 90 % des cas (section 8.1). Les décisions TP5 ADR-001 et ADR-002 imposent également une ingestion hybride et la distinction entre `occurredAt` et `receivedAt`.

La décision porte sur la manière de stocker les séries temporelles dans la couche relationnelle. Elle ne remplace pas l'entrepôt en étoile, qui reste isolé des transactions opérationnelles.

## Options étudiées

### Option 1 — PostgreSQL avec partitionnement déclaratif (retenue)

- **Avantages :** respecte directement la technologie imposée ; conserve PostGIS et les jointures relationnelles ; pas de nouvelle extension obligatoire ; partitionnement par période et index adaptés ; compétences et exploitation unifiées.
- **Inconvénients :** maintenance des partitions à prévoir ; rétention, agrégats continus et compression moins automatisés qu'avec une extension spécialisée ; réglage des index et des requêtes nécessaire.

### Option 2 — TimescaleDB (extension de PostgreSQL)

- **Avantages :** hypertables, partitionnement temporel automatisé, compression et agrégats continus ; SQL et écosystème PostgreSQL conservés ; intéressant si la volumétrie ou les requêtes temporelles augmentent fortement.
- **Inconvénients :** extension supplémentaire à installer, versionner et superviser sur les environnements ; compatibilité et conditions de déploiement à vérifier ; complexité supplémentaire peu justifiée par le volume actuel.

### Option 3 — InfluxDB (base spécialisée séries temporelles)

- **Avantages :** optimisée pour l'écriture et la lecture de séries temporelles ; politiques de rétention et agrégations temporelles natives.
- **Inconvénients :** ajoute une technologie et une compétence d'exploitation ; crée une duplication ou une synchronisation avec PostgreSQL/PostGIS pour les jointures métier et géographiques ; augmente la complexité de cohérence, sauvegarde et sécurité.

## Décision

Nous retenons **PostgreSQL avec partitionnement déclaratif des mesures par période**, tout en conservant PostgreSQL/PostGIS comme socle relationnel imposé. Les tables de mesures seront partitionnées mensuellement au départ, avec index sur `(hive_id, occurred_at)` et contrainte ou mécanisme de déduplication sur `(hive_id, timestamp)` conformément au contrat `MesureValidée.v1`. Les requêtes analytiques lourdes seront dirigées vers l'entrepôt en étoile plutôt que vers la base transactionnelle.

Le choix est cohérent avec le volume actuellement estimé et obtient le meilleur score pondéré dans `docs/evaluation/matrice.md`. Le partitionnement mensuel est une proposition initiale à confirmer par un test de charge ; il ne s'agit pas d'une exigence explicite du CDC.

## Conséquences

### Positives

- Respect de la contrainte PostgreSQL + PostGIS sans introduire un moteur de stockage supplémentaire.
- Jointures simples entre mesures, ruches, sites et positions géographiques.
- Séparation des charges transactionnelles et analytiques grâce à l'entrepôt.
- Exploitation, sauvegarde et contrôle d'accès plus simples qu'avec deux moteurs opérationnels.

### Négatives

- Création et suppression des partitions à automatiser et surveiller.
- Les agrégations temporelles et la compression demanderont davantage de développement qu'avec TimescaleDB.
- Une croissance rapide de la volumétrie pourrait nécessiter de revoir le partitionnement ou d'ajouter une extension.

### À surveiller

- Latence p90 des requêtes analytiques et p95 des écritures.
- Taille des partitions, durée de maintenance et taux de croissance des tables.
- Taux de doublons/rejets et délai entre `occurredAt` et `receivedAt`.

## Révision

Rouvrir cette ADR si, pendant deux mois consécutifs, le volume dépasse **1 million de mesures/jour**, si les requêtes temporelles p90 dépassent **200 ms** malgré l'optimisation des index/partitions, ou si l'exploitation des partitions devient une charge récurrente significative. Dans ce cas, réévaluer TimescaleDB en priorité avec un benchmark sur les requêtes réelles.
