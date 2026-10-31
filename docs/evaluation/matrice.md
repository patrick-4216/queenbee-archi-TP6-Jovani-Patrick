# Évaluation — ADR-004 : stockage des séries temporelles

## Scénarios de qualité

Les poids ont été fixés avant la notation. Les critères reflètent les contraintes explicites du CDC et le contexte d'exploitation de BeeAfrica.

- **S1 — Compatibilité et intégration :** le système doit conserver PostgreSQL + PostGIS, les jointures avec les ruches/sites et la cohérence relationnelle → solution intégrable sans dupliquer le référentiel ; **poids : 40 %**.
- **S2 — Performance temporelle :** avec l'historique des mesures et les agrégations multi-sites, les requêtes analytiques doivent viser moins de 200 ms au p90 (CDC §8.1) → possibilité d'atteindre la cible après indexation/partitionnement ; **poids : 35 %**.
- **S3 — Simplicité d'exploitation :** l'équipe pédagogique/association doit sauvegarder, restaurer, superviser et déployer la solution sur une infrastructure limitée → limiter les moteurs, extensions et opérations supplémentaires ; **poids : 25 %**.

## Matrice (notes de 1 à 5)

| Scénario (poids) | PostgreSQL partitionné | TimescaleDB | InfluxDB |
|---|---:|---:|---:|
| S1 — Compatibilité (40 %) | 5 | 4 | 2 |
| S2 — Performance (35 %) | 4 | 5 | 5 |
| S3 — Exploitation (25 %) | 4 | 3 | 2 |
| **Score pondéré /5** | **4,35** | **4,10** | **3,05** |

Calcul : score = somme(note × poids). Exemple PostgreSQL = 5 × 0,40 + 4 × 0,35 + 4 × 0,25 = **4,35/5**.

## Justification des notes

| Option | S1 — Compatibilité | S2 — Performance | S3 — Exploitation |
|---|---|---|---|
| PostgreSQL partitionné | **5** — respecte la base imposée et conserve PostGIS et les relations métier dans le même moteur. | **4** — partitionnement et index devraient répondre au volume modéré, sous réserve de benchmark. | **4** — un seul moteur principal, mais les partitions nécessitent une maintenance automatisée. |
| TimescaleDB | **4** — reste fondé sur PostgreSQL et conserve l'intégration relationnelle, mais ajoute une extension à gérer. | **5** — fonctions temporelles, compression et agrégats continus adaptés aux séries temporelles. | **3** — exploitation supplémentaire de l'extension et vérification de compatibilité des environnements. |
| InfluxDB | **2** — nécessite de synchroniser ou joindre les données avec PostgreSQL/PostGIS, ce qui fragmente le modèle. | **5** — moteur spécialisé efficace pour les séries temporelles et leurs agrégations. | **2** — ajoute un moteur, des sauvegardes, une supervision et une cohérence inter-bases. |

## Analyse de sensibilité

Le gagnant change si la performance temporelle devient nettement prioritaire. Avec **S1 = 25 %**, **S2 = 55 %** et **S3 = 20 %**, les scores deviennent : PostgreSQL partitionné = 4,25/5 ; TimescaleDB = 4,35/5 ; InfluxDB = 3,65/5. TimescaleDB devient alors le gagnant.

Ce changement de poids est **possible mais pas le plus plausible aujourd'hui** : le CDC insiste sur la fiabilité de collecte en connectivité intermittente et impose PostgreSQL/PostGIS ; la volumétrie estimée reste modeste (environ 10 Mo/jour avec métadonnées). Il deviendrait plausible si le nombre de ruches, la fréquence des mesures ou les exigences de requêtes temporelles augmentaient fortement.

## Conclusion → ADR-004

Nous retenons PostgreSQL partitionné (4,35/5). Il répond au CDC tout en limitant la complexité de déploiement et d'exploitation. TimescaleDB est l'alternative à réexaminer en premier si les performances temporelles deviennent le critère dominant ou si les seuils de révision de l'ADR sont atteints.
