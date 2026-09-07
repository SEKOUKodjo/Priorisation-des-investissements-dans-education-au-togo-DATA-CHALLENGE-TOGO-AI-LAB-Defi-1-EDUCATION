# =============================================================================
# SAD ÉDUCATION TOGO — ui.R
# =============================================================================

bandeau <- tags$div(
  class = "bandeau-institutionnel",
  tags$img(src = "drapeau_togo.svg", alt = "Drapeau du Togo"),
  tags$div(
    class = "bandeau-centre",
    tags$div(class = "pays", "RÉPUBLIQUE TOGOLAISE"),
    tags$div(class = "devise", "TRAVAIL - LIBERTÉ - PATRIE"),
    tags$div(class = "ministere",
             "Ministère des Enseignements Primaire, Secondaire, Technique et de l'Artisanat"),
    tags$div(class = "plateforme",
             "Système d'Aide à la Décision pour l'Investissement Éducatif"),
    tags$div(class = "tricolore")
  ),
  tags$img(src = "armoiries_togo.svg", alt = "Armoiries du Togo")
)

ui <- bs4DashPage(
  title = "SAD Éducation Togo",
  fullscreen = TRUE,
  freshTheme = NULL,
  dark = NULL,
  help = NULL,

  header = bs4DashNavbar(
    status = "white",
    skin = "light",
    fixed = FALSE,
    bandeau
  ),

  sidebar = bs4DashSidebar(
    skin = "dark",
    status = "success",
    elevation = 3,
    collapsed = FALSE,
    minified = FALSE,
    bs4SidebarUserPanel(name = "Éducation Togo"),
    bs4SidebarMenu(
      id = "menu",
      bs4SidebarMenuItem("Accueil", tabName = "accueil", icon = icon("house")),
      bs4SidebarMenuItem("Couverture scolaire", tabName = "couverture", icon = icon("school")),
      bs4SidebarMenuItem("Infrastructures essentielles", tabName = "infrastructures", icon = icon("building")),
      bs4SidebarMenuItem("Capacité enseignante", tabName = "enseignants", icon = icon("chalkboard-user")),
      bs4SidebarMenuItem("Priorisation des investissements", tabName = "priorisation", icon = icon("ranking-star")),
      bs4SidebarMenuItem("Auteur", tabName = "auteur", icon = icon("user"))
    ),
    tags$div(class = "etoile-sidebar",
             icon("star"),
             tags$div(style = "font-size:11px;margin-top:4px;opacity:.85;",
                      paste("Données prétraitées le", META$date_generation)))
  ),

  body = bs4DashBody(
    tags$head(
      tags$link(rel = "stylesheet", href = "custom.css"),
      tags$title("SAD Éducation Togo")
    ),
    bs4TabItems(
      bs4TabItem(tabName = "accueil",        mod_accueil_ui("accueil")),
      bs4TabItem(tabName = "couverture",     mod_dimension_ui("couverture")),
      bs4TabItem(tabName = "infrastructures", mod_dimension_ui("infrastructures")),
      bs4TabItem(tabName = "enseignants",    mod_dimension_ui("enseignants")),
      bs4TabItem(tabName = "priorisation",   mod_priorisation_ui("priorisation")),
      bs4TabItem(tabName = "auteur",         mod_auteur_ui("auteur"))
    )
  ),

  footer = bs4DashFooter(
    left = tags$span("SAD Éducation Togo — Data Challenge Éducation, Défi 1 · Données ouvertes : ",
                     tags$a(href = "https://geodata.gouv.tg", target = "_blank", "geodata.gouv.tg"), " · ",
                     tags$a(href = "https://opendata.gouv.tg", target = "_blank", "opendata.gouv.tg"),
                     " · UNESCO-ISU"),
    right = tags$span(icon("star"), " Travail - Liberté - Patrie")
  )
)
