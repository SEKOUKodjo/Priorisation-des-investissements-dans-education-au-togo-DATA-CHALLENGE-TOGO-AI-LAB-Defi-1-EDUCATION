# SAD Éducation Togo — Système d'Aide à la Décision pour l'Investissement Éducatif

Plateforme décisionnelle **R Shiny** développée pour le **Data Challenge Éducation (Défi 1)** :
identifier, à partir des données ouvertes du Togo (geodata.gouv.tg, opendata.gouv.tg, UNESCO-ISU),
les territoires où les investissements éducatifs sont les plus prioritaires.

Ce n'est pas un tableau de bord descriptif : les quatre dimensions du défi — **couverture scolaire,
infrastructures essentielles, capacité enseignante, résultats scolaires** — alimentent un module de
**Priorisation des investissements** qui produit des classements, des explications automatiques et
des recommandations argumentées (impact attendu + score de confiance).

## Architecture

```text
Données brutes (data/brutes/)
        │
        ▼
Prétraitement R (preprocessing/)
(Nettoyage + Fusion + Indicateurs + ACP + HCPC/K-means + ISPE
 + profils + recommandations + cartes)
        │
        ▼
Fichiers .rds (app/data/)
        │
        ▼
Dashboard R Shiny (app/)
```

Le tableau de bord **ne fait aucun calcul statistique** : il lit uniquement les fichiers `.rds`
générés en amont. Les temps de chargement restent donc très faibles.

## Démarrage rapide

```r
# 1. Installer les dépendances (une seule fois)
source("install_packages.R")

# 2. Lancer l'application (les .rds sont déjà fournis dans app/data/)
shiny::runApp("app")
```

> En cas de mise à jour des données brutes, régénérer les `.rds` :
> `Rscript preprocessing/00_run_all.R` (depuis la racine du projet), puis relancer l'application.

## Contenu du dépôt

| Dossier | Rôle |
|---|---|
| `data/brutes/` | Données ouvertes d'origine (CSV geodata/opendata, UIS, shapefiles, frontières geoBoundaries) |
| `preprocessing/` | Pipeline de prétraitement (6 scripts, orchestrés par `00_run_all.R`) |
| `app/data/` | Fichiers `.rds` prêts à l'emploi : `base_finale`, `indicateurs`, `acp`, `classification`, `profils_classes`, `ispe`, `recommandations`, `cartes`, `resultats_nationaux`, `simulation`, `meta` |
| `app/` | Application Shiny (bs4Dash + bslib, highcharter, plotly, leaflet, DT) |
| `app/www/` | Habillage : CSS aux couleurs du Togo, drapeau et écusson (SVG à remplacer par vos visuels) |

## Méthodes (exécutées uniquement au prétraitement)

1. **Nettoyage / harmonisation** : filtrage géographique, déduplication, recodage des `Nsp`/`N/a`,
   harmonisation des noms de territoires (39 préfectures, 117 communes).
2. **Reconstruction cartographique** : frontières geoBoundaries + tessellation de **Voronoï**
   des 15 000+ établissements pour reconstituer les polygones des préfectures et communes.
3. **Indicateurs synthétiques** par territoire (densité, complétude du cycle, toilettes/100 étab.,
   bâtiments récents, encadrement préscolaire, etc.).
4. **ACP** sur indicateurs standardisés (écrêtés à ±2,5 σ) → composantes ≥ 80 % de variance.
5. **HCPC** : CAH de Ward sur composantes principales, **consolidation K-means**, profils de classes.
6. **ISPE** — Indice Synthétique de Priorité Éducative (0-100) : moyenne pondérée des déficits
   des 4 dimensions (30 % couverture, 30 % infrastructures, 25 % enseignants, 15 % conditions de réussite).
7. **Moteur de recommandations** : règles sur les percentiles nationaux → actions ordonnées,
   impact attendu, score de confiance.

*Limite documentée : les résultats d'examens ne sont ouverts qu'à l'échelle nationale ; la dimension
« résultats scolaires » territoriale mobilise un indice de conditions de réussite (encadrement,
complétude du cycle, hygiène, état du bâti), les résultats nationaux officiels étant affichés dans le
module Priorisation.*

## Simulateur de politiques publiques

L'onglet **Priorisation → Simulateur** répond à des questions en langage naturel
(« Que se passe-t-il si je construis 50 salles de classe dans la commune de Tône 1 ? ») :
la question est analysée (quantité, type d'investissement, territoire), puis l'impact est
simulé « toutes choses égales par ailleurs » à partir des paramètres précalculés de
`simulation.rds` (moyennes, écarts-types, bornes des piliers) — aucun recalcul d'ACP ni
de classification dans l'application. Résultats : ISPE avant/après, évolution du rang,
déficits par pilier, indicateurs modifiés et lecture automatique.

## Personnalisation

- **En-tête** : remplacez `app/www/drapeau_togo.svg` et `app/www/armoiries_togo.svg` par vos images.
- **Onglet Auteur** : éditez la liste `AUTEUR` en tête de `app/R/mod_auteur.R`
  (nom, titre, bio, contacts, compétences) et déposez votre photo dans
  `app/www/auteur_photo.jpg`.

## Sources

- geodata.gouv.tg — établissements scolaires, toilettes, bâtiments, terrains de sport, crèches, bibliothèques
- opendata.gouv.tg — éducation et résultats scolaires, enseignants du préscolaire par inspection
- UNESCO — Institut de statistique (SDG4, OPRI, démographie)
- geoBoundaries (gbOpen) — frontières administratives
"# Priorisation-des-investissements-dans-education-au-togo-DATA-CHALLENGE-TOGO-AI-LAB-Defi-1-EDUCATION"  
