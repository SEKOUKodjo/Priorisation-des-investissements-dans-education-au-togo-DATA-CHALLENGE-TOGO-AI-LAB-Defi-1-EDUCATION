# =============================================================================
# mod_dimension.py — Module générique : Couverture / Infrastructures / Enseignants
# =============================================================================
from datetime import date

import pandas as pd
from shiny import module, ui, render, reactive, req
from shinywidgets import output_widget, render_widget
from faicons import icon_svg

import commun as C

CONFIG = {
    "couverture": dict(
        titre="Couverture scolaire", icone="school",
        variables_carte={
            "nb_etab": "Nombre d'établissements",
            "densite_etab_100km2": "Établissements pour 100 km²",
            "completude_offre": "Complétude du cycle éducatif (%)",
            "jardins_100_primaires": "Jardins d'enfants pour 100 primaires",
            "nb_primaire": "Écoles primaires", "nb_college": "Collèges", "nb_lycee": "Lycées"},
        variables_comparaison=["nb_etab", "densite_etab_100km2", "completude_offre",
                               "jardins_100_primaires", "nb_prescolaire", "nb_primaire",
                               "nb_college", "nb_lycee"]),
    "infrastructures": dict(
        titre="Infrastructures essentielles", icone="building",
        variables_carte={
            "toilettes_100_etab": "Toilettes pour 100 établissements",
            "pct_toilettes_ameliorees": "Toilettes améliorées (%)",
            "pct_batiments_recents": "Bâtiments récents — depuis 2010 (%)",
            "batiments_par_etab": "Bâtiments par établissement",
            "pct_terrain_sport": "Terrains de sport (%)",
            "biblio_100_etab": "Bibliothèques pour 100 établissements"},
        variables_comparaison=["toilettes_100_etab", "pct_toilettes_ameliorees",
                               "pct_batiments_recents", "batiments_par_etab",
                               "pct_terrain_sport", "biblio_100_etab"]),
    "enseignants": dict(
        titre="Capacité enseignante", icone="chalkboard-user",
        variables_carte={
            "enseignants_prescolaire": "Enseignants du préscolaire",
            "ens_100_jardins": "Enseignants pour 100 jardins d'enfants",
            "enseignants_100_etab": "Enseignants pour 100 établissements"},
        variables_comparaison=["enseignants_prescolaire", "ens_100_jardins",
                               "enseignants_100_etab", "nb_prescolaire"]),
}

_choix_niveaux = {"region": "Région", "prefecture": "Préfecture", "commune": "Commune"}


@module.ui
def dimension_ui(dim: str):
    cfg = CONFIG[dim]
    return ui.div(
        ui.output_ui("kpis"),
        ui.navset_card_pill(
            ui.nav_panel(
                "Indicateurs",
                ui.layout_columns(
                    ui.input_radio_buttons("niveau_ind", "Échelon territorial",
                                           _choix_niveaux, selected="prefecture", inline=True),
                    col_widths=[6]),
                ui.layout_columns(
                    output_widget("graphique1"), output_widget("graphique2"),
                    col_widths=[6, 6]),
                ui.output_data_frame("table_indicateurs"),
            ),
            ui.nav_panel(
                "Cartographie",
                ui.layout_columns(
                    ui.div(
                        ui.input_select("var_carte", "Indicateur cartographié",
                                        {k: v for k, v in cfg["variables_carte"].items()}),
                        ui.input_radio_buttons("niveau_carte", "Maille", _choix_niveaux,
                                               selected="commune", inline=True),
                        ui.input_selectize("filtre_region", "Filtrer par région",
                                           sorted(C.IND["commune"]["region"].unique().tolist()),
                                           multiple=True),
                        ui.input_switch("montrer_points", "Afficher les établissements", False),
                        ui.tags.hr(),
                        ui.tags.b("Télécharger la carte affichée"),
                        ui.tags.p("Avec filtres, légende et titre.",
                                  style="font-size:12px;color:#777;"),
                        ui.download_button("dl_png", "PNG haute résolution",
                                           class_="btn-outline-success btn-sm w-100 mb-1"),
                        ui.download_button("dl_pdf", "PDF", class_="btn-outline-success btn-sm w-100 mb-1"),
                        ui.download_button("dl_jpeg", "JPEG", class_="btn-outline-success btn-sm w-100"),
                    ),
                    ui.output_ui("carte"),
                    col_widths=[3, 9]),
            ),
            ui.nav_panel(
                "Comparaison",
                ui.layout_columns(
                    ui.div(
                        ui.input_radio_buttons("niveau_comp", "Échelon", _choix_niveaux,
                                               selected="prefecture", inline=True),
                        ui.output_ui("choix_comparaison")),
                    output_widget("radar_comp"),
                    col_widths=[4, 8]),
                output_widget("barres_comp"),
                ui.output_data_frame("table_comp"),
            ),
            ui.nav_panel(
                "Export",
                ui.layout_columns(
                    ui.div(
                        ui.input_radio_buttons("niveau_export", "Échelon à exporter",
                                               _choix_niveaux, selected="commune", inline=True),
                        ui.download_button("dl_excel", "Excel (.xlsx)", class_="btn-success w-100 mb-1"),
                        ui.download_button("dl_csv", "CSV", class_="btn-outline-success w-100")),
                    ui.output_data_frame("apercu_export"),
                    col_widths=[4, 8]),
            ),
            title=ui.span(icon_svg(cfg["icone"]), " " + cfg["titre"]),
            id="onglets",
        ),
    )


