# =============================================================================
# mod_simulateur.py — Agent de simulation de politiques publiques (Python)
# Question en langage naturel -> impact ISPE « toutes choses égales par ailleurs »
# à partir des paramètres précalculés (simulation.json). Aucun recalcul d'ACP.
# =============================================================================
import re

import pandas as pd
from shiny import module, ui, render, reactive
from shinywidgets import output_widget, render_widget
from faicons import icon_svg

import commun as C

TYPES = {
    "salles": "Construire des salles de classe",
    "ecoles": "Construire de nouvelles écoles",
    "enseignants": "Recruter des enseignants (préscolaire)",
    "toilettes": "Construire des blocs de toilettes",
    "bibliotheques": "Construire des bibliothèques",
    "terrains": "Aménager des terrains de sport",
    "renovation": "Réhabiliter / électrifier des bâtiments",
    "jardins": "Ouvrir des jardins d'enfants",
}
MOTS_CLES = {
    "salles": ["salle", "classe"],
    "enseignants": ["enseignant", "professeur", "recrut", "maitre", "instituteur"],
    "toilettes": ["toilette", "latrine", "sanitaire", "wc"],
    "bibliotheques": ["bibliotheque"],
    "terrains": ["terrain", "sport"],
    "renovation": ["electrif", "rehabilit", "renov"],
    "jardins": ["jardin", "prescolaire", "maternelle", "creche"],
    "ecoles": ["ecole", "college", "lycee", "etablissement"],
}
EXEMPLES = [
    "Que se passe-t-il si je construis 50 salles de classe dans la commune de Tône 1 ?",
    "Et si je recrute 100 enseignants dans la préfecture de Wawa ?",
    "Quel impact si je construis 30 blocs de toilettes à Danyi 1 ?",
    "Et si j'électrifie 80 bâtiments dans la région des Savanes ?",
]

_REPERTOIRE = []
for _n in C.NIVEAUX:
    for _nom in C.IND[_n][_n]:
        _REPERTOIRE.append((_n, _nom, C.normaliser(_nom)))
_REPERTOIRE.sort(key=lambda t: -len(t[2]))


def parser_question(question):
    q = " " + C.normaliser(question) + " "
    m = re.search(r"[0-9]+", q)
    quantite = float(m.group()) if m else None
    type_ = next((t for t, mots in MOTS_CLES.items()
                  if any(mot in q for mot in mots)), None)
    niveau = territoire = None
    for niv, nom, cle in _REPERTOIRE:
        if f" {cle} " in q:
            niveau, territoire = niv, nom
            break
    return dict(quantite=quantite, type=type_, niveau=niveau, territoire=territoire)


