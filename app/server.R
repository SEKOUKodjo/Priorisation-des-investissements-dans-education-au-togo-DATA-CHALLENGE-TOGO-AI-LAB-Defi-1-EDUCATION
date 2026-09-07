# =============================================================================
# SAD ÉDUCATION TOGO — server.R
# =============================================================================

server <- function(input, output, session) {
  mod_accueil_server("accueil")
  mod_dimension_server("couverture")
  mod_dimension_server("infrastructures")
  mod_dimension_server("enseignants")
  mod_priorisation_server("priorisation")
  mod_auteur_server("auteur")
}
