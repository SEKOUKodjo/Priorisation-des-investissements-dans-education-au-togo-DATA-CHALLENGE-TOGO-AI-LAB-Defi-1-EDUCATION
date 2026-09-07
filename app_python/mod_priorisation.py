# =============================================================================
# mod_priorisation.py — Module principal : Priorisation des investissements
# Vue nationale | Fiche territoire | Résultats scolaires | Simulateur | Comparaison
# =============================================================================
from datetime import date

import pandas as pd
from shiny import module, ui, render, reactive, req
from shinywidgets import output_widget, render_widget
from faicons import icon_svg

import commun as C
import mod_simulateur as SIMU

_niveaux = {"region": "Région", "prefecture": "Préfecture", "commune": "Commune"}
LIB_PILIERS = {"deficit_couverture": "Couverture scolaire",
               "deficit_infrastructures": "Infrastructures essentielles",
               "deficit_enseignants": "Capacité enseignante",
               "deficit_resultats": "Conditions de réussite scolaire"}


def _badge(niveau_priorite):
    c = C.PAL_PRIORITE.get(niveau_priorite, "#777")
    return ui.span(niveau_priorite,
                   style=f"background:{c};color:white;padding:4px 12px;"
                         "border-radius:12px;font-weight:600;")


@module.ui
def priorisation_ui():
    return ui.div(
        ui.layout_columns(
            ui.value_box("Communes très prioritaires",
                         C.fmt((C.ISPE["commune"]["niveau_priorite"] == "Très prioritaire").sum()),
                         showcase=icon_svg("triangle-exclamation"), theme="danger"),
            ui.value_box("Score ISPE moyen (communes)",
                         C.fmt1(C.ISPE["commune"]["ispe"].mean()),
                         showcase=icon_svg("gauge-high"), theme="success"),
            ui.value_box("Profils de territoires identifiés",
                         str(int(C.ISPE["commune"]["classe"].nunique())),
                         showcase=icon_svg("layer-group"), theme="primary"),
            ui.value_box("Réussite examen primaire (2022)", "81,8 %",
                         showcase=icon_svg("graduation-cap"), theme="warning"),
            col_widths=[3, 3, 3, 3]),
        ui.navset_card_pill(
            # ---------------- Vue nationale ----------------
            ui.nav_panel(
                "Vue nationale",
                ui.layout_columns(
                    ui.div(
                        ui.input_radio_buttons("niveau_nat", "Maille d'analyse", _niveaux,
                                               selected="commune", inline=True),
                        ui.div(ui.HTML(
                            "<b>ISPE</b> — Indice Synthétique de Priorité Éducative (0-100). "
                            "Plus le score est élevé, plus le territoire est prioritaire. Il agrège "
                            "les déficits de couverture (30 %), d'infrastructures (30 %), de capacité "
                            "enseignante (25 %) et de conditions de réussite (15 %)."),
                            class_="encart-explication", style="font-size:13px;"),
                        ui.tags.hr(),
                        ui.download_button("dl_carte_png", "Télécharger la carte (PNG)",
                                           class_="btn-outline-success btn-sm w-100"),
                        output_widget("donut")),
                    ui.output_ui("carte_priorites"),
                    ui.div(ui.tags.b("Classement national"),
                           ui.output_data_frame("classement")),
                    col_widths=[3, 5, 4]),
            ),
            # ---------------- Fiche territoire ----------------
            ui.nav_panel(
                "Fiche territoire",
                ui.layout_columns(
                    ui.div(
                        ui.input_radio_buttons("niveau_fiche", "Échelon", _niveaux,
                                               selected="commune", inline=True),
                        ui.input_select("region_fiche", "Région",
                                        sorted(C.IND["region"]["region"].tolist())),
                        ui.output_ui("choix_prefecture"),
                        ui.output_ui("choix_commune"),
                        ui.tags.hr(),
                        ui.download_button("dl_fiche_excel", "Fiche (Excel)",
                                           class_="btn-success btn-sm w-100 mb-1"),
                        ui.download_button("dl_fiche_csv", "Fiche (CSV)",
                                           class_="btn-outline-success btn-sm w-100 mb-1"),
                        ui.download_button("dl_fiche_carte", "Carte du territoire (PNG)",
                                           class_="btn-outline-success btn-sm w-100")),
                    ui.div(
                        ui.layout_columns(
                            ui.card(ui.card_header("Score ISPE"), ui.output_ui("fiche_score")),
                            ui.card(ui.card_header("Profil du territoire (classe HCPC)"),
                                    ui.output_ui("fiche_classe")),
                            col_widths=[4, 8]),
                        ui.card(ui.card_header(ui.span(icon_svg("circle-info"),
                                                       " Pourquoi ce classement ?")),
                                ui.output_ui("fiche_explication"),
                                ui.layout_columns(ui.output_ui("fiche_forces"),
                                                  ui.output_ui("fiche_faiblesses"),
                                                  col_widths=[6, 6]),
                                output_widget("fiche_contributions")),
                        ui.card(ui.card_header(ui.span(icon_svg("lightbulb"),
                                                       " Recommandations d'investissement")),
                                ui.output_data_frame("fiche_recos"))),
                    col_widths=[3, 9]),
            ),
            # ---------------- Résultats scolaires ----------------
            ui.nav_panel(
                "Résultats scolaires",
                ui.layout_columns(output_widget("res_reussite"), output_widget("res_scolarisation"),
                                  col_widths=[6, 6]),
                ui.layout_columns(output_widget("res_achevement"), output_widget("res_contribution"),
                                  col_widths=[6, 6]),
                ui.div(ui.HTML(
                    "<b>Note méthodologique.</b> Les résultats d'examens ne sont publiés qu'à "
                    "l'échelle nationale dans les données ouvertes. Au niveau territorial, la "
                    "dimension « résultats scolaires » de l'ISPE mobilise un indice de conditions "
                    "de réussite (encadrement, complétude du cycle, hygiène, état du bâti)."),
                    class_="encart-alerte", style="font-size:13px;margin-top:8px;"),
            ),
            # ---------------- Simulateur ----------------
            ui.nav_panel("Simulateur", SIMU.simulateur_ui("simulateur")),
            # ---------------- Comparaison ----------------
            ui.nav_panel(
                "Comparaison",
                ui.layout_columns(
                    ui.div(ui.input_radio_buttons("niveau_comp", "Échelon", _niveaux,
                                                  selected="prefecture", inline=True),
                           ui.output_ui("choix_comp")),
                    output_widget("radar_piliers"),
                    col_widths=[4, 8]),
                output_widget("barres_ispe"),
                ui.output_data_frame("table_comp"),
            ),
            title=ui.span(icon_svg("ranking-star"), " Priorisation des investissements"),
            id="onglets",
        ),
    )


