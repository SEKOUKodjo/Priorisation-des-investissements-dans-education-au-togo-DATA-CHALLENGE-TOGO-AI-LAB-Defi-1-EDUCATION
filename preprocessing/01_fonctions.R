# =============================================================================
# EDUCATION TOGO — Système d'Aide à la Décision
# 01_fonctions.R — Fonctions utilitaires partagées par le prétraitement
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(sf)
})

CHEMIN_BRUTES  <- "data/brutes"
CHEMIN_SORTIES <- "app/data"
dir.create(CHEMIN_SORTIES, recursive = TRUE, showWarnings = FALSE)

# ---- Nettoyage de chaînes -----------------------------------------------------
nettoyer_texte <- function(x) {
  x <- trimws(as.character(x))
  x[x %in% c("", "Nsp", "N/a", "NA", "Néant", "Neant", "nsp", "n/a")] <- NA_character_
  x
}

# Valeurs "inconnues" conservées comme modalité explicite
recoder_inconnu <- function(x, libelle = "Non renseigné") {
  x <- nettoyer_texte(x)
  ifelse(is.na(x), libelle, x)
}

# ---- Extraction des coordonnées depuis un WKT POINT / MULTIPOLYGON -----------
extraire_lonlat <- function(wkt) {
  m <- regmatches(wkt, regexpr("-?[0-9]+\\.?[0-9]*\\s+-?[0-9]+\\.?[0-9]*", wkt))
  lon <- rep(NA_real_, length(wkt)); lat <- rep(NA_real_, length(wkt))
  ok <- lengths(regmatches(wkt, gregexpr("-?[0-9]", substr(wkt, 1, 1)))) >= 0
  valid <- !is.na(m) & nzchar(m)
  parts <- strsplit(m, "\\s+")
  lon[valid] <- vapply(parts[valid], function(p) as.numeric(p[1]), numeric(1))
  lat[valid] <- vapply(parts[valid], function(p) as.numeric(p[2]), numeric(1))
  data.frame(lon = lon, lat = lat)
}

# Filtre de vraisemblance géographique (emprise du Togo, avec marge)
dans_togo <- function(lon, lat) {
  !is.na(lon) & !is.na(lat) & lon > -0.4 & lon < 2.2 & lat > 5.6 & lat < 11.4
}

# ---- Standardisation ----------------------------------------------------------
zscore <- function(x) {
  s <- sd(x, na.rm = TRUE)
  if (is.na(s) || s == 0) return(rep(0, length(x)))
  (x - mean(x, na.rm = TRUE)) / s
}

minmax_100 <- function(x) {
  rng <- range(x, na.rm = TRUE)
  if (diff(rng) == 0) return(rep(50, length(x)))
  100 * (x - rng[1]) / (rng[2] - rng[1])
}

# Imputation par la médiane du niveau supérieur (préfecture puis national)
imputer_mediane <- function(x, groupe = NULL) {
  if (!is.null(groupe)) {
    med_g <- ave(x, groupe, FUN = function(v) median(v, na.rm = TRUE))
    x[is.na(x)] <- med_g[is.na(x)]
  }
  x[is.na(x)] <- median(x, na.rm = TRUE)
  x
}

# ---- Harmonisation des noms de territoires ------------------------------------
normaliser_nom <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  x <- gsub("[^a-z0-9]+", " ", x)
  trimws(gsub("\\s+", " ", x))
}

# Correspondance inspections pédagogiques -> préfectures
TABLE_INSPECTIONS <- tibble::tribble(
  ~motif_inspection,    ~prefecture,
  "agoenyive",          "Agoè-Nyivé",
  "lome",               "Golfe",
  "agou",               "Agou",
  "akebou",             "Akébou",
  "amou",               "Amou",
  "anie",               "Anié",
  "assoli",             "Assoli",
  "ave",                "Avé",
  "bas mono",           "Bas-Mono",
  "bassar",             "Bassar",
  "binah",              "Binah",
  "blitta",             "Blitta",
  "cinkasse",           "Cinkassé",
  "dankpen",            "Dankpen",
  "danyi",              "Danyi",
  "doufelgou",          "Doufelgou",
  "est mono",           "Est-Mono",
  "haho",               "Haho",
  "keran",              "Kéran",
  "kloto",              "Kloto",
  "kozah",              "Kozah",
  "kpele",              "Kpélé",
  "kpendjal",           "Kpendjal",
  "lacs",               "Lacs",
  "mo",                 "Mô",
  "moyen mono",         "Moyen-Mono",
  "ogou",               "Ogou",
  "oti sud",            "Oti-Sud",
  "oti",                "Oti",
  "sotouboua",          "Sotouboua",
  "tandjoare",          "Tandjoaré",
  "tchamba",            "Tchamba",
  "tchaoudjo",          "Tchaoudjo",
  "tone",               "Tône",
  "vo",                 "Vo",
  "wawa",               "Wawa",
  "yoto",               "Yoto",
  "zio",                "Zio"
)

inspection_vers_prefecture <- function(noms_inspection) {
  cle <- normaliser_nom(noms_inspection)
  res <- rep(NA_character_, length(cle))
  # motifs les plus longs d'abord pour éviter "mo" avant "moyen mono"
  tbl <- TABLE_INSPECTIONS[order(-nchar(TABLE_INSPECTIONS$motif_inspection)), ]
  for (i in seq_len(nrow(tbl))) {
    hit <- is.na(res) & grepl(paste0("^", tbl$motif_inspection[i], "( |$)"), cle)
    res[hit] <- tbl$prefecture[i]
  }
  res
}

message("[OK] Fonctions utilitaires chargées")
