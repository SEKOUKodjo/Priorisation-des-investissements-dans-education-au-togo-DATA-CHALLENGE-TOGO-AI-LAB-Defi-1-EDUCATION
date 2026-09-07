# =============================================================================
# mod_auteur.py — Onglet Auteur
# >>> PERSONNALISEZ : éditez AUTEUR ci-dessous et déposez votre photo dans
# >>> app_python/www/auteur_photo.jpg
# =============================================================================
from shiny import module, ui
from faicons import icon_svg

AUTEUR = dict(
    nom="Maurice Kodjo SEKOU",
    titre="Analyste Statisticien",
    bio=("J'éprouve un réel plaisir à explorer les données, les analyser et les faire parler pour éclairer la prise de décision., j'ai développé cet "
         "Tableau de Bord  dans le cadre du Data Challenge Éducation (Défi 1) du Togo AI Lab, pour "
         "aider à identifier les territoires où les investissements éducatifs sont les plus "
         "prioritaires."),
    email="sekoukodjo4@gmail.com",
    competences=["Statistique", "Python / Shiny", "R / R Shiny","Cartographie & SIG"])
@module.ui
def auteur_ui():
    badges = [ui.span(c, style="display:inline-block;background:#f2f9f6;color:#00563F;"
                               "border:1px solid #cfe5db;border-radius:12px;"
                               "padding:3px 10px;margin:0 6px 6px 0;font-size:12.5px;")
              for c in AUTEUR["competences"]]
    return ui.layout_columns(
        ui.card(
            ui.card_header(ui.span(icon_svg("user"), " Profil")),
            ui.div(
                ui.tags.img(src="maurice1.png", onerror="this.src='maurice1.png';",
                            style="width:170px;height:170px;border-radius:50%;object-fit:cover;"
                                  "border:5px solid #006A4E;box-shadow:0 4px 14px rgba(0,0,0,.18);"),
                ui.h4(AUTEUR["nom"], style="font-weight:800;color:#00563F;margin:14px 0 2px;"),
                ui.div(AUTEUR["titre"], style="color:#D21034;font-weight:600;"),
                style="text-align:center;padding:10px 0 4px;"),
            ui.tags.hr(),
            ui.div(
                ui.div(icon_svg("envelope"), " ",
                       ui.a(AUTEUR["email"], href="mailto:" + AUTEUR["email"])),
                style="font-size:13.5px;line-height:2;"),
            ui.tags.hr(),
            ui.tags.b("Compétences"), ui.div(*badges, style="margin-top:8px;")),
        ui.div(
            ui.card(
                ui.card_header(ui.span(icon_svg("circle-info"), " À propos de ce projet")),
                ui.p(AUTEUR["bio"], style="font-size:14.5px;line-height:1.7;"),
                ui.div(ui.HTML(
                    "<b>SAD Éducation Togo</b> est un Système d'Aide à la Décision développé pour "
                    "le <b>Data Challenge Éducation — Défi 1</b> du Togo AI Lab. Cette version est "
                    "développée avec <b>Shiny for Python</b> ; elle analyse les 117 communes, "
                    "39 préfectures et 5 régions du Togo à partir des données ouvertes "
                    "(geodata.gouv.tg, opendata.gouv.tg, UNESCO-ISU)."),
                    class_="encart-explication")),
            ui.layout_columns(
                ui.card(ui.card_header(ui.span(icon_svg("gears"), " Sous le capot")),
                        ui.tags.ul(
                            ui.tags.li("Prétraitement R indépendant (indicateurs, ACP, HCPC, ISPE)"),
                            ui.tags.li("Résultats exportés en CSV / GeoJSON / JSON — zéro calcul lourd dans l'application"),
                            ui.tags.li("Shiny for Python · folium · plotly · geopandas"),
                            ui.tags.li("Simulateur de politiques publiques en langage naturel"),
                            class_="liste-points", style="font-size:13.5px;")),
                ui.card(ui.card_header(ui.span(icon_svg("database"), " Sources de données")),
                        ui.tags.ul(
                            ui.tags.li(ui.a("geodata.gouv.tg", href="https://geodata.gouv.tg",
                                            target="_blank"),
                                       " — établissements, toilettes, bâtiments, terrains, crèches"),
                            ui.tags.li(ui.a("opendata.gouv.tg", href="https://opendata.gouv.tg",
                                            target="_blank"),
                                       " — enseignants du préscolaire, résultats scolaires"),
                            ui.tags.li("UNESCO Institut de statistique (SDG4, OPRI)"),
                            ui.tags.li("geoBoundaries — frontières administratives"),
                            class_="liste-points", style="font-size:13.5px;")),
                col_widths=[6, 6]),
            ui.card(ui.card_header(ui.span(icon_svg("scroll"), " Remerciements")),
                    ui.p("Merci au Togo AI Lab, initiateur du Data Challenge Éducation, ainsi qu'aux "
                         "institutions qui ouvrent leurs données. Derrière chaque point sur la carte, "
                         "il y a des élèves, des enseignants et des familles : les données n'ont de "
                         "valeur que si elles les servent.",
                         style="font-size:13.5px;margin:0;"))),
        col_widths=[4, 8])


@module.server
def auteur_server(input, output, session):
    pass
