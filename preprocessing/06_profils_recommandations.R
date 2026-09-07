# =============================================================================
# 06_profils_recommandations.R — Génération automatique des profils de classes,
# des explications territoriales et des recommandations d'investissement
# Produit : profils_classes.rds, recommandations.rds, resultats_nationaux.rds, meta.rds
# =============================================================================

message("== [6/6] Profils, explications & recommandations ==")

LIB <- setNames(indicateurs$dictionnaire$libelle, indicateurs$dictionnaire$variable)
LIB_PILIERS <- c(couverture = "Couverture scolaire", infrastructures = "Infrastructures essentielles",
                 enseignants = "Capacité enseignante", resultats = "Conditions de réussite scolaire")

nom_territoire <- function(df) {
  if ("commune" %in% names(df)) df$commune
  else if ("prefecture" %in% names(df)) df$prefecture
  else df$region
}

# ---- 1. Profils automatiques des classes ---------------------------------------
profiler_classes <- function(res, z, niveau) {
  if (all(is.na(res$classe))) return(NULL)
  cles_z <- setdiff(names(z), c("region", "prefecture", "commune"))
  agg <- cbind(classe = res$classe, z[, cles_z]) |>
    group_by(classe) |> summarise(across(everything(), mean), .groups = "drop") |>
    filter(!is.na(classe))
  ispe_moy <- tapply(res$ispe, res$classe, mean)
  deficits_moy <- res |> group_by(classe) |>
    summarise(across(starts_with("deficit_"), mean), .groups = "drop")

  profils <- lapply(agg$classe, function(cl) {
    ligne <- agg[agg$classe == cl, cles_z]
    tri <- sort(unlist(ligne))
    faibles <- names(tri)[1:3]
    fortes  <- rev(names(tri))[1:3]
    defs <- deficits_moy[deficits_moy$classe == cl, -1]
    pilier_dom <- names(PILIERS)[which.max(unlist(defs))]
    rang_sev <- rank(-ispe_moy)[as.character(cl)]
    severite <- c("critique", "élevée", "modérée", "faible", "faible", "faible")[rang_sev]
    tibble(
      niveau = niveau, classe = cl,
      effectif = sum(res$classe == cl, na.rm = TRUE),
      ispe_moyen = round(ispe_moy[[as.character(cl)]], 1),
      pilier_dominant = LIB_PILIERS[[pilier_dom]],
      libelle = sprintf("Classe %s — Priorité %s : déficits marqués en %s",
                        cl, severite, tolower(LIB_PILIERS[[pilier_dom]])),
      description = sprintf(
        "Territoires caractérisés par des niveaux faibles pour : %s. Points relativement favorables : %s.",
        paste(tolower(LIB[faibles]), collapse = " ; "),
        paste(tolower(LIB[fortes]), collapse = " ; ")),
      couleur = c("#C62828", "#E65100", "#F9A825", "#2E7D32", "#1B5E20", "#155724")[rang_sev]
    )
  })
  bind_rows(profils)
}

profils_classes <- list(
  commune    = profiler_classes(analyse_commune$resultat,    analyse_commune$z,    "commune"),
  prefecture = profiler_classes(analyse_prefecture$resultat, analyse_prefecture$z, "prefecture")
)

# ---- 2. Explications automatiques par territoire --------------------------------
expliquer <- function(res, z, niveau) {
  cles <- intersect(c("region", "prefecture", "commune"), names(res))
  cles_z <- setdiff(names(z), cles)
  profs <- profils_classes[[niveau]]
  n_total <- nrow(res)

  lignes <- lapply(seq_len(n_total), function(i) {
    zi <- sort(unlist(z[i, cles_z]))
    faibles <- head(zi, 3); fortes <- tail(zi, 3)
    cl <- res$classe[i]
    lib_classe <- if (!is.na(cl) && !is.null(profs)) profs$libelle[profs$classe == cl] else "Non classé (échelon régional)"
    texte <- sprintf(
      paste0("%s se situe au rang %s sur %s au niveau national avec un score ISPE de %s ",
             "(%s). Ce classement s'explique principalement par : %s. ",
             "Le territoire conserve des atouts relatifs sur : %s."),
      nom_territoire(res)[i], res$rang[i], n_total, res$ispe[i],
      tolower(res$niveau_priorite[i]),
      paste(tolower(LIB[names(faibles)]), collapse = " ; "),
      paste(tolower(LIB[names(fortes)]), collapse = " ; "))
    tibble(
      !!!setNames(as.list(res[i, cles]), cles),
      classe = cl, libelle_classe = lib_classe,
      ispe = res$ispe[i], rang = res$rang[i], niveau_priorite = res$niveau_priorite[i],
      points_faibles = paste(LIB[names(faibles)], collapse = "|"),
      points_forts   = paste(LIB[names(fortes)], collapse = "|"),
      z_faibles = paste(round(faibles, 2), collapse = "|"),
      z_forts   = paste(round(fortes, 2), collapse = "|"),
      explication = texte
    )
  })
  bind_rows(lignes)
}

