# =============================================================================
# mod_priorisation.R — Module principal : Priorisation des investissements
# Vue nationale | Fiche territoire | Résultats scolaires | Comparaison
# ACP / HCPC / K-means / ISPE calculés en amont : ici, uniquement de la lecture.
# =============================================================================

mod_priorisation_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(3, bs4ValueBoxOutput(ns("kpi_tres_prior"), width = NULL)),
      column(3, bs4ValueBoxOutput(ns("kpi_ispe_moyen"), width = NULL)),
      column(3, bs4ValueBoxOutput(ns("kpi_classes"), width = NULL)),
      column(3, bs4ValueBoxOutput(ns("kpi_reussite"), width = NULL))
    ),
    bs4TabCard(
      id = ns("onglets"), width = 12, collapsible = FALSE, maximizable = TRUE,
      status = "danger", type = "tabs", side = "right",
      title = tags$span(icon("ranking-star"), " Priorisation des investissements"),

      # ---------------- Vue nationale ----------------
      tabPanel(
        title = tagList(icon("flag"), "Vue nationale"),
        fluidRow(
          column(3,
                 radioGroupButtons(ns("niveau_nat"), "Maille d'analyse",
                                   choices = c("Région" = "region", "Préfecture" = "prefecture",
                                               "Commune" = "commune"),
                                   selected = "commune", status = "success", justified = TRUE),
                 tags$div(class = "encart-explication", style = "font-size:13px;",
                          HTML(paste0("<b>ISPE</b> — Indice Synthétique de Priorité Éducative (0-100). ",
                                      "Plus le score est élevé, plus le territoire est prioritaire. ",
                                      "Il agrège les déficits de couverture scolaire (30%), d'infrastructures (30%), ",
                                      "de capacité enseignante (25%) et de conditions de réussite scolaire (15%)."))),
                 tags$hr(),
                 downloadButton(ns("dl_carte_png"), "Télécharger la carte (PNG)",
                                class = "btn-outline-success btn-sm btn-block"),
                 tags$hr(),
                 highchartOutput(ns("donut_priorites"), height = 260)),
          column(5, leafletOutput(ns("carte_priorites"), height = 640)),
          column(4,
                 tags$b("Classement national"),
                 DTOutput(ns("classement")))
        )
      ),

      # ---------------- Fiche territoire ----------------
      tabPanel(
        title = tagList(icon("magnifying-glass-location"), "Fiche territoire"),
        fluidRow(
          column(3,
                 radioGroupButtons(ns("niveau_fiche"), "Échelon",
                                   choices = c("Région" = "region", "Préfecture" = "prefecture",
                                               "Commune" = "commune"),
                                   selected = "commune", status = "success", justified = TRUE),
                 pickerInput(ns("region_fiche"), "Région", choices = sort(INDIC$region$region),
                             options = pickerOptions(liveSearch = TRUE)),
                 conditionalPanel(sprintf("input['%s'] != 'region'", ns("niveau_fiche")),
                                  pickerInput(ns("prefecture_fiche"), "Préfecture", choices = NULL,
                                              options = pickerOptions(liveSearch = TRUE))),
                 conditionalPanel(sprintf("input['%s'] == 'commune'", ns("niveau_fiche")),
                                  pickerInput(ns("commune_fiche"), "Commune", choices = NULL,
                                              options = pickerOptions(liveSearch = TRUE))),
                 tags$hr(),
                 tags$b("Exporter"),
                 div(class = "btn-group-vertical", style = "width:100%;",
                     downloadButton(ns("dl_fiche_pdf"), "Fiche synthétique (PDF)", class = "btn-success btn-sm"),
                     downloadButton(ns("dl_fiche_excel"), "Données (Excel)", class = "btn-outline-success btn-sm"),
                     downloadButton(ns("dl_fiche_csv"), "Données (CSV)", class = "btn-outline-success btn-sm"),
                     downloadButton(ns("dl_fiche_carte"), "Carte du territoire (PNG)", class = "btn-outline-success btn-sm"))),
          column(9,
                 fluidRow(
                   column(4, bs4Card(width = NULL, collapsible = FALSE, status = "success",
                                     title = "Score ISPE",
                                     uiOutput(ns("fiche_score")))),
                   column(8, bs4Card(width = NULL, collapsible = FALSE, status = "success",
                                     title = "Profil du territoire (classe HCPC)",
                                     uiOutput(ns("fiche_classe"))))
                 ),
                 bs4Card(width = NULL, collapsible = FALSE, status = "success",
                         title = tagList(icon("circle-info"), "Pourquoi ce classement ?"),
                         uiOutput(ns("fiche_explication")),
                         fluidRow(
                           column(6, uiOutput(ns("fiche_forces"))),
                           column(6, uiOutput(ns("fiche_faiblesses")))
                         ),
                         highchartOutput(ns("fiche_contributions"), height = 240)),
                 bs4Card(width = NULL, collapsible = FALSE, status = "danger",
                         title = tagList(icon("lightbulb"), "Recommandations d'investissement"),
                         DTOutput(ns("fiche_recommandations"))))
        )
      ),

      # ---------------- Résultats scolaires ----------------
      tabPanel(
        title = tagList(icon("graduation-cap"), "Résultats scolaires"),
        fluidRow(
          column(6, highchartOutput(ns("res_reussite"), height = 360)),
          column(6, highchartOutput(ns("res_evolution"), height = 360))
        ),
        fluidRow(
          column(6, highchartOutput(ns("res_achevement"), height = 360)),
          column(6, highchartOutput(ns("res_contribution"), height = 360))
        ),
        tags$div(class = "encart-alerte", style = "margin-top:8px;font-size:13px;",
                 HTML(paste0("<b>Note méthodologique.</b> Les résultats d'examens ne sont publiés qu'à ",
                             "l'échelle nationale dans les données ouvertes. Au niveau territorial, la dimension ",
                             "« résultats scolaires » de l'ISPE mobilise un indice de conditions de réussite ",
                             "(encadrement, complétude du cycle, hygiène, état du bâti), présenté ci-dessus ",
                             "(contribution au score ISPE par territoire).")))
      ),

      # ---------------- Simulateur de politiques publiques ----------------
      tabPanel(
        title = tagList(icon("wand-magic-sparkles"), "Simulateur"),
        mod_simulateur_ui(ns("simulateur"))
      ),

      # ---------------- Comparaison ----------------
      tabPanel(
        title = tagList(icon("scale-balanced"), "Comparaison"),
        fluidRow(
          column(4,
                 radioGroupButtons(ns("niveau_comp"), "Échelon",
                                   choices = c("Région" = "region", "Préfecture" = "prefecture",
                                               "Commune" = "commune"),
                                   selected = "prefecture", status = "success", justified = TRUE),
                 uiOutput(ns("choix_comp"))),
          column(8, plotlyOutput(ns("radar_piliers"), height = 420))
        ),
        highchartOutput(ns("barres_ispe"), height = 320),
        DTOutput(ns("table_comp"))
      )
    )
  )
}

