# =============================================================================
# 05_analyses.R — Traitements statistiques (exécutés uniquement en amont)
# - Standardisation des indicateurs
# - Analyse en Composantes Principales (ACP)
# - Classification Hiérarchique sur Composantes Principales (HCPC)
#   avec consolidation K-means
# - Indice Synthétique de Priorité Éducative (ISPE)
# Produit : acp.rds, classification.rds, ispe.rds
# =============================================================================

message("== [5/6] ACP, HCPC + K-means, ISPE ==")
set.seed(1234)

VARS_ACP <- c("densite_etab_100km2", "completude_offre", "jardins_100_primaires",
              "toilettes_100_etab", "pct_toilettes_ameliorees", "pct_batiments_recents",
              "batiments_par_etab", "pct_terrain_sport", "biblio_100_etab",
              "ens_100_jardins")

PILIERS <- list(
  couverture      = c("densite_etab_100km2", "completude_offre", "jardins_100_primaires"),
  infrastructures = c("toilettes_100_etab", "pct_toilettes_ameliorees",
                      "pct_batiments_recents", "batiments_par_etab",
                      "pct_terrain_sport", "biblio_100_etab"),
  enseignants     = c("ens_100_jardins", "enseignants_100_etab"),
  resultats       = c("completude_offre", "ens_100_jardins",
                      "toilettes_100_etab", "pct_batiments_recents")
)

POIDS_ISPE <- c(couverture = 0.30, infrastructures = 0.30,
                enseignants = 0.25, resultats = 0.15)

LIBELLES_PRIORITE <- c("Très prioritaire", "Prioritaire", "À surveiller",
                       "Modéré", "Satisfaisant")

VARS_TOUTES <- union(VARS_ACP, unlist(PILIERS))

preparer_matrice <- function(df) {
  m <- df[, VARS_TOUTES]
  for (v in VARS_TOUTES) m[[v]] <- imputer_mediane(m[[v]], df$region)
  # écrêtage à ±2,5 écarts-types pour limiter le poids des cas extrêmes
  mz <- as.data.frame(lapply(m, function(v) pmin(pmax(zscore(v), -2.5), 2.5)))
  rownames(mz) <- NULL
  attr(mz, "stats") <- data.frame(
    variable = VARS_TOUTES,
    moyenne = vapply(m, mean, numeric(1)),
    ecart_type = vapply(m, function(v) { s <- sd(v); if (is.na(s) || s == 0) 1 else s }, numeric(1)),
    row.names = NULL
  )
  mz
}

choisir_k <- function(hc, k_min = 4, k_max = 6) {
  hauteurs <- rev(hc$height)
  pertes <- hauteurs[k_min:(k_max)] / hauteurs[(k_min - 1):(k_max - 1)]
  (k_min:k_max)[which.min(pertes)]
}

calculer_ispe <- function(df, mz) {
  piliers_z <- sapply(names(PILIERS), function(p) rowMeans(mz[, PILIERS[[p]], drop = FALSE]))
  BORNES_PILIERS <<- data.frame(pilier = colnames(piliers_z),
                                minimum = apply(piliers_z, 2, min),
                                maximum = apply(piliers_z, 2, max), row.names = NULL)
  deficits  <- apply(piliers_z, 2, function(s) round(100 - minmax_100(s), 1))
  colnames(deficits) <- paste0("deficit_", names(PILIERS))
  ispe <- round(as.numeric(deficits %*% POIDS_ISPE), 1)
  contrib <- sweep(deficits, 2, POIDS_ISPE, `*`)
  contrib <- round(100 * contrib / pmax(rowSums(contrib), 1e-9), 1)
  colnames(contrib) <- paste0("contrib_", names(PILIERS))
  cbind(as.data.frame(deficits), as.data.frame(contrib),
        ispe = ispe,
        rang = rank(-ispe, ties.method = "min"),
        niveau_priorite = as.character(cut(rank(ispe) / length(ispe),
                                           breaks = c(0, .2, .4, .6, .8, 1),
                                           labels = rev(LIBELLES_PRIORITE),
                                           include.lowest = TRUE)))
}

