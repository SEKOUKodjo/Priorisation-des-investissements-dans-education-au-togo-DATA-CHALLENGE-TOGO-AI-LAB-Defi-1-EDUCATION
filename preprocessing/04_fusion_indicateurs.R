# =============================================================================
# 04_fusion_indicateurs.R — Fusion des bases et construction des indicateurs
# territoriaux aux trois échelons : région, préfecture, commune
# Produit : base_finale.rds, indicateurs.rds
# =============================================================================

message("== [4/6] Fusion des bases & calcul des indicateurs ==")

NIVEAUX <- list(
  region     = "region",
  prefecture = c("region", "prefecture"),
  commune    = c("region", "prefecture", "commune")
)

superficies <- list(
  region     = sf::st_drop_geometry(cartes$regions)[, c("region", "superficie_km2")],
  prefecture = sf::st_drop_geometry(cartes$prefectures)[, c("region", "prefecture", "superficie_km2")],
  commune    = sf::st_drop_geometry(cartes$communes)[, c("region", "prefecture", "commune", "superficie_km2")]
)

calculer_indicateurs <- function(cles) {
  socle <- etabs |>
    group_by(across(all_of(cles))) |>
    summarise(
      nb_etab        = n(),
      nb_prescolaire = sum(categorie == "Préscolaire"),
      nb_primaire    = sum(categorie == "Primaire"),
      nb_college     = sum(categorie == "Collège"),
      nb_lycee       = sum(categorie == "Lycée"),
      pct_public     = round(100 * mean(est_public), 1),
      pct_terrain_sport = round(100 * mean(a_terrain_sport, na.rm = TRUE), 1),
      completude_offre  = round(100 * mean(c(any(categorie == "Préscolaire"),
                                             any(categorie == "Primaire"),
                                             any(categorie == "Collège"),
                                             any(categorie == "Lycée"))), 1),
      .groups = "drop"
    )

  ajouter <- function(base, donnees, nom_var, filtre = NULL) {
    if (nrow(donnees) == 0) { base[[nom_var]] <- 0; return(base) }
    agg <- donnees |> group_by(across(all_of(cles))) |>
      summarise(!!nom_var := n(), .groups = "drop")
    base |> left_join(agg, by = cles) |>
      mutate(across(all_of(nom_var), ~tidyr::replace_na(., 0)))
  }

  socle <- socle |>
    ajouter(creches,   "nb_creches") |>
    ajouter(toilettes, "nb_toilettes") |>
    ajouter(batiments, "nb_batiments") |>
    ajouter(terrains,  "nb_terrains_sport") |>
    ajouter(biblio,    "nb_bibliotheques")

  toil_am <- toilettes |> group_by(across(all_of(cles))) |>
    summarise(pct_toilettes_ameliorees = round(100 * mean(amelioree), 1), .groups = "drop")
  bat_rec <- batiments |> filter(!is.na(annee)) |> group_by(across(all_of(cles))) |>
    summarise(pct_batiments_recents = round(100 * mean(recent), 1), .groups = "drop")

  socle |>
    left_join(toil_am, by = cles) |>
    left_join(bat_rec, by = cles) |>
    mutate(
      toilettes_100_etab   = round(100 * nb_toilettes / nb_etab, 1),
      batiments_par_etab   = round(nb_batiments / nb_etab, 2),
      biblio_100_etab      = round(100 * nb_bibliotheques / nb_etab, 2),
      jardins_100_primaires = round(100 * nb_prescolaire / pmax(nb_primaire, 1), 1)
    )
}

indicateurs <- lapply(NIVEAUX, calculer_indicateurs)

# ---- Capacité enseignante (donnée native : préfecture) -------------------------
indicateurs$prefecture <- indicateurs$prefecture |>
  left_join(enseignants_pref, by = "prefecture") |>
  mutate(enseignants_prescolaire = tidyr::replace_na(enseignants_prescolaire, 0))

indicateurs$region <- indicateurs$region |>
  left_join(
    indicateurs$prefecture |> group_by(region) |>
      summarise(enseignants_prescolaire = sum(enseignants_prescolaire), .groups = "drop"),
    by = "region"
  )