mod_priorisation_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    mod_simulateur_server("simulateur")

    LIB_PILIERS_APP <- c(deficit_couverture = "Couverture scolaire",
                         deficit_infrastructures = "Infrastructures essentielles",
                         deficit_enseignants = "Capacité enseignante",
                         deficit_resultats = "Conditions de réussite scolaire")

    # ---------------- KPIs ----------------
    output$kpi_tres_prior <- renderbs4ValueBox(
      boite_valeur(fmt(sum(ISPE$commune$niveau_priorite == "Très prioritaire")),
                   "Communes très prioritaires", "triangle-exclamation", "danger"))
    output$kpi_ispe_moyen <- renderbs4ValueBox(
      boite_valeur(fmt1(mean(ISPE$commune$ispe)), "Score ISPE moyen (communes)", "gauge-high", "success"))
    output$kpi_classes <- renderbs4ValueBox(
      boite_valeur(length(unique(na.omit(ISPE$commune$classe))),
                   "Profils de territoires identifiés", "layer-group", "primary"))
    output$kpi_reussite <- renderbs4ValueBox({
      r <- RESNAT$reussite |> filter(niveau == "Primaire", secteur == "Total") |> arrange(desc(annee))
      boite_valeur(paste0(fmt1(r$valeur[1]), " %"),
                   sprintf("Réussite examen de compétence, primaire (%s)", r$annee[1]),
                   "graduation-cap", "warning")
    })

    # ---------------- Vue nationale ----------------
    output$carte_priorites <- renderLeaflet(carte_priorite(SF[[input$niveau_nat]], input$niveau_nat))

    output$donut_priorites <- renderHighchart({
      d <- ISPE[[input$niveau_nat]] |> count(niveau_priorite) |>
        mutate(niveau_priorite = factor(niveau_priorite, levels = names(PAL_PRIORITE))) |>
        arrange(niveau_priorite)
      hchart(d, "pie", hcaes(name = niveau_priorite, y = n),
             name = "Territoires", innerSize = "55%") |>
        hc_colors(unname(PAL_PRIORITE[as.character(d$niveau_priorite)])) |>
        hc_title(text = "Répartition par niveau de priorité", style = list(fontSize = "13px")) |>
        hc_add_theme(hc_theme_togo)
    })

    output$classement <- renderDT({
      niv <- input$niveau_nat
      d <- ISPE[[niv]] |> arrange(rang)
      cles <- intersect(c("region", "prefecture", "commune"), names(d))
      dd <- d[, c("rang", cles, "ispe", "niveau_priorite")]
      colnames(dd) <- c("Rang", NIVEAUX_LABELS[cles], "ISPE", "Priorité")
      datatable(dd, rownames = FALSE,
                options = list(pageLength = 12, dom = "ftip", scrollX = TRUE),
                class = "table-striped compact") |>
        formatStyle("Priorité", backgroundColor = styleEqual(names(PAL_PRIORITE), unname(PAL_PRIORITE)),
                    color = "white", fontWeight = "600")
    })

    output$dl_carte_png <- telecharger_carte("png", function() {
      dessiner_carte_statique(SF[[input$niveau_nat]], "niveau_priorite",
                              titre = "Carte nationale des priorités éducatives",
                              sous_titre = sprintf("Maille : %s — Indice Synthétique de Priorité Éducative",
                                                   NIVEAUX_LABELS[[input$niveau_nat]]),
                              categorielle = TRUE)
    }, "carte_priorites_nationale")

    # ---------------- Fiche territoire ----------------
    observeEvent(input$region_fiche, {
      prefs <- sort(unique(INDIC$prefecture$prefecture[INDIC$prefecture$region == input$region_fiche]))
      updatePickerInput(session, "prefecture_fiche", choices = prefs)
    })
    observeEvent(input$prefecture_fiche, {
      comms <- sort(unique(INDIC$commune$commune[INDIC$commune$prefecture == input$prefecture_fiche]))
      updatePickerInput(session, "commune_fiche", choices = comms)
    })

    territoire <- reactive({
      niv <- input$niveau_fiche
      nom <- switch(niv, region = input$region_fiche,
                    prefecture = input$prefecture_fiche, commune = input$commune_fiche)
      req(nom)
      list(niveau = niv, nom = nom)
    })

    fiche <- reactive({
      t <- territoire()
      expl <- RECO$explications[[t$niveau]]
      ligne <- expl[expl[[t$niveau]] == t$nom, ]
      req(nrow(ligne) == 1)
      ligne
    })

    fiche_ispe <- reactive({
      t <- territoire()
      d <- ISPE[[t$niveau]]
      d[d[[t$niveau]] == t$nom, ]
    })

    output$fiche_score <- renderUI({
      f <- fiche(); n_total <- nrow(ISPE[[territoire()$niveau]])
      tagList(
        tags$div(class = "fiche-ispe", f$ispe),
        tags$div(class = "fiche-rang", sprintf("Rang %s sur %s au niveau national", f$rang, n_total)),
        tags$div(style = "margin-top:10px;", badge_priorite(f$niveau_priorite))
      )
    })

    output$fiche_classe <- renderUI({
      f <- fiche()
      tagList(
        tags$h5(style = "font-weight:700;color:#00563F;margin-top:0;",
                if (is.na(f$classe)) "Échelon régional — profil hérité des communes" else f$libelle_classe),
        {
          profs <- PROFILS[[territoire()$niveau]]
          if (!is.null(profs) && !is.na(f$classe)) {
            p <- profs[profs$classe == f$classe, ]
            tags$p(style = "font-size:13.5px;color:#444;", p$description,
                   tags$br(),
                   tags$span(style = "color:#888;font-size:12.5px;",
                             sprintf("%s territoires partagent ce profil (ISPE moyen : %s).",
                                     p$effectif, p$ispe_moyen)))
          } else NULL
        }
      )
    })

    output$fiche_explication <- renderUI({
      tags$div(class = "encart-explication", fiche()$explication)
    })

    output$fiche_forces <- renderUI({
      pts <- strsplit(fiche()$points_forts, "\\|")[[1]]
      tagList(tags$b(style = "color:#2E7D32;", icon("circle-check"), " Points forts"),
              tags$ul(class = "liste-points", lapply(pts, tags$li)))
    })
    output$fiche_faiblesses <- renderUI({
      pts <- strsplit(fiche()$points_faibles, "\\|")[[1]]
      tagList(tags$b(style = "color:#C62828;", icon("circle-exclamation"), " Insuffisances"),
              tags$ul(class = "liste-points", lapply(pts, tags$li)))
    })

    output$fiche_contributions <- renderHighchart({
      f <- fiche_ispe()
      d <- tibble(pilier = unname(LIB_PILIERS_APP),
                  contribution = as.numeric(f[, sub("deficit_", "contrib_", names(LIB_PILIERS_APP))]))
      hchart(d, "bar", hcaes(x = pilier, y = contribution), name = "Contribution (%)",
             color = TG_VERT) |>
        hc_title(text = "Contribution des quatre dimensions au score ISPE",
                 style = list(fontSize = "13px")) |>
        hc_yAxis(title = list(text = "%"), max = 60) |>
        hc_xAxis(title = list(text = NULL)) |>
        hc_add_theme(hc_theme_togo)
    })

    recos_territoire <- reactive({
      t <- territoire()
      r <- RECO[[t$niveau]]
      r[r[[t$niveau]] == t$nom, c("ordre", "action", "dimension", "impact_attendu", "confiance", "justification")]
    })

    output$fiche_recommandations <- renderDT({
      d <- recos_territoire()
      colnames(d) <- c("Ordre", "Investissement recommandé", "Dimension", "Impact attendu",
                       "Confiance (%)", "Justification")
      datatable(d, rownames = FALSE, options = list(dom = "t", scrollX = TRUE, ordering = FALSE),
                class = "table-striped") |>
        formatStyle("Impact attendu",
                    color = styleEqual(c("Très élevé", "Élevé", "Moyen", "Modéré"),
                                       c("#C62828", "#E65100", "#F9A825", "#2E7D32")),
                    fontWeight = "700") |>
        formatStyle("Confiance (%)",
                    background = styleColorBar(c(0, 100), "#c7e9c0"),
                    backgroundSize = "95% 70%", backgroundRepeat = "no-repeat",
                    backgroundPosition = "center")
    })

    # ----- Exports fiche -----
    donnees_fiche_export <- reactive({
      t <- territoire()
      ind <- INDIC[[t$niveau]]
      ind <- ind[ind[[t$niveau]] == t$nom, ]
      f <- fiche_ispe()
      vue <- tibble(Indicateur = c("Score ISPE", "Rang national", "Niveau de priorité",
                                   "Classe (profil HCPC)", unname(LIB[intersect(names(ind), names(LIB))])),
                    Valeur = c(f$ispe, f$rang, f$niveau_priorite,
                               ifelse(is.na(f$classe), "-", f$classe),
                               unlist(ind[, intersect(names(ind), names(LIB))])))
      vue
    })

    output$dl_fiche_excel <- downloadHandler(
      filename = function() sprintf("fiche_%s_%s.xlsx", territoire()$nom, format(Sys.Date(), "%Y%m%d")),
      content = function(file) writexl::write_xlsx(
        list(Synthese = donnees_fiche_export(), Recommandations = recos_territoire()), file))
    output$dl_fiche_csv <- telecharger_tableau(donnees_fiche_export, "fiche_territoire", "csv")

    output$dl_fiche_carte <- telecharger_carte("png", function() {
      t <- territoire()
      couche <- SF[[t$niveau]]
      sel <- couche[couche[[t$niveau]] == t$nom, ]
      bb <- sf::st_bbox(sel)
      marge <- 0.35 * max(bb[3] - bb[1], bb[4] - bb[2])
      dessiner_carte_statique(
        couche, "niveau_priorite",
        titre = sprintf("%s — %s", NIVEAUX_LABELS[[t$niveau]], t$nom),
        sous_titre = sprintf("Score ISPE : %s | %s", fiche_ispe()$ispe, fiche_ispe()$niveau_priorite),
        categorielle = TRUE,
        bounds = list(west = bb[1] - marge, east = bb[3] + marge,
                      south = bb[2] - marge, north = bb[4] + marge))
    }, "carte_territoire")

    output$dl_fiche_pdf <- downloadHandler(
      filename = function() sprintf("fiche_%s_%s.pdf", gsub("[^A-Za-z0-9]", "_", territoire()$nom),
                                    format(Sys.Date(), "%Y%m%d")),
      content = function(file) {
        t <- territoire(); f <- fiche(); fi <- fiche_ispe(); recos <- recos_territoire()
        grDevices::cairo_pdf(file, width = 8.3, height = 11.7, onefile = TRUE)
        on.exit(dev.off(), add = TRUE)
        par(mar = c(2, 2, 4, 2))
        plot.new()
        title(main = sprintf("FICHE TERRITOIRE — %s (%s)", toupper(t$nom),
                             NIVEAUX_LABELS[[t$niveau]]), adj = 0, cex.main = 1.2)
        contribs <- as.numeric(fi[, c("contrib_couverture", "contrib_infrastructures",
                                      "contrib_enseignants", "contrib_resultats")])
        texte <- c(
          sprintf("Généré le %s — SAD Éducation Togo", format(Sys.Date(), "%d/%m/%Y")), "",
          sprintf("SCORE ISPE : %s / 100    RANG NATIONAL : %s / %s", fi$ispe, fi$rang,
                  nrow(ISPE[[t$niveau]])),
          sprintf("NIVEAU DE PRIORITÉ : %s", fi$niveau_priorite),
          sprintf("PROFIL (classe HCPC) : %s", f$libelle_classe), "",
          "POURQUOI CE CLASSEMENT ?",
          strwrap(f$explication, width = 95), "",
          "CONTRIBUTION DES DIMENSIONS AU SCORE :",
          sprintf("  - Couverture scolaire : %s%%   - Infrastructures : %s%%", contribs[1], contribs[2]),
          sprintf("  - Capacité enseignante : %s%%  - Conditions de réussite : %s%%", contribs[3], contribs[4]),
          "",
          "RECOMMANDATIONS D'INVESTISSEMENT :",
          unlist(lapply(seq_len(nrow(recos)), function(i) {
            c(sprintf("  %s. %s", recos$ordre[i], recos$action[i]),
              sprintf("     Impact attendu : %s | Confiance : %s%%", recos$impact_attendu[i], recos$confiance[i]),
              strwrap(recos$justification[i], width = 90, prefix = "     "))
          })))
        text(0, seq(0.98, by = -0.026, length.out = length(texte)), texte, adj = c(0, 1), cex = 0.72)
      })

    # ---------------- Résultats scolaires ----------------
    output$res_reussite <- renderHighchart({
      d <- RESNAT$reussite |> filter(secteur == "Total", niveau != "Total") |> arrange(annee)
      hc_serie_temporelle(d, "niveau", "Taux de réussite à l'examen de compétence par niveau", "%")
    })
    output$res_evolution <- renderHighchart({
      d <- RESNAT$scolarisation |> filter(secteur == "Total") |> arrange(annee)
      hc_serie_temporelle(d, "niveau", "Taux de scolarisation — évolution", "%")
    })
    output$res_achevement <- renderHighchart({
      d <- RESNAT$achevement |> filter(secteur == "Total") |> arrange(annee)
      hc_serie_temporelle(d, "niveau", "Taux d'achèvement ou de diplomation", "%")
    })
    output$res_contribution <- renderHighchart({
      d <- ISPE$prefecture |> arrange(desc(contrib_resultats)) |> head(15)
      hchart(d, "bar", hcaes(x = prefecture, y = contrib_resultats), name = "Contribution (%)",
             color = TG_ROUGE) |>
        hc_title(text = "Où les conditions de réussite pèsent-elles le plus sur la priorité ?",
                 style = list(fontSize = "13px")) |>
        hc_subtitle(text = "Top 15 des préfectures — contribution du pilier résultats au score ISPE") |>
        hc_xAxis(title = list(text = NULL)) |> hc_yAxis(title = list(text = "%")) |>
        hc_add_theme(hc_theme_togo)
    })

    # ---------------- Comparaison ----------------
    output$choix_comp <- renderUI(selecteur_territoires(ns("territoires_comp"), niveau = input$niveau_comp))

    comp <- reactive({
      req(input$territoires_comp)
      niv <- input$niveau_comp
      ISPE[[niv]] |> filter(.data[[niv]] %in% input$territoires_comp)
    })

    output$radar_piliers <- renderPlotly({
      d <- comp(); niv <- input$niveau_comp
      req(nrow(d) > 0)
      axes <- c("Couverture scolaire", "Infrastructures", "Capacité enseignante",
                "Conditions de réussite", "Score ISPE")
      fig <- plot_ly(type = "scatterpolar", mode = "lines+markers", fill = "toself")
      for (i in seq_len(nrow(d))) {
        vals <- as.numeric(d[i, c("deficit_couverture", "deficit_infrastructures",
                                  "deficit_enseignants", "deficit_resultats", "ispe")])
        fig <- fig |> add_trace(r = c(vals, vals[1]), theta = c(axes, axes[1]),
                                name = d[[niv]][i], opacity = 0.6)
      }
      fig |> layout(polar = list(radialaxis = list(range = c(0, 100))),
                    legend = list(orientation = "h"),
                    title = list(text = "Déficits par dimension (0 = aucun besoin, 100 = besoin maximal)",
                                 font = list(size = 14)),
                    margin = list(t = 40))
    })

    output$barres_ispe <- renderHighchart({
      niv <- input$niveau_comp
      d <- comp() |> arrange(desc(ispe)) |>
        mutate(territoire = .data[[niv]], couleur = unname(PAL_PRIORITE[niveau_priorite]))
      hchart(d, "column", hcaes(x = territoire, y = ispe, color = couleur),
             name = "Score ISPE") |>
        hc_title(text = "Scores ISPE comparés") |>
        hc_yAxis(max = 100, title = list(text = "ISPE")) |>
        hc_xAxis(title = list(text = NULL)) |>
        hc_add_theme(hc_theme_togo)
    })

    output$table_comp <- renderDT({
      d <- comp(); niv <- input$niveau_comp
      cles <- intersect(c("region", "prefecture", "commune"), names(d))
      dd <- d[, c(cles, "ispe", "rang", "niveau_priorite", "deficit_couverture",
                  "deficit_infrastructures", "deficit_enseignants", "deficit_resultats")]
      colnames(dd) <- c(NIVEAUX_LABELS[cles], "ISPE", "Rang", "Priorité",
                        "Déficit couverture", "Déficit infrastructures",
                        "Déficit enseignants", "Déficit cond. réussite")
      datatable(dd, rownames = FALSE, options = list(dom = "t", scrollX = TRUE),
                class = "table-striped compact")
    })
  })
}
