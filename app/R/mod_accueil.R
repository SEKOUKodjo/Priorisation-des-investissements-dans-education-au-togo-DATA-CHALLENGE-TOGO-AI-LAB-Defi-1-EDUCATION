# =============================================================================
# mod_accueil.R — Page d'accueil : chiffres clés, indicateurs nationaux,
# résumé automatique, carte nationale, Top 10 prioritaires, mises à jour,
# rapport national téléchargeable.
# =============================================================================

mod_accueil_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$div(
      style = sprintf("background:linear-gradient(120deg,%s 0%%,#0a8b64 60%%,%s 130%%);
                       color:white;border-radius:14px;padding:22px 26px;margin-bottom:16px;",
                      TG_VERT_F, TG_VERT),
      tags$h3(style = "font-weight:800;margin:0;",
              icon("star"), " Où investir en priorité pour une éducation plus équitable ?"),
      tags$p(style = "margin:8px 0 0;max-width:900px;opacity:.95;",
             paste("Ce système d'aide à la décision analyse la couverture scolaire, les infrastructures",
                   "essentielles, la capacité enseignante et les résultats scolaires du Togo pour classer",
                   "automatiquement les territoires selon leur priorité d'investissement."))
    ),
    fluidRow(
      column(3, bs4ValueBoxOutput(ns("kpi_etabs"), width = NULL)),
      column(3, bs4ValueBoxOutput(ns("kpi_communes"), width = NULL)),
      column(3, bs4ValueBoxOutput(ns("kpi_prioritaires"), width = NULL)),
      column(3, bs4ValueBoxOutput(ns("kpi_enseignants"), width = NULL))
    ),
    fluidRow(
      column(
        7,
        bs4Card(title = tagList(icon("map-location-dot"), "Carte nationale des priorités éducatives"),
                width = NULL, status = "success", collapsible = FALSE, maximizable = TRUE,
                radioGroupButtons(ns("niveau_carte"), NULL,
                                  choices = c("Régions" = "region", "Préfectures" = "prefecture",
                                              "Communes" = "commune"),
                                  selected = "commune", status = "success", size = "sm"),
                leafletOutput(ns("carte_nationale"), height = 520)),
        bs4Card(title = tagList(icon("file-lines"), "Résumé automatique"),
                width = NULL, status = "success", collapsible = FALSE,
                uiOutput(ns("resume_auto")))
      ),
      column(
        5,
        bs4Card(title = tagList(icon("ranking-star"), "Top 10 des territoires prioritaires"),
                width = NULL, status = "danger", collapsible = FALSE,
                radioGroupButtons(ns("niveau_top"), NULL,
                                  choices = c("Communes" = "commune", "Préfectures" = "prefecture"),
                                  selected = "commune", status = "danger", size = "sm"),
                highchartOutput(ns("top10"), height = 360)),
        bs4Card(title = tagList(icon("gauge-high"), "Indicateurs nationaux"),
                width = NULL, status = "success", collapsible = FALSE,
                uiOutput(ns("indicateurs_nationaux"))),
        bs4Card(title = tagList(icon("clock-rotate-left"), "Dernières mises à jour"),
                width = NULL, status = "warning", collapsible = FALSE,
                uiOutput(ns("mises_a_jour")),
                tags$hr(),
                downloadButton(ns("dl_rapport"), "Télécharger le rapport national (PDF)",
                               class = "btn-success btn-block"))
      )
    )
  )
}