def simuler(niveau, nom, type_, q):
    ind = C.IND[niveau]
    sel = ind[ind[niveau] == nom]
    if len(sel) != 1 or not q or q <= 0:
        return None
    prm = C.SIMUL["niveaux"][niveau]
    stats = pd.DataFrame(prm["stats_variables"]).set_index("variable")
    bornes = pd.DataFrame(prm["bornes_piliers"]).set_index("pilier")
    poids = C.SIMUL["poids"]
    piliers = C.SIMUL["piliers"]

    x = {k: (0 if pd.isna(v) else float(v)) for k, v in sel.iloc[0].items()
         if isinstance(v, (int, float)) or pd.api.types.is_number(v)}
    avant = dict(x)
    hypothese = ""

    def recalc_par_etab(x):
        x["toilettes_100_etab"] = 100 * x["nb_toilettes"] / x["nb_etab"]
        x["biblio_100_etab"] = 100 * x["nb_bibliotheques"] / x["nb_etab"]
        x["enseignants_100_etab"] = 100 * x["enseignants_prescolaire"] / x["nb_etab"]
        x["batiments_par_etab"] = x["nb_batiments"] / x["nb_etab"]
        if x.get("superficie_km2", 0) > 0:
            x["densite_etab_100km2"] = 100 * x["nb_etab"] / x["superficie_km2"]

    if type_ == "salles":
        recents = x["pct_batiments_recents"] / 100 * x["nb_batiments"]
        x["nb_batiments"] += q
        x["batiments_par_etab"] = x["nb_batiments"] / x["nb_etab"]
        x["pct_batiments_recents"] = min(100, 100 * (recents + q) / x["nb_batiments"])
        hypothese = "chaque salle est comptée comme un bâtiment neuf (donc récent)"
    elif type_ == "ecoles":
        x["nb_etab"] += q
        x["nb_primaire"] += q
        recents = x["pct_batiments_recents"] / 100 * x["nb_batiments"]
        x["nb_batiments"] += 2 * q
        x["pct_batiments_recents"] = min(100, 100 * (recents + 2 * q) / x["nb_batiments"])
        x["jardins_100_primaires"] = 100 * x["nb_prescolaire"] / max(x["nb_primaire"], 1)
        recalc_par_etab(x)
        hypothese = "chaque nouvelle école est une primaire de 2 salles neuves"
    elif type_ == "enseignants":
        x["enseignants_prescolaire"] += q
        x["ens_100_jardins"] = 100 * x["enseignants_prescolaire"] / max(x["nb_prescolaire"], 1)
        x["enseignants_100_etab"] = 100 * x["enseignants_prescolaire"] / x["nb_etab"]
        hypothese = "les enseignants recrutés sont affectés au préscolaire du territoire"
    elif type_ == "toilettes":
        amel = x["pct_toilettes_ameliorees"] / 100 * x["nb_toilettes"]
        x["nb_toilettes"] += q
        x["toilettes_100_etab"] = 100 * x["nb_toilettes"] / x["nb_etab"]
        x["pct_toilettes_ameliorees"] = min(100, 100 * (amel + q) / x["nb_toilettes"])
        hypothese = "les blocs construits sont des installations améliorées"
    elif type_ == "bibliotheques":
        x["nb_bibliotheques"] += q
        x["biblio_100_etab"] = 100 * x["nb_bibliotheques"] / x["nb_etab"]
    elif type_ == "terrains":
        avec = x["pct_terrain_sport"] / 100 * x["nb_etab"]
        x["pct_terrain_sport"] = min(100, 100 * (avec + q) / x["nb_etab"])
        hypothese = "chaque terrain équipe un établissement qui n'en avait pas"
    elif type_ == "renovation":
        recents = x["pct_batiments_recents"] / 100 * x["nb_batiments"]
        x["pct_batiments_recents"] = min(100, 100 * (recents + q) / max(x["nb_batiments"], 1))
        hypothese = "un bâtiment réhabilité/électrifié est assimilé à un bâtiment récent"
    elif type_ == "jardins":
        x["nb_prescolaire"] += q
        x["nb_etab"] += q
        x["jardins_100_primaires"] = 100 * x["nb_prescolaire"] / max(x["nb_primaire"], 1)
        x["ens_100_jardins"] = 100 * x["enseignants_prescolaire"] / max(x["nb_prescolaire"], 1)
        recalc_par_etab(x)
        hypothese = "l'encadrement n'augmente pas avec les nouveaux jardins"

    def ispe_local(vals):
        z = {}
        for v in stats.index:
            m, s = stats.loc[v, "moyenne"], stats.loc[v, "ecart_type"]
            z[v] = max(-2.5, min(2.5, (vals.get(v, 0) - m) / s))
        deficits = {}
        for p, membres in piliers.items():
            score = sum(z[v] for v in membres) / len(membres)
            b = bornes.loc[p]
            d = 100 - 100 * (score - b["minimum"]) / (b["maximum"] - b["minimum"])
            deficits[p] = round(max(0, min(100, d)), 1)
        return deficits, round(sum(deficits[p] * poids[p] for p in deficits), 1)

    def_av, ispe_av = ispe_local(avant)
    def_ap, ispe_ap = ispe_local(x)
    autres = C.ISPE[niveau]
    scores_autres = autres.loc[autres[niveau] != nom, "ispe"]

    variables = [v for v in stats.index if v in avant]
    return dict(
        niveau=niveau, nom=nom, type=type_, quantite=q,
        libelle_type=TYPES[type_], hypothese=hypothese,
        ispe_avant=ispe_av, ispe_apres=ispe_ap,
        rang_avant=int((scores_autres > ispe_av).sum() + 1),
        rang_apres=int((scores_autres > ispe_ap).sum() + 1),
        n_total=len(autres),
        deficits_avant=def_av, deficits_apres=def_ap,
        indicateurs=pd.DataFrame({
            "variable": variables,
            "avant": [round(avant[v], 1) for v in variables],
            "apres": [round(x[v], 1) for v in variables]}))


