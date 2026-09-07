# =============================================================================
# SAD ÉDUCATION TOGO — global.R
# Chargement des données prétraitées (.rds) et fonctions partagées.
# AUCUN calcul statistique n'est réalisé ici : tout provient du prétraitement.
# =============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(bs4Dash)
  library(bslib)
  library(leaflet)
  library(highcharter)
  library(plotly)
  library(DT)
  library(dplyr)
  library(tidyr)
  library(sf)
  library(htmlwidgets)
  library(writexl)
  library(shinyWidgets)
})

options(shiny.maxRequestSize = 50 * 1024^2, scipen = 999)

# Locale UTF-8 (sans effet si déjà configurée ; évite les soucis d'accents sous Linux minimal)
if (!grepl("UTF-8|utf8", Sys.getlocale("LC_CTYPE"), ignore.case = TRUE)) {
  for (loc in c("C.UTF-8", "en_US.UTF-8", "fr_FR.UTF-8")) {
    ok <- tryCatch(Sys.setlocale("LC_ALL", loc), warning = function(w) "", error = function(e) "")
    if (nzchar(ok)) break
  }
}

# ---- Chargement des fichiers prétraités --------------------------------------
charger <- function(nom) readRDS(file.path("data", nom))

CARTES     <- charger("cartes.rds")
INDIC      <- charger("indicateurs.rds")
ISPE       <- charger("ispe.rds")
CLASSIF    <- charger("classification.rds")
PROFILS    <- charger("profils_classes.rds")
RECO       <- charger("recommandations.rds")
RESNAT     <- charger("resultats_nationaux.rds")
META       <- charger("meta.rds")
BASE       <- charger("base_finale.rds")

DICO <- INDIC$dictionnaire
LIB  <- setNames(DICO$libelle, DICO$variable)

# ---- Couleurs institutionnelles (drapeau du Togo) ------------------------------
TG_VERT   <- "#006A4E"
TG_VERT_F <- "#00563F"
TG_JAUNE  <- "#FFCE00"
TG_ROUGE  <- "#D21034"
TG_BLANC  <- "#FFFFFF"

PAL_PRIORITE <- c("Très prioritaire" = "#C62828",
                  "Prioritaire"      = "#E65100",
                  "À surveiller"     = "#F9A825",
                  "Modéré"           = "#7CB342",
                  "Satisfaisant"     = "#2E7D32")

PAL_SEQ <- c("#f7fcf5", "#c7e9c0", "#74c476", "#238b45", "#00441b")

NIVEAUX_LABELS <- c(region = "Région", prefecture = "Préfecture", commune = "Commune")

# ---- Couches cartographiques enrichies (jointures légères uniquement) ----------
joindre_sf <- function(niveau) {
  couche <- CARTES[[paste0(niveau, "s")]]
  cles <- switch(niveau,
                 region = "region",
                 prefecture = c("region", "prefecture"),
                 commune = c("region", "prefecture", "commune"))
  couche |>
    left_join(INDIC[[niveau]], by = cles, suffix = c("", ".ind")) |>
    left_join(ISPE[[niveau]] |>
                select(all_of(cles), starts_with("deficit_"), starts_with("contrib_"),
                       ispe, rang, niveau_priorite, any_of("classe")),
              by = cles)
}
SF <- list(region = joindre_sf("region"),
           prefecture = joindre_sf("prefecture"),
           commune = joindre_sf("commune"))

nom_terr <- function(df, niveau) df[[niveau]]

# ---- Format ---------------------------------------------------------------------
fmt <- function(x) formatC(x, big.mark = " ", format = "d")
fmt1 <- function(x) formatC(x, big.mark = " ", format = "f", digits = 1)

# ---- Thème highcharter -----------------------------------------------------------
hc_theme_togo <- hc_theme(
  colors = c(TG_VERT, TG_ROUGE, TG_JAUNE, "#1B5E20", "#8D6E63", "#455A64"),
  chart = list(backgroundColor = "transparent",
               style = list(fontFamily = "Arial")),
  title = list(style = list(color = "#1a1a1a", fontWeight = "600", fontSize = "15px")),
  legend = list(itemStyle = list(fontWeight = "normal"))
)

hc_serie_temporelle <- function(df, groupe, titre, unite = "") {
  hchart(df, "line", hcaes(x = annee, y = valeur, group = .data[[groupe]])) |>
    hc_title(text = titre) |>
    hc_yAxis(title = list(text = unite)) |>
    hc_xAxis(title = list(text = NULL)) |>
    hc_tooltip(shared = TRUE, valueDecimals = 1) |>
    hc_add_theme(hc_theme_togo) |>
    hc_credits(enabled = TRUE, text = "Sources : opendata.gouv.tg / UNESCO-ISU")
}

