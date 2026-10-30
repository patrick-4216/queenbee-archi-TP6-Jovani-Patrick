# QueenBee — Complément TP 6

Ce complément documente, sécurise et évalue l'architecture issue du TP 5 pour le binôme Data  (Jovani et Patrick).

## Livrables produits

- `docs/c4/workspace.dsl` : C4 N1, N2 et N3 (plateforme Data) en Structurizr DSL.
- `docs/c4/conteneurs.md` : justification des conteneurs et placement des 8 bounded contexts.
- `docs/sequences/mesure-vers-alerte.md` : séquence Mermaid Data, de la mesure à l'alerte, avec alternatives.
- `adr/ADR-004-stockage-series-temporelles.md` : ADR Data Science.
- `docs/securite/stride.md` : zones de confiance, flux numérotés, menaces STRIDE et risques résiduels.
- `docs/evaluation/matrice.md` : scénarios, poids, notes, score pondéré et sensibilité.

## Génération des vues C4

Ouvrir `docs/c4/workspace.dsl` dans https://structurizr.com/dsl, puis exporter les vues :

1. `N1-Contexte` → `docs/c4/n1-contexte.png`
2. `N2-Conteneurs` → `docs/c4/n2-conteneurs.png`
3. `N3-Plateforme-Data` → `docs/c4/n3-plateforme-data.png`

Les images doivent être exportées depuis Structurizr après vérification du rendu DSL. Le fichier DSL est la source de vérité.

## Points à valider avec l'enseignant / le métier

- Le CDC indique 15 minutes en section 6.4 (38 400 mesures/jour) mais UC-T02 mentionne 30 minutes. Le dimensionnement retient la section 6.4.
- Le seuil de confiance des prédictions et les plages physiques des capteurs restent à paramétrer avec BeeAfrica.
- Le partitionnement mensuel PostgreSQL est une proposition initiale à confirmer par benchmark.
- Le recours à un fournisseur OIDC externe est facultatif : l'identité et les accès restent un bounded context QueenBee.
