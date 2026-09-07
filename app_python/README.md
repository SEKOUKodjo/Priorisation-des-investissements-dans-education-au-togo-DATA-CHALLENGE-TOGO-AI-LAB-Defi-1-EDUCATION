# SAD Éducation Togo — version Shiny for Python

Portage complet de l'application R Shiny vers **Shiny for Python**, avec les mêmes
fonctionnalités : Accueil, Couverture scolaire, Infrastructures essentielles,
Capacité enseignante, Priorisation des investissements (vue nationale, fiche
territoire, résultats scolaires, **simulateur de politiques publiques**,
comparaison) et Auteur.

## Architecture

Le prétraitement reste en R (source de vérité unique) ; un script d'export fait
le pont vers Python :

```text
Données brutes → Prétraitement R (.rds) → 07_export_python.R → CSV / GeoJSON / JSON → Shiny for Python
```

L'application Python ne fait **aucun calcul statistique** : elle lit les 26
fichiers de `app_python/data/`. Le simulateur applique la même arithmétique
« toutes choses égales par ailleurs » que la version R, à partir des paramètres
précalculés (`simulation.json`).

## Lancement

```bash
cd app_python
pip install -r requirements.txt
shiny run app.py --port 8000
# puis ouvrir http://127.0.0.1:8000
```

## Mise à jour des données

```bash
Rscript preprocessing/00_run_all.R          # régénère les .rds
Rscript preprocessing/07_export_python.R    # ré-exporte pour Python
```

## Technologies

| Rôle | R Shiny | Shiny for Python |
|---|---|---|
| Interface | bs4Dash / bslib | shiny.ui (navset_pill_list, value_box, card) |
| Cartes interactives | leaflet | folium |
| Graphiques | highcharter + plotly | plotly (shinywidgets) |
| Tableaux | DT | render.DataGrid |
| Exports cartes | graphiques base R | matplotlib + geopandas |
| Exports tableurs | writexl | pandas + openpyxl |

## Cartes interactives

Les cartes sont produites avec **folium** (rendu Leaflet), intégrées via une
`<iframe>`. Comme dans la version R Shiny :

- **trois fonds de carte** avec sélecteur de couches : *Fond clair*,
  *OpenStreetMap* et **Satellite** (imagerie Esri World Imagery) ;
- choroplèthe coloré, infobulles au survol, légende, zoom, échelle ;
- surimpression optionnelle des établissements scolaires.

La bibliothèque **Leaflet est servie localement** (`www/lib/leaflet/`) : l'affichage
des cartes fonctionne **hors ligne**, exactement comme la version R. Seules les
tuiles des fonds de carte (fonds clair/OSM/satellite) nécessitent une connexion,
ce qui est inhérent à toute carte en ligne.

Les fichiers HTML des cartes sont générés à la volée dans `www/cartes/` (mis en
cache par empreinte, nettoyés au démarrage) — inutile de les versionner.

## Remarques

- Les résultats (scores ISPE, classes, recommandations, simulateur) sont
  strictement identiques à ceux de la version R : les deux applications lisent
  les mêmes sorties du prétraitement.

## Personnalisation

- **En-tête** : `www/drapeau_togo.svg`, `www/armoiries_togo.svg`
- **Onglet Auteur** : dictionnaire `AUTEUR` en tête de `mod_auteur.py`,
  photo dans `www/auteur_photo.jpg`