# ---- Cartes leaflet ---------------------------------------------------------------
carte_base <- function() {
  leaflet(options = leafletOptions(minZoom = 6, zoomControl = TRUE)) |>
    addProviderTiles(providers$CartoDB.Positron, group = "Fond clair") |>
    addProviderTiles(providers$OpenStreetMap, group = "OpenStreetMap") |>
    addProviderTiles(providers$Esri.WorldImagery, group = "Satellite") |>
    addLayersControl(baseGroups = c("Fond clair", "OpenStreetMap", "Satellite"),
                     options = layersControlOptions(collapsed = TRUE)) |>
    setView(lng = 1.05, lat = 8.55, zoom = 7)
}

ajouter_choroplethe <- function(carte, couche, variable, titre_legende,
                                palette = PAL_SEQ, niveau = "commune",
                                inverser = FALSE, group = "Territoires") {
  vals <- couche[[variable]]
  pal <- colorBin(if (inverser) rev(palette) else palette, domain = vals,
                  bins = 5, na.color = "#ececec")
  noms <- nom_terr(sf::st_drop_geometry(couche), niveau)
  etiquettes <- sprintf("<strong>%s</strong><br/>%s : %s",
                        noms, titre_legende,
                        ifelse(is.na(vals), "n.d.", fmt1(vals))) |>
    lapply(htmltools::HTML)
  carte |>
    addPolygons(data = couche, fillColor = pal(vals), fillOpacity = 0.75,
                color = TG_BLANC, weight = 1, opacity = 1,
                layerId = paste0("poly_", noms), group = group,
                highlightOptions = highlightOptions(weight = 2.5, color = TG_JAUNE,
                                                    fillOpacity = 0.9, bringToFront = TRUE),
                label = etiquettes) |>
    addLegend(position = "bottomright", pal = pal, values = vals,
              title = titre_legende, opacity = 0.9, na.label = "n.d.")
}

carte_priorite <- function(couche, niveau) {
  pal <- colorFactor(PAL_PRIORITE, levels = names(PAL_PRIORITE))
  noms <- nom_terr(sf::st_drop_geometry(couche), niveau)
  etiquettes <- sprintf(
    "<strong>%s</strong><br/>Score ISPE : %s<br/>Rang national : %s<br/>Priorité : %s",
    noms, couche$ispe, couche$rang, couche$niveau_priorite) |>
    lapply(htmltools::HTML)
  carte_base() |>
    addPolygons(data = couche, fillColor = pal(couche$niveau_priorite),
                fillOpacity = 0.8, color = TG_BLANC, weight = 1,
                layerId = paste0("poly_", noms), group = "Territoires",
                highlightOptions = highlightOptions(weight = 2.5, color = TG_JAUNE,
                                                    fillOpacity = 0.95, bringToFront = TRUE),
                label = etiquettes) |>
    addLegend(position = "bottomright", colors = unname(PAL_PRIORITE),
              labels = names(PAL_PRIORITE), title = "Niveau de priorité", opacity = 0.9)
}

# ---- Export d'images de cartes (graphiques base R, sans ggplot) --------------------
dessiner_carte_statique <- function(couche, variable, titre, sous_titre,
                                    palette = PAL_SEQ, bounds = NULL,
                                    categorielle = FALSE, pal_cat = PAL_PRIORITE,
                                    points = NULL, couleur_points = TG_ROUGE) {
  op <- par(mar = c(1, 1, 4.2, 1), xpd = NA)
  on.exit(par(op), add = TRUE)
  geom <- sf::st_geometry(couche)
  if (categorielle) {
    vals <- factor(couche[[variable]], levels = names(pal_cat))
    couleurs <- unname(pal_cat[as.character(vals)])
    couleurs[is.na(couleurs)] <- "#ececec"
  } else {
    vals <- couche[[variable]]
    brks <- pretty(vals, n = 5)
    fpal <- colorRampPalette(palette)(length(brks) - 1)
    idx <- cut(vals, breaks = brks, include.lowest = TRUE)
    couleurs <- fpal[as.integer(idx)]
    couleurs[is.na(couleurs)] <- "#ececec"
  }
  xlim <- ylim <- NULL
  if (!is.null(bounds)) {
    xlim <- c(bounds$west, bounds$east); ylim <- c(bounds$south, bounds$north)
  }
  plot(geom, col = couleurs, border = "white", lwd = 0.6,
       xlim = xlim, ylim = ylim, main = "", setParUsrBB = TRUE)
  if (!is.null(points) && nrow(points) > 0)
    points(points$lon, points$lat, pch = 16, cex = 0.35,
           col = adjustcolor(couleur_points, 0.55))
  title(main = titre, cex.main = 1.35, font.main = 2, line = 2.4, adj = 0)
  mtext(sous_titre, side = 3, line = 1.1, adj = 0, cex = 0.85, col = "#555555")
  if (categorielle) {
    legend("bottomright", legend = names(pal_cat), fill = unname(pal_cat),
           border = NA, bty = "n", cex = 0.85, title = "Légende")
  } else {
    legend("bottomright", legend = paste(head(brks, -1), "-", tail(brks, -1)),
           fill = fpal, border = NA, bty = "n", cex = 0.85, title = "Légende")
  }
  mtext(sprintf("SAD Éducation Togo — généré le %s — %s", format(Sys.Date(), "%d/%m/%Y"),
                "Sources : geodata.gouv.tg, opendata.gouv.tg, UNESCO-ISU"),
        side = 1, line = -0.4, adj = 0, cex = 0.65, col = "#888888")
}

