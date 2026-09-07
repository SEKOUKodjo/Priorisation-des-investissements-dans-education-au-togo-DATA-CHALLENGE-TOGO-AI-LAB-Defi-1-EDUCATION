# =============================================================================
# SAD ÉDUCATION TOGO — Installation des dépendances
# Usage :  Rscript install_packages.R    (ou source() depuis RStudio)
# =============================================================================

paquets <- c(
  # Prétraitement
  "dplyr", "tidyr", "readr", "sf", "foreign", "jsonlite", "tibble", "cluster",
  # Application
  "shiny", "bs4Dash", "bslib", "leaflet", "highcharter", "plotly", "DT",
  "htmlwidgets", "writexl", "shinyWidgets", "htmltools"
)

manquants <- paquets[!vapply(paquets, requireNamespace, logical(1), quietly = TRUE)]

if (length(manquants) > 0) {
  message("Installation de : ", paste(manquants, collapse = ", "))
  install.packages(manquants, repos = "https://cloud.r-project.org")
} else {
  message("Toutes les dépendances sont déjà installées.")
}

invisible(lapply(paquets, function(p) {
  ok <- requireNamespace(p, quietly = TRUE)
  message(sprintf(" %s %s", ifelse(ok, "[OK]", "[MANQUANT]"), p))
}))
