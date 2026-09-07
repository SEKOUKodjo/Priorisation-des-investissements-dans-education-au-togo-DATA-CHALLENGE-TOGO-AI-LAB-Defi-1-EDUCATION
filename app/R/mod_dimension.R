# =============================================================================
# mod_dimension.R — Module générique des pages Couverture scolaire,
# Infrastructures essentielles et Capacité enseignante.
# Chaque page : Indicateurs | Cartographie | Comparaison | Exports
# =============================================================================

CONFIG_DIM <- list(
  couverture = list(
    titre = "Couverture scolaire", icone = "school",
    variables_carte = c("Nombre d'établissements" = "nb_etab",
                        "Établissements pour 100 km²" = "densite_etab_100km2",
                        "Complétude du cycle éducatif (%)" = "completude_offre",
                        "Jardins d'enfants pour 100 primaires" = "jardins_100_primaires",
                        "Écoles primaires" = "nb_primaire",
                        "Collèges" = "nb_college",
                        "Lycées" = "nb_lycee",
                        "Crèches recensées" = "nb_creches"),
    variables_comparaison = c("nb_etab", "densite_etab_100km2", "completude_offre",
                              "jardins_100_primaires", "nb_prescolaire", "nb_primaire",
                              "nb_college", "nb_lycee"),
    couche_points = "points_etabs"
  ),
  infrastructures = list(
    titre = "Infrastructures essentielles", icone = "building",
    variables_carte = c("Toilettes pour 100 établissements" = "toilettes_100_etab",
                        "Toilettes améliorées (%)" = "pct_toilettes_ameliorees",
                        "Bâtiments récents - depuis 2010 (%)" = "pct_batiments_recents",
                        "Bâtiments par établissement" = "batiments_par_etab",
                        "Terrains de sport (%)" = "pct_terrain_sport",
                        "Bibliothèques pour 100 établissements" = "biblio_100_etab"),
    variables_comparaison = c("toilettes_100_etab", "pct_toilettes_ameliorees",
                              "pct_batiments_recents", "batiments_par_etab",
                              "pct_terrain_sport", "biblio_100_etab"),
    couche_points = "points_toilettes"
  ),
  enseignants = list(
    titre = "Capacité enseignante", icone = "chalkboard-user",
    variables_carte = c("Enseignants du préscolaire" = "enseignants_prescolaire",
                        "Enseignants pour 100 jardins d'enfants" = "ens_100_jardins",
                        "Enseignants pour 100 établissements" = "enseignants_100_etab"),
    variables_comparaison = c("enseignants_prescolaire", "ens_100_jardins",
                              "enseignants_100_etab", "nb_prescolaire"),
    couche_points = "points_etabs"
  )
)