telecharger_carte <- function(id_format, dessiner, nom_base) {
  downloadHandler(
    filename = function() sprintf("%s_%s.%s", nom_base, format(Sys.Date(), "%Y%m%d"), id_format),
    content = function(file) {
      largeur <- 12; hauteur <- 10
      if (id_format == "png") {
        png(file, width = largeur, height = hauteur, units = "in", res = 300, type = "cairo")
      } else if (id_format == "jpeg") {
        jpeg(file, width = largeur, height = hauteur, units = "in", res = 300, quality = 95, type = "cairo")
      } else {
        grDevices::cairo_pdf(file, width = largeur, height = hauteur)
      }
      tryCatch(dessiner(), finally = dev.off())
    }
  )
}

# ---- Export tableaux ----------------------------------------------------------------
telecharger_tableau <- function(donnees_fun, nom_base, type_fichier) {
  downloadHandler(
    filename = function() sprintf("%s_%s.%s", nom_base, format(Sys.Date(), "%Y%m%d"),
                                  ifelse(type_fichier == "excel", "xlsx", type_fichier)),
    content = function(file) {
      d <- donnees_fun()
      if (type_fichier == "csv") {
        utils::write.csv(d, file, row.names = FALSE, fileEncoding = "UTF-8")
      } else if (type_fichier == "excel") {
        writexl::write_xlsx(d, file)
      }
    }
  )
}

# PDF tabulaire simple (graphiques base R)
pdf_tableau <- function(file, d, titre, max_lignes = 32) {
  grDevices::cairo_pdf(file, width = 11.7, height = 8.3, onefile = TRUE)
  on.exit(dev.off(), add = TRUE)
  d <- as.data.frame(d)
  d[] <- lapply(d, function(x) ifelse(is.na(x), "", as.character(x)))
  pages <- split(seq_len(nrow(d)), ceiling(seq_len(nrow(d)) / max_lignes))
  for (pg in pages) {
    par(mar = c(1, 1, 3, 1))
    plot.new()
    title(main = titre, adj = 0, cex.main = 1.2)
    bloc <- d[pg, , drop = FALSE]
    n_col <- ncol(bloc)
    xs <- seq(0.01, 0.99, length.out = n_col + 1)[-(n_col + 1)]
    ys <- seq(0.95, 0.02, length.out = max_lignes + 1)
    text(xs, 0.985, colnames(bloc), font = 2, cex = 0.62, adj = 0)
    for (i in seq_len(nrow(bloc)))
      text(xs, ys[i], substr(unlist(bloc[i, ]), 1, 34), cex = 0.55, adj = 0)
    mtext(sprintf("SAD Éducation Togo — %s", format(Sys.Date(), "%d/%m/%Y")),
          side = 1, cex = 0.6, col = "#888888")
  }
}

# ---- Divers UI ------------------------------------------------------------------------
boite_valeur <- function(valeur, sujet, icone, couleur = "success") {
  bs4ValueBox(value = tags$h3(valeur, style = "font-weight:700;margin:0;"),
              subtitle = sujet, icon = icon(icone), color = couleur, width = NULL)
}

selecteur_territoires <- function(ns_id, libelle = "Territoires à comparer",
                                  niveau = "prefecture", multiple = TRUE, choix = NULL) {
  if (is.null(choix)) choix <- sort(INDIC[[niveau]][[niveau]])
  pickerInput(ns_id, libelle, choices = choix, multiple = multiple,
              options = pickerOptions(liveSearch = TRUE, actionsBox = TRUE,
                                      noneSelectedText = "Aucune sélection",
                                      selectAllText = "Tout", deselectAllText = "Aucun"))
}

badge_priorite <- function(niveau_priorite) {
  couleur <- PAL_PRIORITE[[niveau_priorite]]
  tags$span(niveau_priorite,
            style = sprintf("background:%s;color:white;padding:4px 12px;border-radius:12px;font-weight:600;", couleur))
}
