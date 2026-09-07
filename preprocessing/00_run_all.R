# =============================================================================
# EDUCATION TOGO — Système d'Aide à la Décision pour l'investissement éducatif
# 00_run_all.R — Pipeline complet de prétraitement
#
# Usage :   Rscript preprocessing/00_run_all.R
# (à lancer depuis la racine du projet)
#
# Le pipeline lit data/brutes/ et régénère tous les fichiers .rds dans app/data/.
# L'application Shiny ne fait AUCUN calcul statistique : elle lit ces fichiers.
# =============================================================================

t0 <- Sys.time()
invisible(tryCatch(Sys.setlocale("LC_ALL", "C.UTF-8"),
                   warning = function(w) NULL, error = function(e) NULL))
message("================================================================")
message(" SAD ÉDUCATION TOGO — Prétraitement des données")
message("================================================================")

source("preprocessing/01_fonctions.R")
source("preprocessing/02_import_nettoyage.R")
source("preprocessing/03_cartes.R")
source("preprocessing/04_fusion_indicateurs.R")
source("preprocessing/05_analyses.R")
source("preprocessing/06_profils_recommandations.R")

message("================================================================")
message(sprintf(" Prétraitement terminé en %.1f s — fichiers générés dans app/data/",
                as.numeric(difftime(Sys.time(), t0, units = "secs"))))
message(paste(" -", list.files("app/data", pattern = "\\.rds$"), collapse = "\n"))
message("================================================================")
