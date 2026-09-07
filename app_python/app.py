# =============================================================================
# SAD ÉDUCATION TOGO — application Shiny for Python
# Usage :  shiny run app.py   (depuis le dossier app_python/)
# Les données proviennent du prétraitement R :
#   Rscript preprocessing/00_run_all.R && Rscript preprocessing/07_export_python.R
# =============================================================================
from pathlib import Path

from shiny import App, ui
from faicons import icon_svg

import commun as C
import mod_accueil
import mod_dimension
import mod_priorisation
import mod_auteur

bandeau = ui.div(
    ui.tags.img(src="drapeau.jpg", alt="Drapeau du Togo", style="height:70px;"),
    ui.div(
        ui.div("RÉPUBLIQUE TOGOLAISE", class_="pays"),
        ui.div("TRAVAIL - LIBERTÉ - PATRIE", class_="devise"),
        ui.div("Ministère de l’Efficacité du Service Public et de la Transformation Numérique",
               class_="ministere"),
        ui.div("Tableau de bord d'Aide à la prise de Décision pour l'Investissement Éducatif",
               class_="plateforme"),
        ui.div(class_="tricolore"),
        class_="bandeau-centre"),
    ui.tags.img(src="armoiries_togo.jpg", alt="Armoiries du Togo", style="height:70px;"),
    class_="bandeau-institutionnel",
    style="display:flex;align-items:center;justify-content:space-between;gap:12px;"
          "background:white;padding:8px 16px;border-bottom:4px solid #006A4E;"
          "box-shadow:0 2px 8px rgba(0,0,0,.08);",
)

app_ui = ui.page_fluid(
    ui.tags.head(
        ui.tags.link(rel="stylesheet", href="custom.css"),
        ui.tags.title("SAD Éducation Togo — Python"),
        ui.tags.style("""
            body { background:#f4f7f5; overflow-x:hidden; }
            .nav-pills .nav-link { color:#00563F; font-weight:600; border-radius:8px; }
            .nav-pills .nav-link.active { background:#006A4E !important; color:white !important; }
            .bslib-value-box .value-box-title { font-size:13px; }
            .bslib-value-box .value-box-value { font-size:26px; font-weight:700; }
            .card { border-radius:12px; border:none; box-shadow:0 2px 10px rgba(0,0,0,.06); }
            .card-header { border-bottom:3px solid #006A4E; font-weight:700; color:#00563F;
                           background:white; border-radius:12px 12px 0 0 !important; }
            .shiny-plotly-output, .plotly-graph-div { width:100% !important; }
        """),
    ),
    bandeau,
    ui.div(
        ui.navset_pill_list(
            ui.nav_panel(ui.span(icon_svg("house"), " Accueil"),
                         mod_accueil.accueil_ui("accueil"), value="accueil"),
            ui.nav_panel(ui.span(icon_svg("school"), " Couverture scolaire"),
                         mod_dimension.dimension_ui("couverture", "couverture"),
                         value="couverture"),
            ui.nav_panel(ui.span(icon_svg("building"), " Infrastructures essentielles"),
                         mod_dimension.dimension_ui("infrastructures", "infrastructures"),
                         value="infrastructures"),
            ui.nav_panel(ui.span(icon_svg("chalkboard-user"), " Capacité enseignante"),
                         mod_dimension.dimension_ui("enseignants", "enseignants"),
                         value="enseignants"),
            ui.nav_panel(ui.span(icon_svg("ranking-star"), " Priorisation des investissements"),
                         mod_priorisation.priorisation_ui("priorisation"),
                         value="priorisation"),
            ui.nav_panel(ui.span(icon_svg("user"), " Auteur"),
                         mod_auteur.auteur_ui("auteur"), value="auteur"),
            id="menu", widths=(2, 10), well=True,
        ),
        style="padding:14px;",
    ),
    ui.div(
        ui.HTML("SAD Éducation Togo — Data Challenge Éducation, Défi 1 · Données ouvertes : "
                "<a href='https://geodata.gouv.tg' target='_blank'>geodata.gouv.tg</a> · "
                "<a href='https://opendata.gouv.tg' target='_blank'>opendata.gouv.tg</a> · "
                "UNESCO-ISU &nbsp;&nbsp;|&nbsp;&nbsp; ★ Travail - Liberté - Patrie"),
        style="text-align:center;color:#777;font-size:13px;padding:12px;"),
)


def server(input, output, session):
    # Signal de l'onglet actif : permet aux modules de ne construire leurs cartes
    # que lorsque leur panneau est visible (évite l'initialisation Leaflet à 0×0).
    def onglet_actif():
        return input.menu()

    mod_accueil.accueil_server("accueil", onglet_actif)
    mod_dimension.dimension_server("couverture", "couverture", onglet_actif)
    mod_dimension.dimension_server("infrastructures", "infrastructures", onglet_actif)
    mod_dimension.dimension_server("enseignants", "enseignants", onglet_actif)
    mod_priorisation.priorisation_server("priorisation", onglet_actif)
    mod_auteur.auteur_server("auteur")


app = App(app_ui, server, static_assets=Path(__file__).parent / "www")
