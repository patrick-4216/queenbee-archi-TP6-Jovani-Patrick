# ADR-003: Versionnement du contrat `MesureValidée`

- **Statut :** Proposition à valider
- **Date :** 23 octobre 2026
- **Contexte propriétaire :** Collecte et qualité des données
- **Consommateurs concernés :** Santé des colonies et alertes ; Pilotage et reporting

## 1. Contexte

Le contrat `MesureValidée` permet au contexte de collecte de transmettre des mesures validées aux contextes consommateurs. Il doit pouvoir évoluer sans provoquer d'erreurs chez les applications qui utilisent déjà une version antérieure du contrat.

Le CDC QueenBee décrit des capteurs hétérogènes, une connectivité parfois intermittente et une synchronisation différée. Plusieurs versions du contrat pourraient donc coexister pendant une période de migration.

Le CDC ne définit pas explicitement une stratégie complète de versionnement. La décision proposée ci-dessous doit donc être validée par les équipes concernées.

## 2. Décision proposée

Le contrat `MesureValidée` sera versionné explicitement au moyen d'un champ `version` dans l'enveloppe de l'événement.

- La première version du contrat sera `MesureValidée.v1`, identifiée par `version: 1`.
- Une évolution compatible, comme l'ajout d'un champ facultatif, pourra conserver la même version si les consommateurs existants continuent de fonctionner correctement.
- Une évolution incompatible, comme la suppression ou le renommage d'un champ, la modification de son type ou le changement de sa signification, nécessitera une nouvelle version, par exemple `MesureValidée.v2`.
- Le contexte producteur devra documenter le schéma et les règles de validation de chaque version.
- Les consommateurs devront vérifier les versions qu'ils acceptent.
- Lors d'une migration, l'ancienne version pourra rester disponible temporairement afin de laisser aux consommateurs le temps de s'adapter. La durée de coexistence devra être définie.
- Une mesure reçue en retard conservera sa version d'origine. Elle ne sera pas automatiquement convertie vers une nouvelle version sans règle de migration explicite.

## 3. Options étudiées

### Option A — Ne pas versionner le contrat

**Avantages :**
- Mise en place simple au départ.
- Peu de gestion supplémentaire.

**Inconvénients :**
- Les changements peuvent casser les consommateurs existants.
- Les incompatibilités sont plus difficiles à détecter.
- La gestion des messages retardés devient plus délicate.

**Conclusion :** option non retenue dans cette proposition.

### Option B — Ajouter un numéro de version au contrat

**Avantages :**
- Version clairement identifiable.
- Compatibilité plus facile à vérifier.
- Migration progressive des consommateurs.
- Meilleure traçabilité des messages retardés.

**Inconvénients :**
- Nécessité de documenter et de tester chaque version.
- Maintien temporaire de plusieurs versions possible.

**Conclusion :** option recommandée.

### Option C — Créer un nouvel événement à chaque modification

**Avantages :**
- Les contrats sont explicitement séparés.

**Inconvénients :**
- Multiplication des noms d'événements.
- Complexité supplémentaire pour les producteurs et les consommateurs.

**Conclusion :** cette option est à réserver aux changements qui représentent un événement métier réellement différent, plutôt qu'à chaque évolution technique du schéma.

## 4. Conséquences

### Conséquences positives

- Les modifications incompatibles sont identifiées explicitement.
- Les consommateurs peuvent migrer progressivement.
- Les messages conservés hors ligne restent associés à leur version d'origine.
- Les tests de contrat peuvent vérifier la compatibilité avant le déploiement.

### Coûts et limites

- Chaque version doit être documentée et testée.
- Plusieurs validateurs peuvent devoir coexister pendant une migration.
- La durée de prise en charge des anciennes versions reste à définir.
- La procédure d'autorisation du retrait d'une version doit être précisée.

## 5. Exemple d'enveloppe

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
    "weight_kg": 34.2
  }
}
```

Cet exemple est illustratif et partiel. Le contrat complet est défini dans `docs/specialite/data-contrat-mesure-validee.md`.

## 6. Points restant à confirmer

- Quelle durée de coexistence prévoir entre deux versions ?
- Qui autorise le retrait d'une ancienne version ?
- Tous les consommateurs peuvent-ils ignorer les champs inconnus ?
- Quel mécanisme de publication, de validation et de test des schémas sera utilisé ?
- Comment les consommateurs seront-ils informés d'une nouvelle version ?

## 7. Liens avec les autres livrables

- `docs/specialite/data-contrat-mesure-validee.md`
- `docs/context-map.md`
- `docs/points-chauds.md`
- `adr/ADR-001-ingestion-mesures.md`
- `adr/ADR-002-gestion-mesures-en-retard.md`

**Remarque :** les noms et chemins des ADR liés doivent être vérifiés avec les fichiers réellement présents dans le dépôt. Le statut de cet ADR reste « Proposition à valider » jusqu'à validation par l'équipe.