mod_dimension_ui <- function(id) {
  ns <- NS(id)
  cfg <- CONFIG_DIM[[id]]

  tagList(
    fluidRow(
      column(3, bs4ValueBoxOutput(ns("kpi1"), width = NULL)),
      column(3, bs4ValueBoxOutput(ns("kpi2"), width = NULL)),
      column(3, bs4ValueBoxOutput(ns("kpi3"), width = NULL)),
      column(3, bs4ValueBoxOutput(ns("kpi4"), width = NULL))
    ),
    bs4TabCard(
      id = ns("onglets"), width = 12, collapsible = FALSE, maximizable = TRUE,
      status = "success", solidHeader = FALSE, type = "tabs", side = "right",
      title = tags$span(icon(cfg$icone), " ", cfg$titre),

      tabPanel(
        title = tagList(icon("chart-column"), "Indicateurs"),
        fluidRow(
          column(4,
                 radioGroupButtons(ns("niveau_ind"), "Échelon territorial",
                                   choices = c("Région" = "region", "Préfecture" = "prefecture",
                                               "Commune" = "commune"),
                                   selected = "prefecture", status = "success", justified = TRUE))
        ),
        fluidRow(
          column(6, highchartOutput(ns("graphique1"), height = 380)),
          column(6, highchartOutput(ns("graphique2"), height = 380))
        ),
        tags$hr(),
        DTOutput(ns("table_indicateurs"))
      ),

      tabPanel(
        title = tagList(icon("map-location-dot"), "Cartographie"),
        fluidRow(
          column(3,
                 selectInput(ns("var_carte"), "Indicateur cartographié",
                             choices = cfg$variables_carte, width = "100%"),
                 radioGroupButtons(ns("niveau_carte"), "Maille",
                                   choices = c("Région" = "region", "Préfecture" = "prefecture",
                                               "Commune" = "commune"),
                                   selected = "commune", status = "success", justified = TRUE),
                 pickerInput(ns("filtre_region"), "Filtrer par région",
                             choices = sort(unique(INDIC$commune$region)), multiple = TRUE,
                             options = pickerOptions(actionsBox = TRUE, liveSearch = TRUE,
                                                     noneSelectedText = "Tout le Togo")),
                 selectizeInput(ns("recherche"), "Rechercher un territoire",
                                choices = NULL, options = list(placeholder = "Nom du territoire...")),
                 materialSwitch(ns("montrer_points"), "Afficher les établissements",
                                value = FALSE, status = "success"),
                 tags$hr(),
                 tags$b("Télécharger la carte affichée"),
                 tags$p(class = "text-muted", style = "font-size:12px;",
                        "Conserve le zoom, les filtres, la légende et le titre."),
                 div(class = "btn-group-vertical", style = "width:100%;",
                     downloadButton(ns("dl_png"), "PNG haute résolution", class = "btn-outline-success btn-sm"),
                     downloadButton(ns("dl_pdf"), "PDF", class = "btn-outline-success btn-sm"),
                     downloadButton(ns("dl_jpeg"), "JPEG", class = "btn-outline-success btn-sm"))
          ),
          column(9, leafletOutput(ns("carte"), height = 620))
        )
      ),

      tabPanel(
        title = tagList(icon("scale-balanced"), "Comparaison"),
        fluidRow(
          column(4,
                 radioGroupButtons(ns("niveau_comp"), "Échelon",
                                   choices = c("Région" = "region", "Préfecture" = "prefecture",
                                               "Commune" = "commune"),
                                   selected = "prefecture", status = "success", justified = TRUE),
                 uiOutput(ns("choix_comparaison"))),
          column(8, plotlyOutput(ns("radar"), height = 420))
        ),
        tags$hr(),
        highchartOutput(ns("barres_comparaison"), height = 380),
        DTOutput(ns("table_comparaison"))
      ),

      tabPanel(
        title = tagList(icon("download"), "Export"),
        fluidRow(
          column(4,
                 radioGroupButtons(ns("niveau_export"), "Échelon à exporter",
                                   choices = c("Région" = "region", "Préfecture" = "prefecture",
                                               "Commune" = "commune"),
                                   selected = "commune", status = "success", justified = TRUE),
                 tags$p(class = "text-muted", "Le fichier contient tous les indicateurs de la dimension."),
                 div(class = "btn-group-vertical", style = "width:100%;",
                     downloadButton(ns("dl_excel"), "Excel (.xlsx)", class = "btn-success"),
                     downloadButton(ns("dl_csv"), "CSV", class = "btn-outline-success"),
                     downloadButton(ns("dl_pdf_tab"), "PDF", class = "btn-outline-success"))),
          column(8, DTOutput(ns("apercu_export")))
        )
      )
    )
  )
}

