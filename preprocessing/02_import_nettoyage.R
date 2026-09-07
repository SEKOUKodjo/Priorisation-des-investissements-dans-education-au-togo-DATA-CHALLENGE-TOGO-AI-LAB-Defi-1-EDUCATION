# =============================================================================
# 02_import_nettoyage.R — Import, contrôle qualité et nettoyage des bases brutes
# Produit : objets propres en mémoire (etabs, creches, toilettes, batiments,
#           terrains, biblio, sup, enseignants, resultats, uis)
# =============================================================================

message("== [2/6] Import & nettoyage des données brutes ==")

lire_csv <- function(chemin) {
  suppressWarnings(readr::read_csv(chemin, show_col_types = FALSE,
                                   locale = readr::locale(encoding = "UTF-8")))
}

# ---- 1. Établissements scolaires (base pivot) --------------------------------
etabs_brut <- lire_csv(file.path(CHEMIN_BRUTES, "couverture/etablissements_scolaires.csv"))
coords <- extraire_lonlat(etabs_brut$geometry)

etabs <- etabs_brut |>
  transmute(
    region     = nettoyer_texte(region_nom_bdd),
    prefecture = nettoyer_texte(prefecture_nom_bdd),
    commune    = nettoyer_texte(commune_nom_bdd),
    canton     = recoder_inconnu(canton_nom_bdd),
    localite   = recoder_inconnu(nom_localite),
    nom        = recoder_inconnu(etablissement_nom, "Établissement sans nom"),
    categorie  = nettoyer_texte(etablissement_categorie),
    statut_terrain = recoder_inconnu(terrain),
    inspection = recoder_inconnu(inspection_tutelle),
    terrain_sport = nettoyer_texte(terrain_sport),
    lon = coords$lon, lat = coords$lat
  ) |>
  filter(!is.na(region), !is.na(prefecture), !is.na(commune), !is.na(categorie)) |>
  filter(dans_togo(lon, lat)) |>
  distinct(nom, commune, canton, lon, lat, .keep_all = TRUE) |>
  mutate(
    categorie = case_when(
      categorie == "Jardin (maternelle)" ~ "Préscolaire",
      categorie == "Ecole primaire"      ~ "Primaire",
      categorie == "College"             ~ "Collège",
      categorie == "Lycée"               ~ "Lycée",
      TRUE ~ categorie
    ),
    est_public = grepl("public|etat|foncier", tolower(statut_terrain)),
    a_terrain_sport = terrain_sport == "Oui"
  )

message(sprintf("   Établissements valides : %s (sur %s lignes brutes)",
                nrow(etabs), nrow(etabs_brut)))

# ---- 2. Crèches ----------------------------------------------------------------
creches_brut <- lire_csv(file.path(CHEMIN_BRUTES, "couverture/creches.csv"))
cc <- extraire_lonlat(creches_brut$geometry)
creches <- creches_brut |>
  transmute(
    region = nettoyer_texte(region_nom_bdd), prefecture = nettoyer_texte(prefecture_nom_bdd),
    commune = nettoyer_texte(commune_nom_bdd),
    nom = recoder_inconnu(etab_nom, "Crèche sans nom"),
    statut = recoder_inconnu(activite_statut),
    lon = cc$lon, lat = cc$lat
  ) |>
  filter(!is.na(region), dans_togo(lon, lat)) |>
  mutate(active = grepl("Utilise", statut, ignore.case = TRUE))

# ---- 3. Toilettes scolaires ----------------------------------------------------
toil_brut <- lire_csv(file.path(CHEMIN_BRUTES, "infrastructures/toilettes_scolaires.csv"))
tc <- extraire_lonlat(toil_brut$geometry)
toilettes <- toil_brut |>
  transmute(
    region = nettoyer_texte(region_nom_bdd), prefecture = nettoyer_texte(prefecture_nom_bdd),
    commune = nettoyer_texte(commune_nom_bdd),
    type = gsub("[{}]", "", recoder_inconnu(toilette_type)),
    lon = tc$lon, lat = tc$lat
  ) |>
  filter(!is.na(region), dans_togo(lon, lat)) |>
  mutate(amelioree = grepl("WC|eau|Douche", type, ignore.case = TRUE))

# ---- 4. Bâtiments scolaires ----------------------------------------------------
bat_brut <- lire_csv(file.path(CHEMIN_BRUTES, "infrastructures/batiments_scolaires.csv"))
bc <- extraire_lonlat(bat_brut$geometry)
batiments <- bat_brut |>
  transmute(
    region = nettoyer_texte(region_nom_bdd), prefecture = nettoyer_texte(prefecture_nom_bdd),
    commune = nettoyer_texte(commune_nom_bdd),
    fonction = recoder_inconnu(batiment_fonction),
    annee = suppressWarnings(as.integer(nettoyer_texte(batiment_annee))),
    lon = bc$lon, lat = bc$lat
  ) |>
  filter(!is.na(region), dans_togo(lon, lat)) |>
  mutate(
    annee = ifelse(!is.na(annee) & (annee < 1900 | annee > 2026), NA_integer_, annee),
    salle_classe = grepl("classe", fonction, ignore.case = TRUE),
    recent = !is.na(annee) & annee >= 2010
  )

