# Séquence Data — De la mesure reçue à l'alerte (UC-T02 / UC-A02)

Le scénario décrit le chemin nominal d'une trame jusqu'à la décision métier. `occurredAt` reste l'horodatage métier ; `receivedAt` permet de mesurer le retard de synchronisation (ADR-002). La clé de déduplication est `hive_id + timestamp`.

```mermaid
sequenceDiagram
    actor Capteur as Capteur IoT
    participant Passerelle as Passerelle de site
    participant Broker as Broker d'événements
    participant Data as Plateforme de données
    participant API as API centrale
    participant Mobile as Application mobile terrain

    Capteur->>Passerelle: Émet une trame LoRaWAN (mesure, hive_id, timestamp)
    Passerelle->>Broker: Synchronise la trame mise en cache (MQTT/TLS)
    Broker-->>Data: Transmet la trame à traiter
    Data->>Data: Vérifie certificat, schéma, plage physique et horodatage
    Data->>Data: Déduplique avec hive_id + timestamp
    alt Trame valide et non déjà reçue
        Data->>Data: Enregistre occurredAt et receivedAt
        Data->>Broker: Publie MesureValidée.v1
        Broker-->>API: Transmet la mesure validée
        API->>API: Met à jour le score de santé et évalue le seuil de risque
        alt Confiance de prédiction supérieure ou égale au seuil configuré
            API->>API: Crée une alerte métier avec niveau de confiance et recommandation
            API-->>Mobile: Rend l'alerte disponible / déclenche la notification
        else Confiance inférieure au seuil
            API->>API: Conserve le score sans créer d'alerte prioritaire
        end
    else Trame invalide, signature incorrecte ou doublon
        Data->>Data: Rejette la trame et journalise le motif
        Data-->>Broker: Accuse réception du rejet technique
    end
```

## Règles importantes

- Une trame invalide ou rejouée ne produit jamais `MesureValidée.v1`.
- Une mesure retardée est historisée selon `occurredAt` ; elle ne déclenche pas automatiquement une fausse alerte temps réel.
- Le seuil de confiance est configurable par type de ruche/site : sa valeur exacte reste à valider avec BeeAfrica.
- Le diagramme représente une séquence logique. L'entraînement des modèles peut être batch ; l'inférence est déclenchée par les mesures ou par une fenêtre de calcul.
