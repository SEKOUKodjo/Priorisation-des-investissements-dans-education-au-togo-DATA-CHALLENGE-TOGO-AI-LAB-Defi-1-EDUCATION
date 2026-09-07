# =============================================================================
# mod_simulateur.R — Agent de simulation de politiques publiques
# L'utilisateur pose une question en langage naturel
# (« Que se passe-t-il si je construis 50 salles de classe à Tône ? »).
# La simulation est une arithmétique légère « toutes choses égales par
# ailleurs » : moyennes, écarts-types et bornes des piliers proviennent de
# simulation.rds (précalculés) — aucun recalcul d'ACP ni de classification.
# =============================================================================

SIMUL <- charger("simulation.rds")

TYPES_INTERVENTION <- c(
  "Construire des salles de classe"          = "salles",
  "Construire de nouvelles écoles"           = "ecoles",
  "Recruter des enseignants (préscolaire)"   = "enseignants",
  "Construire des blocs de toilettes"        = "toilettes",
  "Construire des bibliothèques"             = "bibliotheques",
  "Aménager des terrains de sport"           = "terrains",
  "Réhabiliter / électrifier des bâtiments"  = "renovation",
  "Ouvrir des jardins d'enfants"             = "jardins"
)

MOTS_CLES_INTERVENTION <- list(
  salles        = c("salle", "classe"),
  enseignants   = c("enseignant", "professeur", "recrut", "maitre", "instituteur"),
  toilettes     = c("toilette", "latrine", "sanitaire", "wc"),
  bibliotheques = c("bibliotheque"),
  terrains      = c("terrain", "sport"),
  renovation    = c("electrif", "rehabilit", "renov"),
  jardins       = c("jardin", "prescolaire", "maternelle", "creche"),
  ecoles        = c("ecole", "college", "lycee", "etablissement")
)

# ---- Analyse de la question en langage naturel --------------------------------
simu_normaliser <- function(x) {
  x <- tolower(x)
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  gsub("[^a-z0-9 ]", " ", x)
}

REPERTOIRE_TERRITOIRES <- local({
  reps <- list()
  for (niv in c("commune", "prefecture", "region")) {
    noms <- INDIC[[niv]][[niv]]
    reps[[niv]] <- data.frame(niveau = niv, nom = noms, cle = simu_normaliser(noms))
  }
  d <- do.call(rbind, reps)
  d[order(-nchar(d$cle)), ]   # les noms les plus longs d'abord (« tone 1 » avant « tone »)
})

parser_question <- function(question) {
  q <- paste0(" ", simu_normaliser(question), " ")
  quantite <- suppressWarnings(as.numeric(regmatches(q, regexpr("[0-9]+", q))))
  if (length(quantite) == 0) quantite <- NA_real_

  type <- NA_character_
  for (t in names(MOTS_CLES_INTERVENTION)) {
    if (any(vapply(MOTS_CLES_INTERVENTION[[t]], function(m) grepl(m, q, fixed = TRUE), logical(1)))) {
      type <- t; break
    }
  }

  niveau <- NA_character_; territoire <- NA_character_
  for (i in seq_len(nrow(REPERTOIRE_TERRITOIRES))) {
    if (grepl(paste0(" ", REPERTOIRE_TERRITOIRES$cle[i], " "), q, fixed = TRUE)) {
      niveau <- REPERTOIRE_TERRITOIRES$niveau[i]
      territoire <- REPERTOIRE_TERRITOIRES$nom[i]
      break
    }
  }
  list(quantite = quantite, type = type, niveau = niveau, territoire = territoire)
}