@module.ui
def simulateur_ui():
    return ui.div(
        ui.layout_columns(
            ui.card(
                ui.card_header(ui.span(icon_svg("wand-magic-sparkles"),
                                       " Posez votre question de politique publique")),
                ui.input_text_area("question", None, rows=2, width="100%",
                                   placeholder=EXEMPLES[0]),
                ui.div(*[ui.input_action_link(f"exemple{i}", ex,
                                              style="display:block;font-size:12.5px;"
                                                    "margin-bottom:3px;color:#006A4E;")
                         for i, ex in enumerate(EXEMPLES)]),
                ui.input_action_button("analyser", "Lancer la simulation",
                                       class_="btn-success btn-lg w-100")),
            ui.card(
                ui.card_header(ui.span(icon_svg("sliders"), " Ou paramétrez directement")),
                ui.layout_columns(
                    ui.input_select("niveau_simu", "Échelon",
                                    {"commune": "Commune", "prefecture": "Préfecture",
                                     "region": "Région"}),
                    ui.input_numeric("quantite", "Quantité", 50, min=1, max=5000),
                    col_widths=[6, 6]),
                ui.output_ui("choix_territoire"),
                ui.input_select("type_simu", "Type d'investissement", TYPES)),
            col_widths=[7, 5]),
        ui.output_ui("zone_resultats"),
    )


