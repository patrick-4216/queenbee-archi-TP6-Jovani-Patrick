# C4 — Niveau 2 : conteneurs QueenBee

Le choix est un **monolithe modulaire pour les fonctions métier centrales**, complété par des conteneurs séparés lorsque le lieu d'exécution, le rythme de charge, le stockage ou le public le justifie. Les huit bounded contexts ne deviennent donc pas huit microservices.

| Conteneur | Technologie | Pourquoi est-il séparé ? | Bounded contexts hébergés / responsabilité | Données stockées |
|---|---|---|---|---|
| Application mobile terrain | Application mobile offline-first | S'exécute sur les téléphones des quelque 300 apicultrices et doit continuer à fonctionner sans réseau. Son cycle de vie et ses contraintes sont différents du serveur. | Interface des contextes Intervention terrain, Production, Référentiel ruchers et Santé des colonies. | Cache local chiffré : ruches affectées, inspections, récoltes et alertes à synchroniser. |
| API centrale | Python / FastAPI | Point d'entrée transactionnel pour les utilisateurs ; règles métier, authentification et API ont un cycle de déploiement distinct des traitements analytiques. Les modules restent dans un même processus pour limiter la complexité d'exploitation. | Référentiel ruchers ; Identité et accès ; Santé des colonies ; Intervention terrain ; Production ; gestion métier de Collecte et supervision ; accès aux prédictions ; Impact et reporting. | Pas de base propre ; accès à la base opérationnelle par interfaces/repositories. |
| Passerelle de site | Linux edge, LoRaWAN, MQTT, cache local | Une instance par site (8 sites), proche des 400 ruches. Doit continuer à collecter et mettre en cache pendant une coupure du lien central. | Adaptateur technique de Collecte et supervision ; prétraitement acoustique local. | File/cache local des trames non synchronisées, configuration et état de la passerelle. |
| Broker d'événements | MQTT / RabbitMQ | Découple les producteurs des consommateurs, absorbe les pointes et permet la reprise après interruption sans couplage synchrone entre ingestion et calcul Data. | Transport des événements publiés par Collecte et supervision vers Prévision, Santé des colonies et Impact et reporting. | Files persistantes, messages en attente et métadonnées de livraison. |
| Plateforme de données | Python, Pandas, NumPy, dbt, Airflow, Scikit-learn, MLflow | Charge de calcul différente de l'API : ETL, calcul de caractéristiques, entraînement et inférence peuvent être batch ou déclenchés en flux. Les dépendances Python/ML et le cycle de déploiement sont spécifiques. | Prévision ; transformations analytiques d'Impact et reporting ; validation/qualité de Collecte et supervision. | Staging temporaire, jeux de caractéristiques, artefacts et versions de modèles (stockage objet/MLflow). |
| Base opérationnelle | PostgreSQL + PostGIS | Stockage transactionnel séparé du calcul applicatif ; garantit l'intégrité relationnelle et les requêtes géospatiales sur les ruches et sites. | Données de Référentiel ruchers, Identité et accès, Intervention terrain, Production, Santé des colonies et métadonnées de Collecte. | Comptes, rôles, sites, ruches, positions, inspections, récoltes, alertes, mesures validées et audit. |
| Entrepôt analytique | PostgreSQL, modèle en étoile | Optimisé pour l'historisation et les agrégations multi-sites ; isole les requêtes analytiques des transactions de l'application. | Impact et reporting ; données historiques consommées par Prévision. | Tables de faits (mesures, récoltes, prédictions) et dimensions (temps, ruche, site, coopérative, capteur). |
| Portail analytics | Apache Superset / Grafana | Public et charge de lecture différents de l'API transactionnelle ; permet des tableaux de bord et cartes sans exposer directement la base opérationnelle. | Présentation d'Impact et reporting, Santé des colonies et Prévision. | Pas de données métier maîtresses ; configuration des tableaux de bord et cache de lecture. |
| Orchestrateur de notifications | n8n | Les intégrations push/email et leurs reprises ont un cycle de vie indépendant ; évite de coupler le cœur métier à un fournisseur externe. | Orchestration transverse des notifications issues de Santé des colonies, Intervention terrain et Impact et reporting. | Historique d'exécution et état des workflows, sans données métier sensibles inutiles. |

## Placement des huit bounded contexts du TP 5

| Bounded context | Placement retenu |
|---|---|
| Référentiel ruchers | Module de l'API centrale ; données maîtresses dans PostgreSQL/PostGIS. |
| Identité et accès | Module de l'API centrale ; comptes et rôles dans PostgreSQL. Une fédération OIDC externe reste possible. |
| Collecte et supervision | Adaptateur edge dans la passerelle, validation dans la plateforme Data et orchestration via le broker ; le contexte reste un seul contexte métier logique. |
| Prévision | Module de calcul de la plateforme Data ; modèles versionnés dans MLflow. |
| Santé des colonies | Module métier de l'API centrale ; consomme les scores/prédictions et gère les alertes métier. |
| Intervention terrain | Module de l'API centrale et application mobile offline-first. |
| Production | Module de l'API centrale et application mobile ; récoltes stockées dans PostgreSQL. |
| Impact et reporting | Module de reporting dans la plateforme Data, données dans l'entrepôt, restitution via le portail analytics. |

## Flux principaux

1. Capteurs → réseau LoRaWAN → passerelle : transmission radio des mesures ; la passerelle conserve les données si le lien central est indisponible.
2. Passerelle → broker → plateforme Data : synchronisation MQTT/AMQP sur VPN/TLS ; validation, déduplication puis publication de `MesureValidée.v1`.
3. Plateforme Data → PostgreSQL/PostGIS : lecture des référentiels et positions ; écriture des mesures et métadonnées validées.
4. Plateforme Data → entrepôt : ETL/dbt en SQL ; alimentation des faits et dimensions.
5. Plateforme Data → broker → API centrale : publication des prédictions ; le module Santé des colonies décide de créer ou non une alerte métier.
6. Application mobile → API centrale : synchronisation HTTPS/JSON avec JWT et gestion des conflits.

**Point de cohérence du CDC :** la section 6.4 fixe une mesure poids/température/humidité toutes les 15 minutes, soit environ 38 400 mesures/jour. UC-T02 mentionne 30 minutes. Pour le dimensionnement, nous retenons la valeur détaillée de la section 6.4 et signalons cette divergence à faire valider.