explications <- list(
  commune    = expliquer(analyse_commune$resultat,    analyse_commune$z,    "commune"),
  prefecture = expliquer(analyse_prefecture$resultat, analyse_prefecture$z, "prefecture"),
  region     = expliquer(analyse_region$resultat,     analyse_region$z,     "region")
)

# ---- 3. Recommandations intelligentes --------------------------------------------
generer_recommandations <- function(ind, res, niveau) {
  cles <- intersect(c("region", "prefecture", "commune"), names(ind))
  df <- ind |> left_join(res[, c(cles, "ispe", "silhouette")], by = cles)
  pct <- function(x) rank(x, ties.method = "average") / length(x)
  p <- lapply(df[, c("densite_etab_100km2", "completude_offre", "jardins_100_primaires",
                     "ens_100_jardins", "toilettes_100_etab", "pct_toilettes_ameliorees",
                     "pct_batiments_recents", "biblio_100_etab", "pct_terrain_sport")], pct)

  impact_de <- function(q) ifelse(q < .15, "Très élevé", ifelse(q < .30, "Élevé", ifelse(q < .45, "Moyen", "Modéré")))
  confiance_de <- function(nb, sil, q) {
    pmin(95, round(55 + 25 * pmin(nb, 300) / 300 + 15 * pmax(ifelse(is.na(sil), 0.2, sil), 0) - 5 * (q > .35)))
  }

  lignes <- list()
  for (i in seq_len(nrow(df))) {
    cand <- list()
    ajouter_reco <- function(q, action, dimension, justification) {
      cand[[length(cand) + 1]] <<- tibble(q = q, action = action, dimension = dimension,
                                          justification = justification)
    }
    manque <- c(if (df$nb_lycee[i] == 0) "lycée", if (df$nb_college[i] == 0) "collège",
                if (df$nb_prescolaire[i] == 0) "jardin d'enfants")
    q_couv <- min(p$densite_etab_100km2[i], p$completude_offre[i])
    if (q_couv < .45 || length(manque) > 0)
      ajouter_reco(q_couv,
        if (length(manque) > 0) sprintf("Construire de nouvelles écoles (en priorité : %s)", paste(manque, collapse = ", "))
        else "Construire de nouvelles écoles pour densifier le maillage",
        "Couverture scolaire",
        sprintf("Densité de %s établissements/100 km² et complétude du cycle de %s%%, parmi les plus faibles du pays.",
                df$densite_etab_100km2[i], df$completude_offre[i]))
    if (p$jardins_100_primaires[i] < .35 && df$nb_prescolaire[i] > 0)
      ajouter_reco(p$jardins_100_primaires[i], "Développer l'offre préscolaire (jardins d'enfants)",
        "Couverture scolaire",
        sprintf("Seulement %s jardins d'enfants pour 100 écoles primaires.", df$jardins_100_primaires[i]))
    if (p$ens_100_jardins[i] < .40)
      ajouter_reco(p$ens_100_jardins[i], "Recruter et affecter des enseignants",
        "Capacité enseignante",
        sprintf("Taux d'encadrement estimé à %s enseignants pour 100 jardins d'enfants, sous la référence nationale.",
                df$ens_100_jardins[i]))
    if (p$toilettes_100_etab[i] < .40 || (!is.na(df$pct_toilettes_ameliorees[i]) && df$pct_toilettes_ameliorees[i] < 50))
      ajouter_reco(p$toilettes_100_etab[i], "Construire des blocs de toilettes et latrines améliorées",
        "Infrastructures essentielles",
        sprintf("%s points de toilettes pour 100 établissements ; au niveau national, seuls 6 à 38%% des établissements disposent d'un assainissement de base (UNESCO-ISU 2022).",
                df$toilettes_100_etab[i]))
    if (p$pct_batiments_recents[i] < .40)
      ajouter_reco(p$pct_batiments_recents[i], "Réhabiliter et électrifier les bâtiments scolaires",
        "Infrastructures essentielles",
        sprintf("%s%% de bâtiments construits depuis 2010 ; l'électrification nationale varie de 29%% (primaire) à 66%% (lycée) (UNESCO-ISU 2022).",
                ifelse(is.na(df$pct_batiments_recents[i]), 0, df$pct_batiments_recents[i])))
    if (df$nb_bibliotheques[i] == 0)
      ajouter_reco(p$biblio_100_etab[i] * 0.8, "Construire des bibliothèques scolaires",
        "Infrastructures essentielles",
        "Aucune bibliothèque scolaire recensée sur le territoire.")
    if (p$pct_terrain_sport[i] < .35)
      ajouter_reco(p$pct_terrain_sport[i] + .05, "Aménager des terrains de sport",
        "Infrastructures essentielles",
        sprintf("Seuls %s%% des établissements disposent d'un terrain de sport.", df$pct_terrain_sport[i]))

    if (length(cand) == 0)
      ajouter_reco(.6, "Consolider les acquis et maintenir le niveau d'équipement",
        "Suivi", "Aucun déficit majeur détecté par rapport au reste du pays.")

    recos <- bind_rows(cand) |> arrange(q) |> head(5)
    recos$ordre <- seq_len(nrow(recos))
    recos$impact_attendu <- impact_de(recos$q)
    recos$confiance <- confiance_de(df$nb_etab[i], df$silhouette[i], recos$q)
    for (k in cles) recos[[k]] <- df[[k]][i]
    lignes[[i]] <- recos |> select(all_of(cles), ordre, action, dimension,
                                   impact_attendu, confiance, justification)
  }
  bind_rows(lignes)
}