@module.server
def simulateur_server(input, output, session):
    def _lier_exemple(idx, texte):
        @reactive.effect
        @reactive.event(lambda: input[f"exemple{idx}"]())
        def _():
            ui.update_text_area("question", value=texte)

    for _i, _ex in enumerate(EXEMPLES):
        _lier_exemple(_i, _ex)

    @render.ui
    def choix_territoire():
        niv = input.niveau_simu()
        return ui.input_selectize("territoire_simu", "Territoire",
                                  sorted(C.IND[niv][niv].tolist()))

    @reactive.calc
    @reactive.event(input.analyser)
    def resultat():
        interp = None
        if (input.question() or "").strip():
            interp = parser_question(input.question())
        niveau = interp["niveau"] if interp and interp["niveau"] else input.niveau_simu()
        try:
            terr_manuel = input.territoire_simu()
        except Exception:
            terr_manuel = None
        nom = interp["territoire"] if interp and interp["territoire"] else terr_manuel
        type_ = interp["type"] if interp and interp["type"] else input.type_simu()
        q = interp["quantite"] if interp and interp["quantite"] else input.quantite()
        if not nom:
            return {"erreur": "Précisez un territoire (dans la question ou le panneau de droite)."}
        s = simuler(niveau, nom, type_, q)
        if s is None:
            return {"erreur": "Simulation impossible : vérifiez le territoire et la quantité."}
        return s

    @render.ui
    def zone_resultats():
        s = resultat()
        if s is None:
            return None
        if "erreur" in s:
            return ui.div(s["erreur"], class_="encart-alerte")
        delta = round(s["ispe_apres"] - s["ispe_avant"], 1)
        coul = "#2E7D32" if delta < 0 else "#C62828"
        libs = {"couverture": "couverture scolaire",
                "infrastructures": "infrastructures essentielles",
                "enseignants": "capacité enseignante",
                "resultats": "conditions de réussite scolaire"}
        gains = {p: s["deficits_avant"][p] - s["deficits_apres"][p] for p in s["deficits_avant"]}
        pilier_max = max(gains, key=gains.get)
        if delta < -0.05:
            verdict = (f"Cet investissement ferait baisser le score de priorité de {s['nom']} de "
                       f"{s['ispe_avant']} à {s['ispe_apres']} ({delta:+.1f} point"
                       f"{'s' if abs(delta) > 1 else ''}), le faisant passer du rang "
                       f"{s['rang_avant']} au rang {s['rang_apres']} sur {s['n_total']}. "
                       f"L'effet porte principalement sur le pilier {libs[pilier_max]}.")
            classe_verdict = "encart-explication"
        else:
            verdict = (f"Cet investissement ne modifierait pas sensiblement le score de priorité de "
                       f"{s['nom']} ({s['ispe_avant']} → {s['ispe_apres']}). Ce levier n'est "
                       f"probablement pas le plus efficace ici : consultez les recommandations de "
                       f"la fiche territoire.")
            classe_verdict = "encart-alerte"

        bloc = lambda titre, val, rang, extra="", style="": ui.div(
            ui.div(titre, style="font-size:11px;color:#888;font-weight:700;"),
            ui.div(str(val), style="font-size:34px;font-weight:800;color:#00563F;"),
            ui.div(f"Rang {rang} / {s['n_total']}", style="font-size:12px;color:#555;"),
            ui.HTML(extra),
            style="text-align:center;padding:12px 6px;background:#f4f7f5;border-radius:10px;" + style)

        return ui.div(
            ui.layout_columns(
                ui.card(ui.card_header(ui.span(icon_svg("robot"), " Lecture de votre question")),
                        ui.div(ui.HTML(
                            f"J'ai compris : <b>{s['libelle_type'].lower()}</b> — quantité : "
                            f"<b>{C.fmt(s['quantite'])}</b> — territoire : <b>{s['nom']}</b> "
                            f"({C.NIVEAUX_LABELS[s['niveau']]})."
                            + (f"<br/><span style='color:#777;font-size:12px;'>Hypothèse : "
                               f"{s['hypothese']}.</span>" if s["hypothese"] else "")),
                            class_="encart-explication", style="font-size:13.5px;"),
                        ui.tags.hr(),
                        ui.div(verdict, class_=classe_verdict, style="font-size:13.5px;")),
                ui.card(ui.card_header(ui.span(icon_svg("arrow-trend-down"),
                                               " Impact simulé sur les déficits et le score ISPE")),
                        ui.layout_columns(
                            bloc("AVANT", s["ispe_avant"], s["rang_avant"]),
                            bloc("APRÈS", s["ispe_apres"], s["rang_apres"],
                                 f"<div style='font-size:14px;font-weight:700;color:{coul};'>"
                                 f"{delta:+.1f} point{'s' if abs(delta) > 1 else ''}</div>",
                                 "border:2px solid #006A4E;background:#f2f9f6;"),
                            output_widget("graph_deficits"),
                            col_widths=[3, 3, 6])),
                col_widths=[4, 8]),
            ui.card(ui.card_header(ui.span(icon_svg("table"),
                                           " Indicateurs modifiés par la simulation")),
                    ui.output_data_frame("table_simulation"),
                    ui.tags.p("Simulation « toutes choses égales par ailleurs » : les autres "
                              "territoires et les bornes des piliers restent figés. Les classes HCPC "
                              "ne sont pas recalculées. Cet outil éclaire un ordre de grandeur, il ne "
                              "remplace pas une étude de faisabilité.",
                              style="font-size:12px;color:#777;margin-top:8px;")))

    @render_widget
    def graph_deficits():
        s = resultat()
        import plotly.graph_objects as go
        if s is None or "erreur" in s:
            return C.theme_plotly(go.Figure(), None, hauteur=300)
        libs = {"couverture": "Couverture", "infrastructures": "Infrastructures",
                "enseignants": "Enseignants", "resultats": "Cond. réussite"}
        axes = [libs[p] for p in s["deficits_avant"]]
        fig = go.Figure()
        fig.add_trace(go.Bar(name="Avant", x=axes, y=list(s["deficits_avant"].values()),
                             marker_color="#9AB5A9"))
        fig.add_trace(go.Bar(name="Après", x=axes, y=list(s["deficits_apres"].values()),
                             marker_color=C.TG_VERT))
        fig.update_yaxes(range=[0, 100], title="Déficit (0-100)")
        return C.theme_plotly(fig, None, hauteur=300)

    @render.data_frame
    def table_simulation():
        s = resultat()
        if s is None or "erreur" in s:
            return render.DataGrid(pd.DataFrame())
        d = s["indicateurs"].copy()
        membres = sum(C.SIMUL["piliers"].values(), [])
        d = d[((d["apres"] - d["avant"]).abs() > 1e-9) | d["variable"].isin(membres)]
        d["variable"] = d["variable"].map(lambda v: C.LIB.get(v, v))
        d["evolution"] = (d["apres"] - d["avant"]).map(lambda x: f"{x:+.1f}")
        d.columns = ["Indicateur", "Avant", "Après", "Évolution"]
        return render.DataGrid(d, width="100%")
