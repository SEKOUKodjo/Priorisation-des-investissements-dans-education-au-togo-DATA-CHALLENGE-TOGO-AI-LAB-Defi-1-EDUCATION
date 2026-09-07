# =============================================================================
# mod_auteur.R — Onglet Auteur : profil, photo et présentation du projet
#
# >>> PERSONNALISEZ ICI : remplacez les valeurs ci-dessous par les vôtres,
# >>> et déposez votre photo dans app/www/auteur_photo.jpg
# >>> (formats acceptés : .jpg ou .png — adaptez PHOTO_AUTEUR si besoin).
# =============================================================================

AUTEUR <- list(
  nom        = "Votre Nom & Prénom",
  titre      = "Data Analyst / Statisticien",
  bio        = paste("Passionné par la donnée au service des politiques publiques,",
                     "j'ai développé cette plateforme dans le cadre du Data Challenge",
                     "Éducation (Défi 1) du Togo AI Lab, pour aider à identifier les",
                     "territoires où les investissements éducatifs sont les plus prioritaires."),
  email      = "votre.email@exemple.com",
  telephone  = "+228 90 00 00 00",
  linkedin   = "https://www.linkedin.com/in/votre-profil",
  github     = "https://github.com/votre-compte",
  ville      = "Lomé, Togo",
  competences = c("R / R Shiny", "Analyse de données", "Statistique (ACP, classification)",
                  "Cartographie & SIG", "Aide à la décision")
)
PHOTO_AUTEUR <- "auteur_photo.jpg"   # fichier dans app/www/

mod_auteur_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(
        4,
        bs4Card(
          width = NULL, collapsible = FALSE, status = "success",
          title = tagList(icon("user"), "Profil"),
          tags$div(
            style = "text-align:center;padding:10px 0 4px;",
            tags$img(src = PHOTO_AUTEUR, alt = "Photo de l'auteur",
                     onerror = "this.src='auteur_photo_defaut.svg';",
                     style = paste("width:170px;height:170px;border-radius:50%;object-fit:cover;",
                                   "border:5px solid #006A4E;box-shadow:0 4px 14px rgba(0,0,0,.18);")),
            tags$h4(AUTEUR$nom, style = "font-weight:800;color:#00563F;margin:14px 0 2px;"),
            tags$div(AUTEUR$titre, style = "color:#D21034;font-weight:600;"),
            tags$div(icon("location-dot"), " ", AUTEUR$ville,
                     style = "color:#777;font-size:13px;margin-top:4px;")
          ),
          tags$hr(),
          tags$div(
            style = "font-size:13.5px;line-height:2;",
            tags$div(icon("envelope"), " ", tags$a(href = paste0("mailto:", AUTEUR$email), AUTEUR$email)),
            tags$div(icon("phone"), " ", AUTEUR$telephone),
            tags$div(icon("linkedin"), " ", tags$a(href = AUTEUR$linkedin, target = "_blank", "LinkedIn")),
            tags$div(icon("github"), " ", tags$a(href = AUTEUR$github, target = "_blank", "GitHub"))
          ),
          tags$hr(),
          tags$b("Compétences"),
          tags$div(style = "margin-top:8px;",
                   lapply(AUTEUR$competences, function(c)
                     tags$span(c, style = paste("display:inline-block;background:#f2f9f6;color:#00563F;",
                                                "border:1px solid #cfe5db;border-radius:12px;",
                                                "padding:3px 10px;margin:0 6px 6px 0;font-size:12.5px;"))))
        )
      ),
      column(
        8,
        bs4Card(
          width = NULL, collapsible = FALSE, status = "success",
          title = tagList(icon("circle-info"), "À propos de ce projet"),
          tags$p(AUTEUR$bio, style = "font-size:14.5px;line-height:1.7;"),
          tags$div(
            class = "encart-explication",
            HTML(paste(
              "<b>SAD Éducation Togo</b> est un Système d'Aide à la Décision développé pour le",
              "<b>Data Challenge Éducation — Défi 1</b> du Togo AI Lab. Il analyse la couverture scolaire,",
              "les infrastructures essentielles, la capacité enseignante et les résultats scolaires des",
              "<b>117 communes, 39 préfectures et 5 régions</b> du Togo, à partir des données ouvertes",
              "(geodata.gouv.tg, opendata.gouv.tg, UNESCO-ISU)."))
          )
        ),
        fluidRow(
          column(6, bs4Card(width = NULL, collapsible = FALSE, status = "success",
                            title = tagList(icon("gears"), "Sous le capot"),
                            tags$ul(class = "liste-points", style = "font-size:13.5px;",
                                    tags$li("Prétraitement R indépendant : nettoyage, fusion, indicateurs"),
                                    tags$li("ACP + classification HCPC consolidée K-means"),
                                    tags$li("Indice Synthétique de Priorité Éducative (ISPE)"),
                                    tags$li("Résultats servis en fichiers .rds — zéro calcul dans l'application"),
                                    tags$li("R Shiny · bs4Dash · leaflet · highcharter · plotly")))),
          column(6, bs4Card(width = NULL, collapsible = FALSE, status = "danger",
                            title = tagList(icon("database"), "Sources de données"),
                            tags$ul(class = "liste-points", style = "font-size:13.5px;",
                                    tags$li(tags$a(href = "https://geodata.gouv.tg", target = "_blank", "geodata.gouv.tg"),
                                            " — établissements, toilettes, bâtiments, terrains, crèches, bibliothèques"),
                                    tags$li(tags$a(href = "https://opendata.gouv.tg", target = "_blank", "opendata.gouv.tg"),
                                            " — enseignants du préscolaire, résultats scolaires nationaux"),
                                    tags$li("UNESCO — Institut de statistique (SDG4, OPRI)"),
                                    tags$li("geoBoundaries — frontières administratives"))))
        ),
        bs4Card(width = NULL, collapsible = FALSE, status = "success",
                title = tagList(icon("scroll"), "Remerciements"),
                tags$p(style = "font-size:13.5px;margin:0;",
                       "Merci au Togo AI Lab, initiateur du Data Challenge Éducation, ainsi qu'aux institutions",
                       " qui ouvrent leurs données. Derrière chaque point sur la carte, il y a des élèves,",
                       " des enseignants et des familles : les données n'ont de valeur que si elles les servent."))
      )
    )
  )
}

mod_auteur_server <- function(id) {
  moduleServer(id, function(input, output, session) {})
}
