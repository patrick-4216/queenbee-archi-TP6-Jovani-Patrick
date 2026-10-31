workspace "QueenBee" "Plateforme apicole connectée de BeeAfrica — architecture Data Science" {
    model {
        apicultrice = person "Apicultrice / apiculteur" "Consulte ses ruches, saisit les inspections et déclare les récoltes, y compris hors connexion."
        coordinateur = person "Coordinateur régional" "Suit les ruches de son site, priorise les visites et valide les récoltes."
        gestionnaire = person "Gestionnaire association" "Pilote les huit sites, consulte les indicateurs consolidés et produit les rapports d'impact."
        administrateur = person "Administrateur" "Gère les comptes, les rôles, les permissions et les seuils de fonctionnement."

        queenbee = softwareSystem "QueenBee" "Plateforme IoT de suivi, de prédiction et de pilotage des ruchers BeeAfrica." {
            mobile = container "Application mobile terrain" "Consultation, inspections et récoltes avec stockage local chiffré et synchronisation différée." "Application mobile offline-first"
            api = container "API centrale" "Expose les fonctions métier et applique les règles d'accès ; héberge les modules du monolithe modulaire." "Python / FastAPI — HTTPS/JSON"
            gateway = container "Passerelle de site" "Reçoit les trames LoRaWAN, extrait les caractéristiques acoustiques, met en cache et synchronise en différé." "Edge Linux — LoRaWAN, MQTT, VPN"
            broker = container "Broker d'événements" "Distribue les mesures validées et les événements métier de façon asynchrone." "MQTT / RabbitMQ"
            data = container "Plateforme de données" "Valide, transforme et exploite les données ; entraîne et sert les modèles prédictifs." "Python, Pandas, dbt, Airflow, Scikit-learn" {
                dataStaging = component "Zone de staging" "Reçoit les trames et événements bruts avant validation." "Stockage objet / fichiers Parquet"
                quality = component "Validation et déduplication" "Vérifie schéma, plages physiques, identité du capteur et unicité hive_id + timestamp." "Python / Pandas"
                etl = component "ETL et transformations" "Normalise les mesures, joint les référentiels et prépare les jeux analytiques." "Python / dbt"
                feature = component "Calcul des caractéristiques" "Construit les variables temporelles et géospatiales utiles aux modèles." "Pandas / NumPy / PostGIS"
                prediction = component "Moteur prédictif" "Estime le risque d'essaimage, le score de santé et le rendement de miel." "Scikit-learn"
                registry = component "Registre des modèles" "Versionne les modèles, leurs métriques et leurs dates de mise en production." "MLflow"
                mart = component "Data marts et reporting" "Alimente les faits et dimensions puis expose les indicateurs consolidés." "dbt / SQL"
            }
            operationalDb = container "Base opérationnelle" "Stocke les données métier transactionnelles et les référentiels géographiques." "PostgreSQL + PostGIS" "Database"
            warehouse = container "Entrepôt analytique" "Historise les mesures et récoltes dans un modèle en étoile pour les analyses multi-sites." "PostgreSQL — schéma étoile" "Database"
            analytics = container "Portail analytics" "Présente les tableaux de bord, cartes et rapports d'impact aux gestionnaires autorisés." "Apache Superset / Grafana — HTTPS"
            notification = container "Orchestrateur de notifications" "Déclenche les notifications push et email à partir des alertes et événements." "n8n — Webhooks"


            broker -> dataStaging "Dépose les événements bruts à traiter" "AMQP / JSON"
            dataStaging -> quality "Transmet les données brutes" "Fichiers / Parquet"
            quality -> etl "Publie les mesures validées" "MesureValidée.v1 / Python"
            etl -> feature "Fournit les séries nettoyées" "DataFrame / SQL"
            feature -> prediction "Transmet les variables explicatives" "API Python"
            prediction -> registry "Enregistre et charge les versions" "MLflow API"
            etl -> mart "Alimente les faits et dimensions" "SQL / dbt"
            mart -> warehouse "Écrit les données analytiques" "SQL"
            prediction -> broker "Publie les prédictions et scores" "AMQP / JSON"
            quality -> operationalDb "Enregistre les mesures et rejets" "SQL"
            feature -> operationalDb "Lit les référentiels géographiques" "SQL / PostGIS"
        }

        capteurs = softwareSystem "Capteurs IoT des ruches" "Mesurent poids, température, humidité et signaux acoustiques." "Externe"
        meteo = softwareSystem "Service météorologique" "Fournit les observations et prévisions météo utiles aux modèles." "Externe"
        identite = softwareSystem "Fournisseur d'identité" "Fournit une fédération d'identité si l'authentification externe est activée." "Externe"
        fournisseurNotif = softwareSystem "Fournisseur push / email" "Achemine les notifications vers les appareils et adresses des bénéficiaires." "Externe"
        reseauLora = softwareSystem "Réseau LoRaWAN" "Transporte les trames radio des capteurs vers les passerelles des sites." "Externe"

        apicultrice -> queenbee "Consulte ses ruches et saisit inspections et récoltes" "Application mobile, mode hors ligne"
        coordinateur -> queenbee "Suit les ruches et priorise les visites" "HTTPS"
        gestionnaire -> queenbee "Pilote les sites et génère les rapports d'impact" "HTTPS"
        administrateur -> queenbee "Gère les comptes, rôles et seuils" "HTTPS/MFA"
        apicultrice -> mobile "Consulte les ruches et saisit inspections et récoltes" "Application mobile, mode hors ligne"
        coordinateur -> analytics "Consulte les risques et priorise les visites" "HTTPS"
        gestionnaire -> analytics "Consulte les indicateurs et génère les rapports" "HTTPS"
        administrateur -> api "Administre comptes, rôles et seuils" "HTTPS/JSON, MFA"
        mobile -> api "Synchronise les opérations locales" "HTTPS/JSON, JWT"
        api -> operationalDb "Lit et écrit les données métier" "SQL/TLS"
        api -> broker "Publie les événements métier" "AMQP/TLS"
        gateway -> broker "Synchronise les trames mises en cache" "MQTT sur VPN/TLS"
        meteo -> feature "Fournit les variables météorologiques" "HTTPS/JSON"
        capteurs -> queenbee "Transmettent les mesures périodiques des ruches" "LoRaWAN via passerelles de site"
        meteo -> queenbee "Fournit les observations et prévisions météorologiques" "HTTPS/JSON"
        identite -> queenbee "Fournit une identité fédérée si activée" "OIDC/OAuth2"
        fournisseurNotif -> queenbee "Achemine les notifications push et email" "HTTPS/API"
        reseauLora -> queenbee "Transporte les trames radio vers les sites" "LoRaWAN"
        capteurs -> reseauLora "Émettent les mesures périodiques" "LoRaWAN"
        reseauLora -> gateway "Transporte les trames vers le site" "LoRaWAN"
        broker -> data "Transmet les événements de mesure" "AMQP/TLS, MesureValidée.v1"
        meteo -> data "Fournit les données météorologiques" "HTTPS/JSON"
        data -> warehouse "Alimente l'historique analytique" "SQL/TLS"
        data -> operationalDb "Lit les référentiels et positions" "SQL/TLS"
        analytics -> warehouse "Interroge les indicateurs consolidés" "SQL/TLS"
        api -> notification "Demande l'envoi d'une notification" "Webhook HTTPS"
        notification -> fournisseurNotif "Achemine les alertes et rapports" "HTTPS/API"
        api -> identite "Vérifie l'identité si fédération activée" "OIDC/OAuth2"
    }

    views {
        systemContext queenbee "N1-Contexte" {
            include *
            autolayout tb
        }
        container queenbee "N2-Conteneurs" {
            include *
            autolayout lr
        }
        component data "N3-Plateforme-Data" {
            include *
            autolayout lr
        }
        styles {
            element "Person" { shape Person background #08427b color #ffffff }
            element "Software System" { background #1168bd color #ffffff }
            element "Container" { background #438dd5 color #ffffff }
            element "Component" { background #85bbf0 color #000000 }
            element "Database" { shape Cylinder }
            element "Externe" { background #999999 color #ffffff }
        }
    }
}