analyser_niveau <- function(df, cles, faire_classif = TRUE) {
  mz <- preparer_matrice(df)
  stats_vars <- attr(mz, "stats")

  # ---- ACP (en arrière-plan uniquement) ----
  acp <- prcomp(mz[, VARS_ACP], center = FALSE, scale. = FALSE)
  var_exp <- acp$sdev^2 / sum(acp$sdev^2)
  n_pc <- max(2, min(which(cumsum(var_exp) >= 0.80)))
  scores_pc <- as.data.frame(acp$x[, 1:n_pc, drop = FALSE])

  resultat <- df[, cles, drop = FALSE]
  resultat <- cbind(resultat, calculer_ispe(df, mz))

  classif <- NULL
  if (faire_classif && nrow(df) >= 12) {
    # ---- HCPC : CAH de Ward sur les composantes principales ----
    hc <- hclust(dist(scores_pc), method = "ward.D2")
    k <- choisir_k(hc)
    classes_cah <- cutree(hc, k = k)

    # ---- Consolidation K-means (centres initiaux = centres CAH) ----
    centres <- aggregate(scores_pc, list(classe = classes_cah), mean)[, -1]
    km <- kmeans(scores_pc, centers = as.matrix(centres), iter.max = 100)
    classes <- km$cluster

    # Renumérotation : classe 1 = ISPE moyen le plus élevé (la plus prioritaire)
    ordre <- order(-tapply(resultat$ispe, classes, mean))
    classes <- match(classes, ordre)

    sil <- tryCatch({
      s <- cluster::silhouette(classes, dist(scores_pc))
      round(s[, "sil_width"], 3)
    }, error = function(e) rep(NA_real_, length(classes)))

    resultat$classe <- classes
    resultat$silhouette <- sil
    classif <- list(k = k, inertie_expliquee = round(100 * km$betweenss / km$totss, 1))
  } else {
    resultat$classe <- NA_integer_
    resultat$silhouette <- NA_real_
  }

  list(
    resultat = resultat,
    z = cbind(df[, cles, drop = FALSE], mz),
    simulation = list(stats_variables = stats_vars, bornes_piliers = BORNES_PILIERS),
    acp = list(
      valeurs_propres = round(acp$sdev^2, 3),
      variance_expliquee = round(100 * var_exp, 1),
      n_composantes = n_pc,
      charges = round(acp$rotation[, 1:n_pc, drop = FALSE], 3),
      coordonnees = cbind(df[, cles, drop = FALSE], round(scores_pc, 3))
    ),
    classif = classif
  )
}

analyse_commune    <- analyser_niveau(indicateurs$commune,    c("region", "prefecture", "commune"))
analyse_prefecture <- analyser_niveau(indicateurs$prefecture, c("region", "prefecture"))
analyse_region     <- analyser_niveau(indicateurs$region,     "region", faire_classif = FALSE)

# Les régions héritent de la classe majoritaire de leurs communes
classe_reg <- analyse_commune$resultat |>
  count(region, classe) |> group_by(region) |> slice_max(n, n = 1, with_ties = FALSE) |>
  select(region, classe)
analyse_region$resultat$classe <- classe_reg$classe[match(analyse_region$resultat$region, classe_reg$region)]

acp_rds <- list(commune = analyse_commune$acp, prefecture = analyse_prefecture$acp,
                region = analyse_region$acp,
                variables = VARS_ACP, piliers = PILIERS, poids_ispe = POIDS_ISPE)

classification_rds <- list(
  commune    = analyse_commune$resultat[, c("region", "prefecture", "commune", "classe", "silhouette")],
  prefecture = analyse_prefecture$resultat[, c("region", "prefecture", "classe", "silhouette")],
  region     = analyse_region$resultat[, c("region", "classe")],
  parametres = list(commune = analyse_commune$classif, prefecture = analyse_prefecture$classif),
  methode = "CAH de Ward sur composantes principales (ACP), consolidation K-means"
)

ispe_rds <- list(
  commune    = analyse_commune$resultat,
  prefecture = analyse_prefecture$resultat,
  region     = analyse_region$resultat,
  z_commune    = analyse_commune$z,
  z_prefecture = analyse_prefecture$z,
  z_region     = analyse_region$z,
  poids = POIDS_ISPE,
  libelles_priorite = LIBELLES_PRIORITE
)

# Paramètres nécessaires au simulateur de politiques publiques (arithmétique
# légère dans l'application : aucun recalcul d'ACP ni de classification)
simulation_rds <- list(
  commune    = analyse_commune$simulation,
  prefecture = analyse_prefecture$simulation,
  region     = analyse_region$simulation,
  piliers = PILIERS,
  poids = POIDS_ISPE,
  note = paste("Simulation ceteris paribus : les moyennes, écarts-types et bornes des piliers",
               "sont figés à leur valeur observée ; seuls les indicateurs du territoire simulé varient.")
)
saveRDS(simulation_rds, file.path(CHEMIN_SORTIES, "simulation.rds"))

saveRDS(acp_rds,            file.path(CHEMIN_SORTIES, "acp.rds"))
saveRDS(classification_rds, file.path(CHEMIN_SORTIES, "classification.rds"))
saveRDS(ispe_rds,           file.path(CHEMIN_SORTIES, "ispe.rds"))

message(sprintf("   Communes : %s classes (inertie %s%%) | Préfectures : %s classes",
                classification_rds$parametres$commune$k,
                classification_rds$parametres$commune$inertie_expliquee,
                classification_rds$parametres$prefecture$k))
message("[OK] acp.rds, classification.rds, ispe.rds enregistrés")