@module.server
def dimension_server(input, output, session, dim: str, onglet_actif=None):
    cfg = CONFIG[dim]
    vars_dim = [v for v in dict.fromkeys(cfg["variables_comparaison"]
                                          + list(cfg["variables_carte"]))
                if v in C.IND["commune"].columns]

    # ---------- KPIs ----------
    @render.ui
    def kpis():
        i = C.IND["commune"]
        if dim == "couverture":
            valeurs = [(C.fmt(C.META["nb_etablissements"]), "Établissements scolaires", "school"),
                       (C.fmt(i["nb_primaire"].sum()), "Écoles primaires", "children"),
                       (C.fmt1(i["completude_offre"].mean()) + " %", "Complétude moyenne du cycle", "layer-group"),
                       (C.fmt(C.META["nb_communes"]), "Communes couvertes", "map")]
        elif dim == "infrastructures":
            valeurs = [(C.fmt(C.META["nb_toilettes"]), "Points de toilettes recensés", "restroom"),
                       (C.fmt(C.META["nb_batiments"]), "Bâtiments scolaires", "building"),
                       (C.fmt1(i["pct_toilettes_ameliorees"].mean()) + " %", "Toilettes améliorées (moyenne)", "droplet"),
                       (C.fmt1(i["pct_terrain_sport"].mean()) + " %", "Établissements avec terrain de sport", "futbol")]
        else:
            p = C.IND["prefecture"]
            valeurs = [(C.fmt(C.META["nb_enseignants_prescolaire"]), "Enseignants du préscolaire", "chalkboard-user"),
                       (C.fmt1(p["ens_100_jardins"].median()), "Enseignants / 100 jardins (médiane)", "users"),
                       (C.fmt(i["nb_prescolaire"].sum()), "Jardins d'enfants", "shapes"),
                       (C.fmt((p["ens_100_jardins"] < p["ens_100_jardins"].quantile(.25)).sum()),
                        "Préfectures sous-dotées (quartile inf.)", "triangle-exclamation")]
        themes = ["success", "primary", "warning", "danger"]
        return ui.layout_columns(
            *[ui.value_box(t, v, showcase=icon_svg(ic), theme=th)
              for (v, t, ic), th in zip(valeurs, themes)],
            col_widths=[3, 3, 3, 3])

    # ---------- Indicateurs ----------
    @render_widget
    def graphique1():
        if dim == "couverture":
            rep = C.POINTS["categorie"].value_counts()
            import plotly.graph_objects as go
            fig = go.Figure(go.Pie(labels=rep.index, values=rep.values, hole=0))
            return C.theme_plotly(fig, "Répartition nationale par type d'établissement")
        if dim == "infrastructures":
            d = C.UIS_INFRA[C.UIS_INFRA["indicateur"].str.contains("lectrifi")]
            return C.series_temporelles(d, "indicateur",
                                        "Électrification des établissements (national, UNESCO-ISU)", "%")
        d = C.UIS_RATIO
        return C.series_temporelles(d, "indicateur",
                                    "Ratio élèves / enseignant (national, UNESCO-ISU)")

    @render_widget
    def graphique2():
        niv = input.niveau_ind()
        var = {"couverture": "nb_etab", "infrastructures": "toilettes_100_etab",
               "enseignants": "ens_100_jardins"}[dim]
        d = C.IND[niv].nlargest(20, var)
        titre = {"couverture": "Répartition territoriale des établissements",
                 "infrastructures": "Toilettes pour 100 établissements",
                 "enseignants": "Encadrement préscolaire par territoire"}[dim]
        return C.barres(d, niv, var, titre + (" (top 20)" if len(C.IND[niv]) > 20 else ""))

    @render.data_frame
    def table_indicateurs():
        niv = input.niveau_ind()
        d = C.IND[niv][C.cles(niv) + vars_dim].copy()
        d.columns = [C.NIVEAUX_LABELS.get(c, C.LIB.get(c, c)) for c in d.columns]
        return render.DataGrid(d, width="100%", height="380px", filters=True)

    # ---------- Cartographie ----------
    def couche_filtree():
        g = C.SF[input.niveau_carte()]
        regs = list(input.filtre_region())
        if regs:
            g = g[g["region"].isin(regs)]
        return g

    @render.ui
    def carte():
        g = couche_filtree()
        pts = None
        if input.montrer_points():
            pts = C.POINTS
            regs = list(input.filtre_region())
            if regs:
                pts = pts[pts["region"].isin(regs)]
        return ui.HTML(C.carte_leaflet(g, input.var_carte(),
                                       cfg["variables_carte"][input.var_carte()],
                                       input.niveau_carte(), points=pts))

    def _export_carte(fm):
        g = couche_filtree()
        regs = list(input.filtre_region())
        sous = ("Régions : " + ", ".join(regs)) if regs else "Ensemble du territoire national"
        return C.exporter_carte(
            g, input.var_carte(),
            f"{cfg['titre']} — {cfg['variables_carte'][input.var_carte()]}",
            f"{sous} · Maille : {C.NIVEAUX_LABELS[input.niveau_carte()]}", fm)

    @render.download(filename=lambda: f"carte_{dim}_{date.today():%Y%m%d}.png")
    def dl_png():
        yield _export_carte("png")

    @render.download(filename=lambda: f"carte_{dim}_{date.today():%Y%m%d}.pdf")
    def dl_pdf():
        yield _export_carte("pdf")

    @render.download(filename=lambda: f"carte_{dim}_{date.today():%Y%m%d}.jpeg")
    def dl_jpeg():
        yield _export_carte("jpeg")

    # ---------- Comparaison ----------
    @render.ui
    def choix_comparaison():
        niv = input.niveau_comp()
        return ui.input_selectize("territoires_comp", "Territoires à comparer",
                                  sorted(C.IND[niv][niv].tolist()), multiple=True)

    @reactive.calc
    def d_comp():
        niv = input.niveau_comp()
        sel = list(input.territoires_comp() or [])
        return C.IND[niv][C.IND[niv][niv].isin(sel)]

    @render_widget
    def radar_comp():
        niv = input.niveau_comp()
        d = d_comp()
        ens = C.IND[niv]
        axes = [C.LIB.get(v, v) for v in cfg["variables_comparaison"]]
        traces = []
        for _, ligne in d.iterrows():
            vals = [float((ens[v] <= ligne[v]).mean() * 100)
                    for v in cfg["variables_comparaison"]]
            traces.append((ligne[niv], vals))
        return C.radar(traces, axes, "Positionnement relatif (percentile national)")

    @render_widget
    def barres_comp():
        import plotly.graph_objects as go
        niv = input.niveau_comp()
        d = d_comp()
        fig = go.Figure()
        for i, (_, ligne) in enumerate(d.iterrows()):
            fig.add_trace(go.Bar(
                name=ligne[niv],
                x=[C.LIB.get(v, v) for v in cfg["variables_comparaison"]],
                y=[ligne[v] for v in cfg["variables_comparaison"]],
                marker_color=C.COULEURS_SERIES[i % 6]))
        fig.update_layout(barmode="group")
        return C.theme_plotly(fig, "Comparaison des indicateurs (valeurs brutes)")

    @render.data_frame
    def table_comp():
        niv = input.niveau_comp()
        d = d_comp()[C.cles(niv) + cfg["variables_comparaison"]].copy()
        d.columns = [C.NIVEAUX_LABELS.get(c, C.LIB.get(c, c)) for c in d.columns]
        return render.DataGrid(d, width="100%")

    # ---------- Export ----------
    def d_export():
        niv = input.niveau_export()
        d = C.IND[niv][C.cles(niv) + vars_dim].copy()
        d.columns = [C.NIVEAUX_LABELS.get(c, C.LIB.get(c, c)) for c in d.columns]
        return d

    @render.data_frame
    def apercu_export():
        return render.DataGrid(d_export(), width="100%", height="420px")

    @render.download(filename=lambda: f"{dim}_indicateurs_{date.today():%Y%m%d}.xlsx")
    def dl_excel():
        yield C.exporter_excel({cfg["titre"][:31]: d_export()})

    @render.download(filename=lambda: f"{dim}_indicateurs_{date.today():%Y%m%d}.csv")
    def dl_csv():
        yield C.exporter_csv(d_export())