@module.server
def priorisation_server(input, output, session, onglet_actif=None):
    SIMU.simulateur_server("simulateur")

    # ---------------- Vue nationale ----------------
    @render.ui
    def carte_priorites():
        niv = input.niveau_nat()
        return ui.HTML(C.carte_leaflet(C.SF[niv], "niveau_priorite", "Niveau de priorité",
                                       niv, categorielle=True, hauteur=640))

    @render_widget
    def donut():
        import plotly.graph_objects as go
        d = C.ISPE[input.niveau_nat()]["niveau_priorite"].value_counts()
        d = d.reindex([k for k in C.PAL_PRIORITE if k in d.index])
        fig = go.Figure(go.Pie(labels=d.index, values=d.values, hole=.55,
                               marker=dict(colors=[C.PAL_PRIORITE[k] for k in d.index])))
        return C.theme_plotly(fig, "Répartition par niveau de priorité", hauteur=280)

    @render.data_frame
    def classement():
        niv = input.niveau_nat()
        d = C.ISPE[niv].sort_values("rang")[["rang"] + C.cles(niv) + ["ispe", "niveau_priorite"]]
        d.columns = ["Rang"] + [C.NIVEAUX_LABELS[c] for c in C.cles(niv)] + ["ISPE", "Priorité"]
        return render.DataGrid(d, width="100%", height="560px", filters=True)

    @render.download(filename=lambda: f"carte_priorites_{date.today():%Y%m%d}.png")
    def dl_carte_png():
        niv = input.niveau_nat()
        yield C.exporter_carte(C.SF[niv], "niveau_priorite",
                               "Carte nationale des priorités éducatives",
                               f"Maille : {C.NIVEAUX_LABELS[niv]} — ISPE", "png",
                               categorielle=True)

    # ---------------- Fiche territoire ----------------
    @render.ui
    def choix_prefecture():
        if input.niveau_fiche() == "region":
            return None
        prefs = sorted(C.IND["prefecture"].loc[
            C.IND["prefecture"]["region"] == input.region_fiche(), "prefecture"].tolist())
        return ui.input_select("prefecture_fiche", "Préfecture", prefs)

    @render.ui
    def choix_commune():
        if input.niveau_fiche() != "commune":
            return None
        try:
            pref = input.prefecture_fiche()
        except Exception:
            return None
        comms = sorted(C.IND["commune"].loc[
            C.IND["commune"]["prefecture"] == pref, "commune"].tolist())
        return ui.input_select("commune_fiche", "Commune", comms)

    @reactive.calc
    def territoire():
        niv = input.niveau_fiche()
        if niv == "region":
            nom = input.region_fiche()
        elif niv == "prefecture":
            nom = input.prefecture_fiche()
        else:
            nom = input.commune_fiche()
        return niv, nom

    @reactive.calc
    def fiche():
        niv, nom = territoire()
        e = C.EXPL[niv]
        ligne = e[e[niv] == nom]
        i = C.ISPE[niv]
        return ligne.iloc[0], i[i[niv] == nom].iloc[0]

    @render.ui
    def fiche_score():
        f, _ = fiche()
        niv, _n = territoire()
        return ui.div(
            ui.div(str(f["ispe"]), class_="fiche-ispe"),
            ui.div(f"Rang {int(f['rang'])} sur {len(C.ISPE[niv])} au niveau national",
                   class_="fiche-rang"),
            ui.div(_badge(f["niveau_priorite"]), style="margin-top:10px;"))

    @render.ui
    def fiche_classe():
        f, _ = fiche()
        niv, _n = territoire()
        if pd.isna(f.get("classe")):
            return ui.h5("Échelon régional — profil hérité des communes",
                         style="color:#00563F;font-weight:700;")
        p = C.PROFILS[(C.PROFILS["niveau"] == niv) & (C.PROFILS["classe"] == f["classe"])]
        titre = ui.h5(f["libelle_classe"], style="color:#00563F;font-weight:700;margin-top:0;")
        if len(p):
            p = p.iloc[0]
            return ui.div(titre, ui.p(p["description"], style="font-size:13.5px;color:#444;"),
                          ui.span(f"{int(p['effectif'])} territoires partagent ce profil "
                                  f"(ISPE moyen : {p['ispe_moyen']}).",
                                  style="color:#888;font-size:12.5px;"))
        return titre

    @render.ui
    def fiche_explication():
        f, _ = fiche()
        return ui.div(f["explication"], class_="encart-explication")

    @render.ui
    def fiche_forces():
        f, _ = fiche()
        return ui.div(ui.tags.b("Points forts", style="color:#2E7D32;"),
                      ui.tags.ul(*[ui.tags.li(x) for x in str(f["points_forts"]).split("|")],
                                 class_="liste-points"))

    @render.ui
    def fiche_faiblesses():
        f, _ = fiche()
        return ui.div(ui.tags.b("Insuffisances", style="color:#C62828;"),
                      ui.tags.ul(*[ui.tags.li(x) for x in str(f["points_faibles"]).split("|")],
                                 class_="liste-points"))

    @render_widget
    def fiche_contributions():
        _, i = fiche()
        d = pd.DataFrame({
            "pilier": list(LIB_PILIERS.values()),
            "contribution": [i[c.replace("deficit_", "contrib_")] for c in LIB_PILIERS]})
        fig = C.barres(d, "pilier", "contribution",
                       "Contribution des quatre dimensions au score ISPE", hauteur=240)
        fig.update_xaxes(title="%", range=[0, 60])
        return fig

    @reactive.calc
    def recos_territoire():
        niv, nom = territoire()
        r = C.RECO[niv]
        d = r[r[niv] == nom][["ordre", "action", "dimension", "impact_attendu",
                              "confiance", "justification"]].copy()
        d.columns = ["Ordre", "Investissement recommandé", "Dimension",
                     "Impact attendu", "Confiance (%)", "Justification"]
        return d

    @render.data_frame
    def fiche_recos():
        return render.DataGrid(recos_territoire(), width="100%")

    def _fiche_export():
        f, i = fiche()
        niv, nom = territoire()
        ind = C.IND[niv]
        ind = ind[ind[niv] == nom].iloc[0]
        lignes = [("Score ISPE", f["ispe"]), ("Rang national", int(f["rang"])),
                  ("Niveau de priorité", f["niveau_priorite"]),
                  ("Classe (profil HCPC)", f.get("classe", "-"))]
        lignes += [(C.LIB[v], ind[v]) for v in C.LIB if v in ind.index]
        return pd.DataFrame(lignes, columns=["Indicateur", "Valeur"])

    @render.download(filename=lambda: f"fiche_{territoire()[1]}_{date.today():%Y%m%d}.xlsx")
    def dl_fiche_excel():
        yield C.exporter_excel({"Synthese": _fiche_export(),
                                "Recommandations": recos_territoire()})

    @render.download(filename=lambda: f"fiche_{territoire()[1]}_{date.today():%Y%m%d}.csv")
    def dl_fiche_csv():
        yield C.exporter_csv(_fiche_export())

    @render.download(filename=lambda: f"carte_{territoire()[1]}_{date.today():%Y%m%d}.png")
    def dl_fiche_carte():
        niv, nom = territoire()
        f, _ = fiche()
        yield C.exporter_carte(C.SF[niv], "niveau_priorite",
                               f"{C.NIVEAUX_LABELS[niv]} — {nom}",
                               f"Score ISPE : {f['ispe']} | {f['niveau_priorite']}",
                               "png", categorielle=True)

    # ---------------- Résultats scolaires ----------------
    def _serie(indicateur):
        d = C.SERIES[(C.SERIES["indicateur"] == indicateur) & (C.SERIES["secteur"] == "Total")
                     & (C.SERIES["niveau"] != "Total")]
        return d

    @render_widget
    def res_reussite():
        return C.series_temporelles(_serie("Résultats de l'examen de compétence"), "niveau",
                                    "Taux de réussite à l'examen de compétence par niveau", "%")

    @render_widget
    def res_scolarisation():
        return C.series_temporelles(_serie("Taux de scolarisation"), "niveau",
                                    "Taux de scolarisation — évolution", "%")

    @render_widget
    def res_achevement():
        return C.series_temporelles(_serie("Taux d'achèvement ou de diplomation"), "niveau",
                                    "Taux d'achèvement ou de diplomation", "%")

    @render_widget
    def res_contribution():
        d = C.ISPE["prefecture"].nlargest(15, "contrib_resultats")
        fig = C.barres(d, "prefecture", "contrib_resultats",
                       "Contribution du pilier résultats au score ISPE (top 15 préfectures)",
                       couleur=C.TG_ROUGE, hauteur=360)
        fig.update_xaxes(title="%")
        return fig

    # ---------------- Comparaison ----------------
    @render.ui
    def choix_comp():
        niv = input.niveau_comp()
        return ui.input_selectize("territoires_comp", "Territoires à comparer",
                                  sorted(C.ISPE[niv][niv].tolist()), multiple=True)

    @reactive.calc
    def d_comp():
        niv = input.niveau_comp()
        sel = list(input.territoires_comp() or [])
        return C.ISPE[niv][C.ISPE[niv][niv].isin(sel)]

    @render_widget
    def radar_piliers():
        niv = input.niveau_comp()
        d = d_comp()
        axes = ["Couverture scolaire", "Infrastructures", "Capacité enseignante",
                "Conditions de réussite", "Score ISPE"]
        traces = [(r[niv], [r["deficit_couverture"], r["deficit_infrastructures"],
                            r["deficit_enseignants"], r["deficit_resultats"], r["ispe"]])
                  for _, r in d.iterrows()]
        return C.radar(traces, axes,
                       "Déficits par dimension (0 = aucun besoin, 100 = besoin maximal)")

    @render_widget
    def barres_ispe():
        niv = input.niveau_comp()
        d = d_comp().sort_values("ispe", ascending=False)
        couleurs = d["niveau_priorite"].map(C.PAL_PRIORITE).tolist()
        fig = C.barres(d, niv, "ispe", "Scores ISPE comparés",
                       couleurs=couleurs, horizontal=False, hauteur=320)
        fig.update_yaxes(range=[0, 100], title="ISPE")
        return fig

    @render.data_frame
    def table_comp():
        niv = input.niveau_comp()
        d = d_comp()[C.cles(niv) + ["ispe", "rang", "niveau_priorite", "deficit_couverture",
                                    "deficit_infrastructures", "deficit_enseignants",
                                    "deficit_resultats"]].copy()
        d.columns = [C.NIVEAUX_LABELS[c] for c in C.cles(niv)] + \
            ["ISPE", "Rang", "Priorité", "Déficit couverture", "Déficit infrastructures",
             "Déficit enseignants", "Déficit cond. réussite"]
        return render.DataGrid(d, width="100%")