# ---- Moteur de simulation (arithmétique, toutes choses égales par ailleurs) ----
simuler_intervention <- function(niveau, nom, type, quantite) {
  ind <- INDIC[[niveau]]
  ligne <- ind[ind[[niveau]] == nom, ]
  if (nrow(ligne) != 1 || is.na(quantite) || quantite <= 0) return(NULL)

  prm <- SIMUL[[niveau]]
  vars <- prm$stats_variables$variable
  x <- as.list(ligne[1, intersect(names(ligne), c(vars, "nb_etab", "nb_batiments", "nb_toilettes",
                                                  "nb_bibliotheques", "nb_prescolaire", "nb_primaire",
                                                  "enseignants_prescolaire", "superficie_km2"))])
  x <- lapply(x, function(v) ifelse(is.na(v), 0, v))
  avant <- x; q <- quantite
  hypotheses <- character(0)

  recalc_par_etab <- function(x) {
    x$toilettes_100_etab    <- 100 * x$nb_toilettes / x$nb_etab
    x$biblio_100_etab       <- 100 * x$nb_bibliotheques / x$nb_etab
    x$enseignants_100_etab  <- 100 * x$enseignants_prescolaire / x$nb_etab
    x$batiments_par_etab    <- x$nb_batiments / x$nb_etab
    if (!is.na(x$superficie_km2) && x$superficie_km2 > 0)
      x$densite_etab_100km2 <- 100 * x$nb_etab / x$superficie_km2
    x
  }

  if (type == "salles") {
    recents <- x$pct_batiments_recents / 100 * x$nb_batiments
    x$nb_batiments <- x$nb_batiments + q
    x$batiments_par_etab <- x$nb_batiments / x$nb_etab
    x$pct_batiments_recents <- min(100, 100 * (recents + q) / x$nb_batiments)
    hypotheses <- "chaque salle est comptée comme un bâtiment neuf (donc récent)"
  } else if (type == "ecoles") {
    x$nb_etab <- x$nb_etab + q
    x$nb_primaire <- x$nb_primaire + q
    recents <- x$pct_batiments_recents / 100 * x$nb_batiments
    x$nb_batiments <- x$nb_batiments + 2 * q
    x$pct_batiments_recents <- min(100, 100 * (recents + 2 * q) / x$nb_batiments)
    x$jardins_100_primaires <- 100 * x$nb_prescolaire / max(x$nb_primaire, 1)
    x <- recalc_par_etab(x)
    hypotheses <- "chaque nouvelle école est une école primaire de 2 salles de classe neuves"
  } else if (type == "enseignants") {
    x$enseignants_prescolaire <- x$enseignants_prescolaire + q
    x$ens_100_jardins <- 100 * x$enseignants_prescolaire / max(x$nb_prescolaire, 1)
    x$enseignants_100_etab <- 100 * x$enseignants_prescolaire / x$nb_etab
    hypotheses <- "les enseignants recrutés sont affectés au préscolaire du territoire"
  } else if (type == "toilettes") {
    ameliorees <- x$pct_toilettes_ameliorees / 100 * x$nb_toilettes
    x$nb_toilettes <- x$nb_toilettes + q
    x$toilettes_100_etab <- 100 * x$nb_toilettes / x$nb_etab
    x$pct_toilettes_ameliorees <- min(100, 100 * (ameliorees + q) / x$nb_toilettes)
    hypotheses <- "les blocs construits sont des installations améliorées (WC / latrines à eau)"
  } else if (type == "bibliotheques") {
    x$nb_bibliotheques <- x$nb_bibliotheques + q
    x$biblio_100_etab <- 100 * x$nb_bibliotheques / x$nb_etab
  } else if (type == "terrains") {
    avec <- x$pct_terrain_sport / 100 * x$nb_etab
    x$pct_terrain_sport <- min(100, 100 * (avec + q) / x$nb_etab)
    hypotheses <- "chaque terrain équipe un établissement qui n'en avait pas"
  } else if (type == "renovation") {
    recents <- x$pct_batiments_recents / 100 * x$nb_batiments
    x$pct_batiments_recents <- min(100, 100 * (recents + q) / max(x$nb_batiments, 1))
    hypotheses <- "un bâtiment réhabilité/électrifié est assimilé à un bâtiment récent"
  } else if (type == "jardins") {
    x$nb_prescolaire <- x$nb_prescolaire + q
    x$nb_etab <- x$nb_etab + q
    x$jardins_100_primaires <- 100 * x$nb_prescolaire / max(x$nb_primaire, 1)
    x$ens_100_jardins <- 100 * x$enseignants_prescolaire / max(x$nb_prescolaire, 1)
    x$completude_offre <- max(x$completude_offre, 100 * ((x$completude_offre / 25 >= 1) + 3) / 4)
    x <- recalc_par_etab(x)
    hypotheses <- "l'encadrement n'augmente pas : les enseignants actuels couvrent les nouveaux jardins"
  }

  # ---- Recalcul ISPE (paramètres figés du prétraitement) ----
  calcul_ispe_local <- function(vals) {
    st <- prm$stats_variables
    z <- vapply(seq_len(nrow(st)), function(i) {
      v <- st$variable[i]
      max(-2.5, min(2.5, (as.numeric(vals[[v]]) - st$moyenne[i]) / st$ecart_type[i]))
    }, numeric(1))
    names(z) <- st$variable
    deficits <- vapply(names(SIMUL$piliers), function(p) {
      score <- mean(z[SIMUL$piliers[[p]]])
      b <- prm$bornes_piliers[prm$bornes_piliers$pilier == p, ]
      d <- 100 - 100 * (score - b$minimum) / (b$maximum - b$minimum)
      max(0, min(100, d))
    }, numeric(1))
    list(deficits = round(deficits, 1),
         ispe = round(sum(deficits * SIMUL$poids[names(deficits)]), 1))
  }

  res_avant <- calcul_ispe_local(avant)
  res_apres <- calcul_ispe_local(x)

  autres <- ISPE[[niveau]]
  scores_autres <- autres$ispe[autres[[niveau]] != nom]
  rang_de <- function(s) 1 + sum(scores_autres > s)

  list(
    niveau = niveau, nom = nom, type = type, quantite = q,
    libelle_type = names(TYPES_INTERVENTION)[TYPES_INTERVENTION == type],
    hypotheses = hypotheses,
    ispe_avant = res_avant$ispe, ispe_apres = res_apres$ispe,
    rang_avant = rang_de(res_avant$ispe), rang_apres = rang_de(res_apres$ispe),
    n_total = nrow(autres),
    deficits_avant = res_avant$deficits, deficits_apres = res_apres$deficits,
    indicateurs = data.frame(
      variable = intersect(prm$stats_variables$variable, names(avant)),
      avant = round(unlist(avant[intersect(prm$stats_variables$variable, names(avant))]), 1),
      apres = round(unlist(x[intersect(prm$stats_variables$variable, names(avant))]), 1),
      row.names = NULL
    )
  )
}