# Communes : répartition estimée au prorata du nombre de jardins d'enfants
alloc <- indicateurs$commune |>
  select(region, prefecture, commune, nb_prescolaire) |>
  group_by(prefecture) |>
  mutate(poids = nb_prescolaire / pmax(sum(nb_prescolaire), 1)) |>
  ungroup() |>
  left_join(enseignants_pref, by = "prefecture") |>
  mutate(enseignants_prescolaire = round(poids * tidyr::replace_na(enseignants_prescolaire, 0), 1)) |>
  select(region, prefecture, commune, enseignants_prescolaire)

indicateurs$commune <- indicateurs$commune |> left_join(alloc, by = c("region", "prefecture", "commune"))

# ---- Densités et ratios finaux ---------------------------------------------------
for (niv in names(indicateurs)) {
  indicateurs[[niv]] <- indicateurs[[niv]] |>
    left_join(superficies[[niv]], by = NIVEAUX[[niv]]) |>
    mutate(
      superficie_km2      = ifelse(is.na(superficie_km2) | superficie_km2 <= 0, NA, superficie_km2),
      densite_etab_100km2 = round(100 * nb_etab / superficie_km2, 1),
      ens_100_jardins     = round(100 * enseignants_prescolaire / pmax(nb_prescolaire, 1), 1),
      enseignants_100_etab = round(100 * enseignants_prescolaire / nb_etab, 1)
    )
}

# ---- Dictionnaire des indicateurs ------------------------------------------------
dictionnaire <- tibble::tribble(
  ~variable,                 ~libelle,                                          ~dimension,        ~sens,
  "nb_etab",                 "Nombre d'établissements scolaires",               "Couverture",      "+",
  "nb_prescolaire",          "Jardins d'enfants (préscolaire)",                 "Couverture",      "+",
  "nb_primaire",             "Écoles primaires",                                "Couverture",      "+",
  "nb_college",              "Collèges",                                        "Couverture",      "+",
  "nb_lycee",                "Lycées",                                          "Couverture",      "+",
  "nb_creches",              "Crèches recensées",                               "Couverture",      "+",
  "densite_etab_100km2",     "Établissements pour 100 km²",                     "Couverture",      "+",
  "completude_offre",        "Complétude du cycle éducatif (%)",                "Couverture",      "+",
  "jardins_100_primaires",   "Jardins d'enfants pour 100 écoles primaires",     "Couverture",      "+",
  "pct_public",              "Part d'établissements sur domaine public (%)",    "Couverture",      "+",
  "toilettes_100_etab",      "Points de toilettes pour 100 établissements",     "Infrastructures", "+",
  "pct_toilettes_ameliorees","Toilettes améliorées (WC / eau) (%)",             "Infrastructures", "+",
  "pct_batiments_recents",   "Bâtiments construits depuis 2010 (%)",            "Infrastructures", "+",
  "batiments_par_etab",      "Bâtiments recensés par établissement",            "Infrastructures", "+",
  "pct_terrain_sport",       "Établissements avec terrain de sport (%)",        "Infrastructures", "+",
  "biblio_100_etab",         "Bibliothèques pour 100 établissements",           "Infrastructures", "+",
  "enseignants_prescolaire", "Enseignants du préscolaire",                      "Enseignants",     "+",
  "ens_100_jardins",         "Enseignants pour 100 jardins d'enfants",          "Enseignants",     "+",
  "enseignants_100_etab",    "Enseignants du préscolaire pour 100 établissements", "Enseignants",  "+"
)

indicateurs$dictionnaire <- dictionnaire

# ---- Base finale fusionnée --------------------------------------------------------
base_finale <- list(
  etablissements = etabs,
  creches        = creches,
  toilettes      = toilettes,
  batiments      = batiments,
  terrains_sport = terrains,
  bibliotheques  = biblio,
  enseignement_superieur = sup,
  enseignants_prefecture = enseignants_pref,
  enseignants_sexe       = enseignants_sexe,
  resultats_nationaux    = resultats
)

saveRDS(base_finale, file.path(CHEMIN_SORTIES, "base_finale.rds"))
saveRDS(indicateurs, file.path(CHEMIN_SORTIES, "indicateurs.rds"))
message(sprintf("   Indicateurs : %s régions, %s préfectures, %s communes",
                nrow(indicateurs$region), nrow(indicateurs$prefecture), nrow(indicateurs$commune)))
message("[OK] base_finale.rds et indicateurs.rds enregistrés")
