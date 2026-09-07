# =============================================================================
# 07_export_python.R — Pont vers l'application Shiny for Python
# Convertit les fichiers .rds en formats lisibles par Python :
#   - CSV  : tableaux d'indicateurs, ISPE, recommandations, séries nationales
#   - GeoJSON : polygones des régions, préfectures et communes
#   - JSON : métadonnées et paramètres du simulateur
# Sortie : app_python/data/
# Usage : Rscript preprocessing/07_export_python.R   (après 00_run_all.R)
# =============================================================================

suppressPackageStartupMessages({ library(dplyr); library(sf); library(jsonlite) })
invisible(tryCatch(Sys.setlocale("LC_ALL", "C.UTF-8"),
                   warning = function(w) NULL, error = function(e) NULL))

ENTREE <- "app/data"; SORTIE <- "app_python/data"
dir.create(SORTIE, recursive = TRUE, showWarnings = FALSE)

lire <- function(f) readRDS(file.path(ENTREE, f))
ecrire_csv <- function(d, nom) utils::write.csv(d, file.path(SORTIE, nom),
                                                row.names = FALSE, fileEncoding = "UTF-8")

message("== Export vers app_python/data/ ==")

# ---- Indicateurs, ISPE, explications, recommandations ------------------------
IND <- lire("indicateurs.rds"); ISPE <- lire("ispe.rds")
RECO <- lire("recommandations.rds"); PROF <- lire("profils_classes.rds")

for (niv in c("region", "prefecture", "commune")) {
  ecrire_csv(IND[[niv]], paste0("indicateurs_", niv, ".csv"))
  ecrire_csv(ISPE[[niv]], paste0("ispe_", niv, ".csv"))
  ecrire_csv(ISPE[[paste0("z_", niv)]], paste0("z_", niv, ".csv"))
  ecrire_csv(RECO[[niv]], paste0("recommandations_", niv, ".csv"))
  ecrire_csv(RECO$explications[[niv]], paste0("explications_", niv, ".csv"))
}
ecrire_csv(IND$dictionnaire, "dictionnaire.csv")
ecrire_csv(bind_rows(PROF$commune, PROF$prefecture), "profils_classes.csv")

# ---- Résultats nationaux -------------------------------------------------------
RES <- lire("resultats_nationaux.rds")
ecrire_csv(RES$series, "resultats_series.csv")
ecrire_csv(RES$uis_infrastructures, "uis_infrastructures.csv")
ecrire_csv(RES$uis_ratio_eleves_maitre, "uis_ratio.csv")

# ---- Cartes ---------------------------------------------------------------------
CARTES <- lire("cartes.rds")
for (niv in c("regions", "prefectures", "communes")) {
  f <- file.path(SORTIE, paste0("carte_", niv, ".geojson"))
  if (file.exists(f)) unlink(f)
  sf::st_write(CARTES[[niv]], f, driver = "GeoJSON", quiet = TRUE)
}
ecrire_csv(CARTES$points_etabs, "points_etablissements.csv")

# ---- Métadonnées & paramètres du simulateur --------------------------------------
writeLines(jsonlite::toJSON(lire("meta.rds"), auto_unbox = TRUE, pretty = TRUE),
           file.path(SORTIE, "meta.json"))

SIM <- lire("simulation.rds")
sim_json <- list(
  poids = as.list(SIM$poids),
  piliers = SIM$piliers,
  niveaux = lapply(SIM[c("commune", "prefecture", "region")], function(x)
    list(stats_variables = x$stats_variables, bornes_piliers = x$bornes_piliers))
)
writeLines(jsonlite::toJSON(sim_json, auto_unbox = TRUE, pretty = TRUE, dataframe = "rows"),
           file.path(SORTIE, "simulation.json"))

message(sprintf("[OK] %s fichiers exportés dans %s",
                length(list.files(SORTIE)), SORTIE))