# =============================================================================
# UI / SERVER
# =============================================================================
mod_simulateur_ui <- function(id) {
  ns <- NS(id)
  EXEMPLES <- c(
    "Que se passe-t-il si je construis 50 salles de classe dans la commune de Tône 1 ?",
    "Et si je recrute 100 enseignants dans la préfecture de Wawa ?",
    "Quel impact si je construis 30 blocs de toilettes à Danyi 1 ?",
    "Et si j'électrifie 80 bâtiments dans la région des Savanes ?"
  )
  tagList(
    fluidRow(
      column(
        7,
        bs4Card(width = NULL, collapsible = FALSE, status = "success",
                title = tagList(icon("wand-magic-sparkles"), "Posez votre question de politique publique"),
                textAreaInput(ns("question"), NULL, rows = 2, width = "100%",
                              placeholder = EXEMPLES[1]),
                div(style = "margin:-6px 0 10px;",
                    lapply(seq_along(EXEMPLES), function(i)
                      actionLink(ns(paste0("exemple", i)), tags$span(icon("comment-dots"), EXEMPLES[i]),
                                 style = "display:block;font-size:12.5px;margin-bottom:3px;color:#006A4E;"))),
                actionButton(ns("analyser"), tagList(icon("play"), "Lancer la simulation"),
                             class = "btn-success btn-lg", width = "100%"))
      ),
      column(
        5,
        bs4Card(width = NULL, collapsible = FALSE, status = "success",
                title = tagList(icon("sliders"), "Ou paramétrez directement"),
                fluidRow(
                  column(6, selectInput(ns("niveau_simu"), "Échelon",
                                        c("Commune" = "commune", "Préfecture" = "prefecture", "Région" = "region"),
                                        selected = "commune", width = "100%")),
                  column(6, numericInput(ns("quantite"), "Quantité", 50, min = 1, max = 5000, width = "100%"))
                ),
                selectizeInput(ns("territoire_simu"), "Territoire", choices = NULL, width = "100%"),
                selectInput(ns("type_simu"), "Type d'investissement", TYPES_INTERVENTION, width = "100%"))
      )
    ),
    uiOutput(ns("zone_resultats"))
  )
}