recommandations <- list(
  commune    = generer_recommandations(indicateurs$commune,    analyse_commune$resultat,    "commune"),
  prefecture = generer_recommandations(indicateurs$prefecture, analyse_prefecture$resultat, "prefecture"),
  region     = generer_recommandations(indicateurs$region,
                 analyse_region$resultat |> mutate(silhouette = NA_real_), "region"),
  explications = explications
)

saveRDS(profils_classes, file.path(CHEMIN_SORTIES, "profils_classes.rds"))
saveRDS(recommandations, file.path(CHEMIN_SORTIES, "recommandations.rds"))

# ---- 4. Résultats scolaires nationaux ---------------------------------------------
derniere <- function(df) df |> group_by(indicateur = indicateur, niveau, secteur) |>
  slice_max(annee, n = 1, with_ties = FALSE) |> ungroup()

resultats_nationaux <- list(
  series      = resultats,
  reussite    = resultats |> filter(indicateur == "Résultats de l'examen de compétence"),
  scolarisation = resultats |> filter(indicateur == "Taux de scolarisation"),
  achevement  = resultats |> filter(indicateur == "Taux d'achèvement ou de diplomation"),
  analphabetisme = resultats |> filter(indicateur == "Taux d'analphabétisme des adultes (%)"),
  budget      = resultats |> filter(grepl("Budget|penses", indicateur)),
  ecoles_enseignants = resultats |> filter(indicateur %in% c("Nombre d'écoles", "Nombre d'enseignants")),
  uis_infrastructures = uis_infra,
  uis_ratio_eleves_maitre = uis_ratio
)
saveRDS(resultats_nationaux, file.path(CHEMIN_SORTIES, "resultats_nationaux.rds"))

# ---- 5. Métadonnées ----------------------------------------------------------------
meta <- list(
  date_generation = format(Sys.time(), "%d/%m/%Y %H:%M"),
  nb_etablissements = nrow(etabs),
  nb_creches = nrow(creches),
  nb_toilettes = nrow(toilettes),
  nb_batiments = nrow(batiments),
  nb_terrains = nrow(terrains),
  nb_bibliotheques = nrow(biblio),
  nb_enseignants_prescolaire = sum(enseignants_pref$enseignants_prescolaire),
  nb_regions = nrow(indicateurs$region),
  nb_prefectures = nrow(indicateurs$prefecture),
  nb_communes = nrow(indicateurs$commune),
  sources = c(
    "geodata.gouv.tg — Établissements scolaires, toilettes, bâtiments, terrains de sport, crèches, bibliothèques",
    "opendata.gouv.tg — Éducation et résultats scolaires, enseignants du préscolaire par inspection",
    "UNESCO — Institut de Statistique (ISU) : indicateurs SDG4, OPRI et démographie",
    "geoBoundaries (gbOpen) — Frontières administratives du Togo"
  ),
  note_methodologique = paste(
    "Les indicateurs territoriaux sont calculés à partir des bases géolocalisées officielles,",
    "agrégés aux échelons région, préfecture et commune. Une ACP suivie d'une classification",
    "hiérarchique (Ward) consolidée par K-means regroupe les territoires en profils homogènes.",
    "L'ISPE (0-100) combine les déficits des quatre dimensions : couverture scolaire (30%),",
    "infrastructures essentielles (30%), capacité enseignante (25%) et conditions de réussite scolaire (15%).",
    "Les résultats scolaires territorialisés n'étant pas publiés en données ouvertes, la quatrième dimension",
    "mobilise un indice de conditions de réussite (encadrement, complétude du cycle, hygiène, état du bâti),",
    "complété par les résultats nationaux officiels affichés dans le module Priorisation.")
)
saveRDS(meta, file.path(CHEMIN_SORTIES, "meta.rds"))

message("[OK] profils_classes.rds, recommandations.rds, resultats_nationaux.rds, meta.rds enregistrés")