mod_accueil_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    output$kpi_etabs <- renderbs4ValueBox(
      boite_valeur(fmt(META$nb_etablissements), "Établissements scolaires géolocalisés", "school", "success"))
    output$kpi_communes <- renderbs4ValueBox(
      boite_valeur(sprintf("%s / %s / %s", META$nb_regions, META$nb_prefectures, META$nb_communes),
                   "Régions / Préfectures / Communes", "map", "primary"))
    output$kpi_prioritaires <- renderbs4ValueBox(
      boite_valeur(fmt(sum(ISPE$commune$niveau_priorite %in% c("Très prioritaire", "Prioritaire"))),
                   "Communes à investissement prioritaire", "triangle-exclamation", "danger"))
    output$kpi_enseignants <- renderbs4ValueBox(
      boite_valeur(fmt(META$nb_enseignants_prescolaire), "Enseignants du préscolaire", "chalkboard-user", "warning"))

    output$carte_nationale <- renderLeaflet({
      carte_priorite(SF[[input$niveau_carte]], input$niveau_carte)
    })

    output$top10 <- renderHighchart({
      niv <- input$niveau_top
      d <- ISPE[[niv]] |> arrange(rang) |> head(10) |>
        mutate(nom = .data[[niv]], couleur = unname(PAL_PRIORITE[niveau_priorite]))
      hchart(d, "bar", hcaes(x = nom, y = ispe, color = couleur), name = "Score ISPE") |>
        hc_xAxis(title = list(text = NULL)) |>
        hc_yAxis(title = list(text = "Score ISPE (0-100, plus élevé = plus prioritaire)"), max = 100) |>
        hc_tooltip(pointFormat = "Score ISPE : <b>{point.y}</b>") |>
        hc_add_theme(hc_theme_togo)
    })

    output$resume_auto <- renderUI({
      top <- ISPE$commune |> arrange(rang) |> head(3)
      reg_prior <- ISPE$region |> arrange(rang) |> head(1)
      nb_tp <- sum(ISPE$commune$niveau_priorite == "Très prioritaire")
      reussite <- RESNAT$reussite |> filter(niveau == "Primaire", secteur == "Total") |>
        arrange(desc(annee)) |> head(1)
      tags$div(
        class = "encart-explication",
        HTML(sprintf(
          paste0("Sur les <b>%s communes</b> analysées, <b>%s</b> ressortent comme très prioritaires ",
                 "pour l'investissement éducatif. Les trois territoires les plus prioritaires sont ",
                 "<b>%s</b> (ISPE %s), <b>%s</b> (%s) et <b>%s</b> (%s). À l'échelle régionale, ",
                 "la région <b>%s</b> concentre les besoins les plus élevés. ",
                 "%s L'analyse combine %s établissements géolocalisés, les infrastructures recensées ",
                 "(toilettes, bâtiments, bibliothèques, terrains de sport) et la capacité enseignante du préscolaire."),
          META$nb_communes, nb_tp,
          top$commune[1], top$ispe[1], top$commune[2], top$ispe[2], top$commune[3], top$ispe[3],
          reg_prior$region[1],
          if (nrow(reussite) == 1)
            sprintf("Au plan national, le taux de réussite à l'examen de compétence au primaire s'établit à <b>%s%%</b> (%s). ",
                    fmt1(reussite$valeur), reussite$annee) else "",
          fmt(META$nb_etablissements)))
      )
    })

    output$indicateurs_nationaux <- renderUI({
      derniere_valeur <- function(df, niv = "Primaire") {
        d <- df |> filter(niveau == niv, secteur == "Total") |> arrange(desc(annee))
        if (nrow(d) == 0) return(list(valeur = NA))
        d[1, ]
      }
      lignes <- list(
        c("Écoles (2022)", fmt((RESNAT$ecoles_enseignants |> filter(indicateur == "Nombre d'écoles", niveau == "Total", secteur == "Total") |> arrange(desc(annee)))$valeur[1])),
        c("Enseignants (2022)", fmt((RESNAT$ecoles_enseignants |> filter(indicateur == "Nombre d'enseignants", niveau == "Total", secteur == "Total") |> arrange(desc(annee)))$valeur[1])),
        c("Taux de scolarisation (primaire)", paste0(fmt1(derniere_valeur(RESNAT$scolarisation)$valeur), " %")),
        c("Taux d'achèvement (primaire)", paste0(fmt1(derniere_valeur(RESNAT$achevement)$valeur), " %")),
        c("Réussite examen de compétence (primaire)", paste0(fmt1(derniere_valeur(RESNAT$reussite)$valeur), " %")),
        c("Écoles primaires électrifiées", paste0(fmt1((RESNAT$uis_infrastructures |> filter(code == "SCHBSP.1.WELEC") |> arrange(desc(annee)))$valeur[1]), " %"))
      )
      tags$table(class = "table table-sm", style = "margin:0;",
                 lapply(lignes, function(l) tags$tr(
                   tags$td(l[1]), tags$td(style = "text-align:right;font-weight:700;color:#00563F;", l[2]))))
    })

    output$mises_a_jour <- renderUI({
      tags$ul(class = "liste-points", style = "font-size:13px;",
              tags$li(tags$b("Prétraitement des données : "), META$date_generation),
              tags$li(tags$b("Établissements scolaires : "), "geodata.gouv.tg, extraction décembre 2024"),
              tags$li(tags$b("Résultats scolaires nationaux : "), "opendata.gouv.tg, séries 2013-2022"),
              tags$li(tags$b("Indicateurs UNESCO-ISU : "), "dernière année disponible 2022"),
              tags$li(tags$b("Enseignants du préscolaire : "), "annuaire 2021-2022"))
    })

    output$dl_rapport <- downloadHandler(
      filename = function() sprintf("rapport_national_education_togo_%s.pdf", format(Sys.Date(), "%Y%m%d")),
      content = function(file) {
        grDevices::cairo_pdf(file, width = 11.7, height = 8.3, onefile = TRUE)
        on.exit(dev.off(), add = TRUE)

        # Page 1 — synthèse
        par(mar = c(2, 2, 4, 2))
        plot.new()
        title(main = "RAPPORT NATIONAL — PRIORITÉS D'INVESTISSEMENT ÉDUCATIF AU TOGO",
              cex.main = 1.35, adj = 0)
        top10 <- ISPE$commune |> arrange(rang) |> head(10)
        texte <- c(
          sprintf("Généré le %s par le SAD Éducation Togo", format(Sys.Date(), "%d/%m/%Y")),
          "",
          sprintf("Territoires analysés : %s régions, %s préfectures, %s communes",
                  META$nb_regions, META$nb_prefectures, META$nb_communes),
          sprintf("Établissements géolocalisés : %s | Bâtiments : %s | Toilettes : %s",
                  fmt(META$nb_etablissements), fmt(META$nb_batiments), fmt(META$nb_toilettes)),
          sprintf("Enseignants du préscolaire : %s", fmt(META$nb_enseignants_prescolaire)),
          "",
          "TOP 10 DES COMMUNES PRIORITAIRES (score ISPE) :",
          sprintf("  %2d. %-25s %-15s ISPE : %5.1f  (%s)", top10$rang, top10$commune,
                  paste0("(", top10$prefecture, ")"), top10$ispe, top10$niveau_priorite),
          "",
          "MÉTHODE :",
          strwrap(META$note_methodologique, width = 110))
        text(0, seq(0.97, by = -0.037, length.out = length(texte)), texte,
             adj = c(0, 1), cex = 0.78, family = "sans")

        # Page 2 — carte nationale des priorités (communes)
        dessiner_carte_statique(SF$commune, "niveau_priorite",
                                titre = "Carte nationale des priorités éducatives (communes)",
                                sous_titre = "Indice Synthétique de Priorité Éducative (ISPE)",
                                categorielle = TRUE)

        # Page 3 — répartition et classement
        par(mfrow = c(1, 2), mar = c(8, 4, 4, 1))
        rep <- table(ISPE$commune$niveau_priorite)[names(PAL_PRIORITE)]
        barplot(rep, col = unname(PAL_PRIORITE), border = NA, las = 2,
                main = "Communes par niveau de priorité", cex.names = 0.8)
        top20 <- ISPE$commune |> arrange(rang) |> head(20)
        par(mar = c(4, 9, 4, 1))
        barplot(rev(top20$ispe), names.arg = rev(top20$commune), horiz = TRUE, las = 1,
                col = rev(unname(PAL_PRIORITE[top20$niveau_priorite])), border = NA,
                main = "Top 20 des communes (score ISPE)", cex.names = 0.65)
        par(mfrow = c(1, 1))
      })
  })
}