mod_simulateur_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    EXEMPLES <- c(
      "Que se passe-t-il si je construis 50 salles de classe dans la commune de Tône 1 ?",
      "Et si je recrute 100 enseignants dans la préfecture de Wawa ?",
      "Quel impact si je construis 30 blocs de toilettes à Danyi 1 ?",
      "Et si j'électrifie 80 bâtiments dans la région des Savanes ?"
    )
    lapply(1:4, function(i) observeEvent(input[[paste0("exemple", i)]],
      updateTextAreaInput(session, "question", value = EXEMPLES[i])))

    observe({
      niv <- input$niveau_simu
      updateSelectizeInput(session, "territoire_simu",
                           choices = sort(INDIC[[niv]][[niv]]), server = TRUE)
    })

    resultat <- eventReactive(input$analyser, {
      interp <- NULL
      if (nzchar(trimws(input$question %||% ""))) {
        p <- parser_question(input$question)
        if (!is.na(p$territoire)) {
          updateSelectInput(session, "niveau_simu", selected = p$niveau)
          updateSelectizeInput(session, "territoire_simu",
                               choices = sort(INDIC[[p$niveau]][[p$niveau]]),
                               selected = p$territoire, server = TRUE)
        }
        if (!is.na(p$type)) updateSelectInput(session, "type_simu", selected = p$type)
        if (!is.na(p$quantite)) updateNumericInput(session, "quantite", value = p$quantite)
        interp <- p
      }
      niveau <- if (!is.null(interp) && !is.na(interp$niveau)) interp$niveau else input$niveau_simu
      nom <- if (!is.null(interp) && !is.na(interp$territoire)) interp$territoire else input$territoire_simu
      type <- if (!is.null(interp) && !is.na(interp$type)) interp$type else input$type_simu
      q <- if (!is.null(interp) && !is.na(interp$quantite)) interp$quantite else input$quantite
      validate(need(nzchar(nom %||% ""), "Précisez un territoire (dans la question ou le panneau de droite)."))
      sim <- simuler_intervention(niveau, nom, type, q)
      validate(need(!is.null(sim), "Simulation impossible : vérifiez le territoire et la quantité."))
      sim$interpretation <- interp
      sim
    })

    output$zone_resultats <- renderUI({
      req(resultat())
      tagList(
        fluidRow(
          column(4, bs4Card(width = NULL, collapsible = FALSE, status = "success",
                            title = tagList(icon("robot"), "Lecture de votre question"),
                            uiOutput(ns("interpretation")),
                            tags$hr(),
                            uiOutput(ns("verdict")))),
          column(8, bs4Card(width = NULL, collapsible = FALSE, status = "danger",
                            title = tagList(icon("arrow-trend-down"), "Impact simulé sur les déficits et le score ISPE"),
                            fluidRow(
                              column(3, uiOutput(ns("carte_avant"))),
                              column(3, uiOutput(ns("carte_apres"))),
                              column(6, highchartOutput(ns("graph_deficits"), height = 300))
                            )))
        ),
        fluidRow(
          column(12, bs4Card(width = NULL, collapsible = FALSE, status = "success",
                             title = tagList(icon("table"), "Indicateurs modifiés par la simulation"),
                             DTOutput(ns("table_indicateurs")),
                             tags$p(class = "text-muted", style = "font-size:12px;margin-top:8px;",
                                    paste("Simulation « toutes choses égales par ailleurs » : les autres territoires,",
                                          "les moyennes nationales et les bornes des piliers restent figés à leur valeur",
                                          "observée. Les classes HCPC ne sont pas recalculées. Cet outil éclaire un ordre",
                                          "de grandeur, il ne remplace pas une étude de faisabilité."))))
        )
      )
    })

    output$interpretation <- renderUI({
      s <- resultat()
      tags$div(class = "encart-explication", style = "font-size:13.5px;",
        HTML(sprintf("J'ai compris : <b>%s</b> — quantité : <b>%s</b> — territoire : <b>%s</b> (%s).%s",
                     tolower(s$libelle_type), fmt(s$quantite), s$nom, NIVEAUX_LABELS[[s$niveau]],
                     if (length(s$hypotheses) && nzchar(s$hypotheses))
                       paste0("<br/><span style='color:#777;font-size:12px;'>Hypothèse : ", s$hypotheses, ".</span>") else "")))
    })

    output$carte_avant <- renderUI({
      s <- resultat()
      tags$div(style = "text-align:center;padding:12px 4px;background:#f4f7f5;border-radius:10px;",
               tags$div("AVANT", style = "font-size:11px;color:#888;font-weight:700;"),
               tags$div(s$ispe_avant, style = "font-size:34px;font-weight:800;color:#00563F;"),
               tags$div(sprintf("Rang %s / %s", s$rang_avant, s$n_total), style = "font-size:12px;color:#555;"))
    })
    output$carte_apres <- renderUI({
      s <- resultat()
      delta <- round(s$ispe_apres - s$ispe_avant, 1)
      coul <- if (delta < 0) "#2E7D32" else "#C62828"
      tags$div(style = "text-align:center;padding:12px 4px;background:#f2f9f6;border-radius:10px;border:2px solid #006A4E;",
               tags$div("APRÈS", style = "font-size:11px;color:#00563F;font-weight:700;"),
               tags$div(s$ispe_apres, style = "font-size:34px;font-weight:800;color:#00563F;"),
               tags$div(sprintf("Rang %s / %s", s$rang_apres, s$n_total), style = "font-size:12px;color:#555;"),
               tags$div(sprintf("%+.1f point%s", delta, ifelse(abs(delta) > 1, "s", "")),
                        style = sprintf("font-size:14px;font-weight:700;color:%s;", coul)))
    })

    output$graph_deficits <- renderHighchart({
      s <- resultat()
      libs <- c(couverture = "Couverture", infrastructures = "Infrastructures",
                enseignants = "Enseignants", resultats = "Cond. réussite")
      d <- data.frame(pilier = rep(unname(libs[names(s$deficits_avant)]), 2),
                      moment = factor(rep(c("Avant", "Après"), each = length(s$deficits_avant)),
                                      levels = c("Avant", "Après")),
                      deficit = c(unname(s$deficits_avant), unname(s$deficits_apres)))
      hchart(d, "column", hcaes(x = pilier, y = deficit, group = moment)) |>
        hc_colors(c("#9AB5A9", TG_VERT)) |>
        hc_yAxis(max = 100, title = list(text = "Déficit (0-100)")) |>
        hc_xAxis(title = list(text = NULL)) |>
        hc_title(text = NULL) |>
        hc_add_theme(hc_theme_togo)
    })

    output$verdict <- renderUI({
      s <- resultat()
      delta <- round(s$ispe_apres - s$ispe_avant, 1)
      gain_rang <- s$rang_apres - s$rang_avant
      dmax <- names(which.max(s$deficits_avant - s$deficits_apres))
      libs <- c(couverture = "couverture scolaire", infrastructures = "infrastructures essentielles",
                enseignants = "capacité enseignante", resultats = "conditions de réussite scolaire")
      texte <- if (delta < -0.05) {
        sprintf(paste0("Cet investissement ferait baisser le score de priorité de %s de %s à %s (%+.1f point%s), ",
                       "le faisant passer du rang %s au rang %s sur %s. L'effet porte principalement sur le pilier %s. %s"),
                s$nom, s$ispe_avant, s$ispe_apres, delta, ifelse(abs(delta) > 1, "s", ""),
                s$rang_avant, s$rang_apres, s$n_total,
                libs[dmax],
                if (gain_rang > 0) "Le besoin diminue nettement : d'autres territoires deviennent comparativement plus prioritaires." else "")
      } else {
        sprintf(paste0("Cet investissement ne modifierait pas sensiblement le score de priorité de %s (%s → %s). ",
                       "Ce levier n'est probablement pas le plus efficace ici : consultez les recommandations de la fiche ",
                       "territoire pour identifier les investissements à plus fort impact."),
                s$nom, s$ispe_avant, s$ispe_apres)
      }
      tags$div(class = if (delta < -0.05) "encart-explication" else "encart-alerte",
               style = "font-size:13.5px;", texte)
    })

    output$table_indicateurs <- renderDT({
      s <- resultat()
      d <- s$indicateurs
      d <- d[abs(d$apres - d$avant) > 1e-9 | d$variable %in% unlist(SIMUL$piliers), ]
      d$variable <- unname(LIB[d$variable])
      d$evolution <- sprintf("%+.1f", d$apres - d$avant)
      colnames(d) <- c("Indicateur", "Avant", "Après", "Évolution")
      datatable(d, rownames = FALSE, options = list(dom = "t", pageLength = 15, scrollX = TRUE),
                class = "table-striped compact") |>
        formatStyle("Évolution", fontWeight = "700",
                    color = styleInterval(0, c("#555555", "#2E7D32")))
    })
  })
}

`%||%` <- function(a, b) if (is.null(a)) b else a