# ---- 5. Terrains de sport --------------------------------------------------------
ter_brut <- lire_csv(file.path(CHEMIN_BRUTES, "infrastructures/terrains_sport.csv"))
xc <- extraire_lonlat(ter_brut$geometry)
terrains <- ter_brut |>
  transmute(
    region = nettoyer_texte(region_nom_bdd), prefecture = nettoyer_texte(prefecture_nom_bdd),
    commune = nettoyer_texte(commune_nom_bdd),
    lon = xc$lon, lat = xc$lat
  ) |>
  filter(!is.na(region), dans_togo(lon, lat))

# ---- 6. Bibliothèques & enseignement supérieur (shapefiles) ---------------------
biblio <- tryCatch({
  b <- sf::st_read(file.path(CHEMIN_BRUTES, "geodata/bibliotheques/bibliotheques.shp"), quiet = TRUE)
  xy <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(b)))
  tibble(region = nettoyer_texte(b$region_nom), prefecture = nettoyer_texte(b$prefecture),
         commune = nettoyer_texte(b$commune_no), lon = xy[, 1], lat = xy[, 2])
}, error = function(e) tibble(region = character(), prefecture = character(),
                              commune = character(), lon = numeric(), lat = numeric()))

sup <- tryCatch({
  s <- sf::st_read(file.path(CHEMIN_BRUTES, "geodata/enseignement_superieur/enseignement_superieur.shp"), quiet = TRUE)
  xy <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(s)))
  tibble(region = nettoyer_texte(s$region_nom), prefecture = nettoyer_texte(s$prefecture),
         commune = nettoyer_texte(s$commune_no), nom = nettoyer_texte(s$etab_nom),
         lon = xy[, 1], lat = xy[, 2])
}, error = function(e) tibble())

# ---- 7. Enseignants du préscolaire par inspection --------------------------------
ens_brut <- lire_csv(file.path(CHEMIN_BRUTES, "couverture/enseignants_prescolaire_inspection.csv"))
enseignants <- ens_brut |>
  rename(inspection = inspections, valeur = Value) |>
  filter(!grepl("^T\\.", inspection)) |>              # retire totaux et sous-totaux
  mutate(prefecture = inspection_vers_prefecture(inspection),
         valeur = suppressWarnings(as.numeric(valeur))) |>
  filter(!is.na(prefecture), !is.na(valeur))

enseignants_pref <- enseignants |>
  filter(sexe == "Total") |>
  group_by(prefecture) |>
  summarise(enseignants_prescolaire = sum(valeur), .groups = "drop")

enseignants_sexe <- enseignants |>
  filter(sexe != "Total") |>
  group_by(prefecture, sexe) |>
  summarise(enseignants = sum(valeur), .groups = "drop")

# ---- 8. Résultats scolaires nationaux (opendata) ----------------------------------
res_brut <- lire_csv(file.path(CHEMIN_BRUTES, "resultats/resultats_scolaires.csv"))
resultats <- res_brut |>
  rename(indicateur = indicateurs, annee = Date, valeur = Value, unite = Unit) |>
  filter(indicateur != "indicateurs") |>
  mutate(
    indicateur = sub("^r", "R", indicateur),          # harmonise la casse
    annee = suppressWarnings(as.integer(annee)),
    valeur = suppressWarnings(as.numeric(valeur))
  ) |>
  filter(!is.na(annee), !is.na(valeur))

# ---- 9. Indicateurs internationaux UIS/UNESCO --------------------------------------
lire_uis <- function(fichier) {
  d <- lire_csv(file.path(CHEMIN_BRUTES, "indicateurs", fichier))
  d |> filter(!grepl("^#", indicator_id)) |>
    mutate(year = suppressWarnings(as.integer(year)),
           value = suppressWarnings(as.numeric(value))) |>
    filter(!is.na(year), !is.na(value))
}
uis_sdg  <- lire_uis("sdg-data-tgo.csv")
uis_opri <- lire_uis("opri-data-tgo.csv")
uis_dem  <- lire_uis("dem-data-tgo.csv")

# Extraction ciblée : électrification, assainissement, ratio élèves/maître, scolarisation
extraire_uis <- function(donnees, codes, libelles) {
  donnees |> filter(indicator_id %in% codes) |>
    left_join(tibble(indicator_id = codes, libelle = libelles), by = "indicator_id") |>
    select(indicateur = libelle, code = indicator_id, annee = year, valeur = value)
}

uis_infra <- extraire_uis(uis_sdg,
  c("SCHBSP.1.WELEC", "SCHBSP.2.WELEC", "SCHBSP.3.WELEC",
    "SCHBSP.1.WTOILA", "SCHBSP.2.WTOILA", "SCHBSP.3.WTOILA"),
  c("Écoles primaires électrifiées (%)", "Collèges électrifiés (%)", "Lycées électrifiés (%)",
    "Primaires avec assainissement de base (%)", "Collèges avec assainissement de base (%)",
    "Lycées avec assainissement de base (%)"))

uis_ratio <- uis_opri |>
  filter(indicator_id %in% c("PTRHC.02", "PTRHC.1", "PTRHC.2", "PTRHC.3")) |>
  mutate(indicateur = case_when(
    indicator_id == "PTRHC.02" ~ "Préscolaire",
    indicator_id == "PTRHC.1"  ~ "Primaire",
    indicator_id == "PTRHC.2"  ~ "Collège",
    indicator_id == "PTRHC.3"  ~ "Lycée")) |>
  select(indicateur, annee = year, valeur = value)

message(sprintf("   Bases nettoyées : %s écoles, %s crèches, %s toilettes, %s bâtiments, %s terrains",
                nrow(etabs), nrow(creches), nrow(toilettes), nrow(batiments), nrow(terrains)))
message("[OK] Import & nettoyage terminés")