mod_dimension_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    cfg <- CONFIG_DIM[[id]]
    vars_dim <- intersect(unique(c(cfg$variables_comparaison, unname(cfg$variables_carte))),
                          names(INDIC$commune))

    # ---------------- KPIs ----------------
    output$kpi1 <- renderbs4ValueBox({
      switch(id,
        couverture = boite_valeur(fmt(META$nb_etablissements), "Établissements scolaires", "school", "success"),
        infrastructures = boite_valeur(fmt(META$nb_toilettes), "Points de toilettes recensés", "restroom", "success"),
        enseignants = boite_valeur(fmt(META$nb_enseignants_prescolaire), "Enseignants du préscolaire", "chalkboard-user", "success"))
    })
    output$kpi2 <- renderbs4ValueBox({
      switch(id,
        couverture = boite_valeur(fmt(sum(INDIC$commune$nb_primaire)), "Écoles primaires", "children", "primary"),
        infrastructures = boite_valeur(fmt(META$nb_batiments), "Bâtiments scolaires", "building", "primary"),
        enseignants = boite_valeur(fmt1(median(INDIC$prefecture$ens_100_jardins, na.rm = TRUE)),
                                   "Enseignants / 100 jardins (médiane)", "users", "primary"))
    })
    output$kpi3 <- renderbs4ValueBox({
      switch(id,
        couverture = boite_valeur(paste0(fmt1(mean(INDIC$commune$completude_offre)), " %"),
                                  "Complétude moyenne du cycle", "layer-group", "warning"),
        infrastructures = boite_valeur(paste0(fmt1(mean(INDIC$commune$pct_toilettes_ameliorees, na.rm = TRUE)), " %"),
                                       "Toilettes améliorées (moyenne)", "droplet", "warning"),
        enseignants = boite_valeur(fmt(sum(INDIC$commune$nb_prescolaire)), "Jardins d'enfants", "shapes", "warning"))
    })
    output$kpi4 <- renderbs4ValueBox({
      switch(id,
        couverture = boite_valeur(fmt(META$nb_communes), "Communes couvertes", "map", "danger"),
        infrastructures = boite_valeur(paste0(fmt1(mean(INDIC$commune$pct_terrain_sport, na.rm = TRUE)), " %"),
                                       "Établissements avec terrain de sport", "futbol", "danger"),
        enseignants = boite_valeur(
          fmt(sum(INDIC$prefecture$ens_100_jardins < quantile(INDIC$prefecture$ens_100_jardins, .25, na.rm = TRUE), na.rm = TRUE)),
          "Préfectures sous-dotées (quartile inférieur)", "triangle-exclamation", "danger"))
    })

    # ---------------- Indicateurs : graphiques ----------------
    donnees_niveau <- reactive(INDIC[[input$niveau_ind]])

    output$graphique1 <- renderHighchart({
      d <- donnees_niveau(); niv <- input$niveau_ind
      if (id == "couverture") {
        rep_cat <- BASE$etablissements |> count(categorie)
        hchart(rep_cat, "pie", hcaes(name = categorie, y = n), name = "Établissements") |>
          hc_title(text = "Répartition nationale par type d'établissement") |>
          hc_add_theme(hc_theme_togo)
      } else if (id == "infrastructures") {
        d2 <- RESNAT$uis_infrastructures |>
          filter(grepl("lectrifi", indicateur)) |> arrange(annee)
        hc_serie_temporelle(d2, "indicateur", "Électrification des établissements (national, UNESCO-ISU)", "%")
      } else {
        d2 <- BASE$enseignants_sexe |> group_by(sexe) |> summarise(enseignants = sum(enseignants))
        hchart(d2, "pie", hcaes(name = sexe, y = enseignants), name = "Enseignants") |>
          hc_title(text = "Enseignants du préscolaire par sexe (2021-2022)") |>
          hc_add_theme(hc_theme_togo)
      }
    })

    output$graphique2 <- renderHighchart({
      d <- donnees_niveau(); niv <- input$niveau_ind
      var <- switch(id, couverture = "nb_etab", infrastructures = "toilettes_100_etab",
                    enseignants = "ens_100_jardins")
      titre <- switch(id,
        couverture = "Répartition territoriale des établissements",
        infrastructures = "Toilettes pour 100 établissements par territoire",
        enseignants = "Encadrement préscolaire par territoire")
      d <- d |> arrange(desc(.data[[var]])) |> head(20) |>
        mutate(territoire = .data[[niv]], valeur = .data[[var]])
      hchart(d, "bar", hcaes(x = territoire, y = valeur), name = LIB[[var]],
             color = TG_VERT) |>
        hc_title(text = paste0(titre, if (nrow(donnees_niveau()) > 20) " (top 20)" else "")) |>
        hc_xAxis(title = list(text = NULL)) |>
        hc_yAxis(title = list(text = LIB[[var]])) |>
        hc_add_theme(hc_theme_togo)
    })

    output$table_indicateurs <- renderDT({
      niv <- input$niveau_ind
      cles <- intersect(c("region", "prefecture", "commune"), names(donnees_niveau()))
      d <- donnees_niveau()[, c(cles, vars_dim)]
      colnames(d) <- c(NIVEAUX_LABELS[cles], unname(LIB[vars_dim]))
      datatable(d, rownames = FALSE, extensions = "Buttons",
                options = list(pageLength = 10, scrollX = TRUE, dom = "ftip"),
                class = "table-striped compact") |>
        formatStyle(columns = seq_along(d), fontSize = "13px")
    })

    # ---------------- Cartographie ----------------
    couche_carte <- reactive({
      couche <- SF[[input$niveau_carte]]
      if (length(input$filtre_region) > 0) couche <- couche |> filter(region %in% input$filtre_region)
      couche
    })

    observe({
      noms <- sort(nom_terr(sf::st_drop_geometry(couche_carte()), input$niveau_carte))
      updateSelectizeInput(session, "recherche", choices = c("", noms), server = TRUE)
    })

    output$carte <- renderLeaflet({
      couche <- couche_carte()
      lib_var <- names(cfg$variables_carte)[cfg$variables_carte == input$var_carte]
      m <- carte_base() |>
        ajouter_choroplethe(couche, input$var_carte, lib_var, niveau = input$niveau_carte)
      if (isTRUE(input$montrer_points)) {
        pts <- CARTES[[cfg$couche_points]]
        if (length(input$filtre_region) > 0) pts <- pts |> filter(region %in% input$filtre_region)
        if (nrow(pts) > 0)
          m <- m |> addCircleMarkers(data = pts, lng = ~lon, lat = ~lat, radius = 2.5,
                                     stroke = FALSE, fillOpacity = 0.55, fillColor = TG_ROUGE,
                                     clusterOptions = markerClusterOptions(maxClusterRadius = 45),
                                     label = if ("nom" %in% names(pts)) ~nom else NULL,
                                     group = "Établissements")
      }
      m
    })

    observeEvent(input$recherche, {
      req(nzchar(input$recherche))
      couche <- couche_carte()
      sel <- couche[nom_terr(sf::st_drop_geometry(couche), input$niveau_carte) == input$recherche, ]
      req(nrow(sel) == 1)
      bb <- as.numeric(sf::st_bbox(sel))
      leafletProxy("carte") |> fitBounds(bb[1], bb[2], bb[3], bb[4])
    })

    dessin_courant <- function() {
      couche <- couche_carte()
      lib_var <- names(cfg$variables_carte)[cfg$variables_carte == input$var_carte]
      filtres <- if (length(input$filtre_region) > 0)
        paste("Régions :", paste(input$filtre_region, collapse = ", ")) else "Ensemble du territoire national"
      pts <- NULL
      if (isTRUE(input$montrer_points)) {
        pts <- CARTES[[cfg$couche_points]]
        if (length(input$filtre_region) > 0) pts <- pts |> filter(region %in% input$filtre_region)
      }
      function() dessiner_carte_statique(
        couche, input$var_carte,
        titre = sprintf("%s — %s", cfg$titre, lib_var),
        sous_titre = sprintf("%s · Maille : %s", filtres, NIVEAUX_LABELS[[input$niveau_carte]]),
        bounds = input$carte_bounds, points = pts)
    }
    output$dl_png  <- telecharger_carte("png",  function() dessin_courant()(), paste0("carte_", id))
    output$dl_pdf  <- telecharger_carte("pdf",  function() dessin_courant()(), paste0("carte_", id))
    output$dl_jpeg <- telecharger_carte("jpeg", function() dessin_courant()(), paste0("carte_", id))

    # ---------------- Comparaison ----------------
    output$choix_comparaison <- renderUI({
      selecteur_territoires(ns("territoires_comp"), niveau = input$niveau_comp)
    })

    donnees_comp <- reactive({
      req(input$territoires_comp)
      niv <- input$niveau_comp
      INDIC[[niv]] |> filter(.data[[niv]] %in% input$territoires_comp)
    })

    output$radar <- renderPlotly({
      d <- donnees_comp(); niv <- input$niveau_comp
      req(nrow(d) > 0)
      ens <- INDIC[[niv]]
      fig <- plot_ly(type = "scatterpolar", mode = "lines+markers", fill = "toself")
      for (i in seq_len(nrow(d))) {
        vals <- vapply(cfg$variables_comparaison, function(v) {
          x <- ens[[v]]; r <- rank(x, ties.method = "average") / length(x) * 100
          r[which(nom_terr(ens, niv) == nom_terr(d, niv)[i])]
        }, numeric(1))
        fig <- fig |> add_trace(r = c(vals, vals[1]),
                                theta = c(unname(LIB[cfg$variables_comparaison]),
                                          LIB[[cfg$variables_comparaison[1]]]),
                                name = nom_terr(d, niv)[i], opacity = 0.6)
      }
      fig |> layout(polar = list(radialaxis = list(range = c(0, 100), ticksuffix = "")),
                    legend = list(orientation = "h"),
                    margin = list(t = 30),
                    title = list(text = "Positionnement relatif (percentile national)", font = list(size = 14)))
    })

    output$barres_comparaison <- renderHighchart({
      d <- donnees_comp(); niv <- input$niveau_comp
      req(nrow(d) > 0)
      dl <- d |> select(all_of(c(niv, cfg$variables_comparaison))) |>
        pivot_longer(-all_of(niv), names_to = "variable", values_to = "valeur") |>
        mutate(variable = unname(LIB[variable]), territoire = .data[[niv]])
      hchart(dl, "column", hcaes(x = variable, y = valeur, group = territoire)) |>
        hc_title(text = "Comparaison des indicateurs (valeurs brutes)") |>
        hc_xAxis(title = list(text = NULL)) |> hc_yAxis(title = list(text = NULL)) |>
        hc_add_theme(hc_theme_togo)
    })

    output$table_comparaison <- renderDT({
      d <- donnees_comp(); niv <- input$niveau_comp
      cles <- intersect(c("region", "prefecture", "commune"), names(d))
      dd <- d[, c(cles, cfg$variables_comparaison)]
      colnames(dd) <- c(NIVEAUX_LABELS[cles], unname(LIB[cfg$variables_comparaison]))
      datatable(dd, rownames = FALSE, options = list(dom = "t", scrollX = TRUE),
                class = "table-striped compact")
    })

    # ---------------- Exports ----------------
    donnees_export <- reactive({
      niv <- input$niveau_export
      cles <- intersect(c("region", "prefecture", "commune"), names(INDIC[[niv]]))
      d <- INDIC[[niv]][, c(cles, vars_dim)]
      colnames(d) <- c(NIVEAUX_LABELS[cles], unname(LIB[vars_dim]))
      d
    })
    output$apercu_export <- renderDT(
      datatable(donnees_export(), rownames = FALSE,
                options = list(pageLength = 8, scrollX = TRUE, dom = "tip"),
                class = "table-striped compact"))
    output$dl_excel <- telecharger_tableau(donnees_export, paste0(id, "_indicateurs"), "excel")
    output$dl_csv   <- telecharger_tableau(donnees_export, paste0(id, "_indicateurs"), "csv")
    output$dl_pdf_tab <- downloadHandler(
      filename = function() sprintf("%s_indicateurs_%s.pdf", id, format(Sys.Date(), "%Y%m%d")),
      content = function(file) pdf_tableau(file, donnees_export(),
                                           paste("SAD Éducation Togo —", cfg$titre)))
  })
}
