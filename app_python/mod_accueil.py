# =============================================================================
# mod_accueil.py — Accueil : chiffres clés, carte nationale, Top 10,
# résumé automatique, indicateurs nationaux, rapport national PDF.
# =============================================================================
import io
from datetime import date

import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from shiny import module, ui, render, req
from shinywidgets import output_widget, render_widget
from faicons import icon_svg

import commun as C

_niveaux = {"region": "Régions", "prefecture": "Préfectures", "commune": "Communes"}


@module.ui
def accueil_ui():
    return ui.div(
        ui.div(
            ui.h3("Où investir en priorité pour une éducation plus équitable ?",
                  style="font-weight:800;margin:0;color:white;"),
            ui.p("Ce tableau de bord  d'aide à la prise de décision analyse la couverture scolaire, les infrastructures "
                 "essentielles, la capacité enseignante et les résultats scolaires du Togo pour classer "
                 "automatiquement les territoires selon leur priorité d'investissement.",
                 style="margin:8px 0 0;color:#eafff5;max-width:960px;"),
            style=(f"background:linear-gradient(120deg,{C.TG_VERT_F} 0%,#0a8b64 60%);"
                   "border-radius:14px;padding:22px 26px;margin-bottom:14px;"),
        ),
        ui.layout_columns(
            ui.value_box("Établissements géolocalisés", C.fmt(C.META["nb_etablissements"]),
                         showcase=icon_svg("school"), theme="success"),
            ui.value_box("Régions / Préfectures / Communes",
                         f"{C.META['nb_regions']} / {C.META['nb_prefectures']} / {C.META['nb_communes']}",
                         showcase=icon_svg("map"), theme="primary"),
            ui.value_box("Communes à investissement prioritaire",
                         C.fmt((C.ISPE["commune"]["niveau_priorite"]
                                .isin(["Très prioritaire", "Prioritaire"])).sum()),
                         showcase=icon_svg("triangle-exclamation"), theme="danger"),
            ui.value_box("Enseignants du préscolaire", C.fmt(C.META["nb_enseignants_prescolaire"]),
                         showcase=icon_svg("chalkboard-user"), theme="warning"),
            col_widths=[3, 3, 3, 3]),
        ui.layout_columns(
            ui.div(
                ui.card(
                    ui.card_header(ui.span(icon_svg("map-location-dot"),
                                           " Carte nationale des priorités éducatives")),
                    ui.input_radio_buttons("niveau_carte", None, _niveaux,
                                           selected="commune", inline=True),
                    ui.output_ui("carte_nationale")),
                ui.card(ui.card_header(ui.span(icon_svg("file-lines"), " Résumé automatique")),
                        ui.output_ui("resume_auto")),
            ),
            ui.div(
                ui.card(ui.card_header(ui.span(icon_svg("ranking-star"),
                                               " Top 10 des territoires prioritaires")),
                        ui.input_radio_buttons("niveau_top", None,
                                               {"commune": "Communes", "prefecture": "Préfectures"},
                                               selected="commune", inline=True),
                        output_widget("top10")),
                ui.card(ui.card_header(ui.span(icon_svg("gauge-high"), " Indicateurs nationaux")),
                        ui.output_ui("indicateurs_nationaux")),
                ui.card(ui.card_header(ui.span(icon_svg("clock-rotate-left"), " Dernières mises à jour")),
                        ui.output_ui("mises_a_jour"),
                        ui.download_button("dl_rapport", "Télécharger le rapport national (PDF)",
                                           class_="btn-success w-100")),
            ),
            col_widths=[7, 5]),
    )


@module.server
def accueil_server(input, output, session, onglet_actif=None):

    @render.ui
    def carte_nationale():
        niv = input.niveau_carte()
        return ui.HTML(C.carte_leaflet(C.SF[niv], "niveau_priorite", "Niveau de priorité",
                                       niv, categorielle=True, hauteur=520))

    @render_widget
    def top10():
        niv = input.niveau_top()
        d = C.ISPE[niv].nsmallest(10, "rang")
        couleurs = d["niveau_priorite"].map(C.PAL_PRIORITE).tolist()
        fig = C.barres(d, niv, "ispe", None, couleurs=couleurs, hauteur=360)
        fig.update_xaxes(title="Score ISPE (0-100, plus élevé = plus prioritaire)", range=[0, 100])
        return fig

    @render.ui
    def resume_auto():
        top = C.ISPE["commune"].nsmallest(3, "rang")
        reg = C.ISPE["region"].nsmallest(1, "rang").iloc[0]
        nb_tp = (C.ISPE["commune"]["niveau_priorite"] == "Très prioritaire").sum()
        r = C.SERIES[(C.SERIES["indicateur"] == "Résultats de l'examen de compétence")
                     & (C.SERIES["niveau"] == "Primaire") & (C.SERIES["secteur"] == "Total")]
        r = r.sort_values("annee").iloc[-1]
        t = top.reset_index()
        texte = (
            f"Sur les <b>{C.META['nb_communes']} communes</b> analysées, <b>{nb_tp}</b> ressortent "
            f"comme très prioritaires. Les trois territoires les plus prioritaires sont "
            f"<b>{t.loc[0,'commune']}</b> (ISPE {t.loc[0,'ispe']}), <b>{t.loc[1,'commune']}</b> "
            f"({t.loc[1,'ispe']}) et <b>{t.loc[2,'commune']}</b> ({t.loc[2,'ispe']}). À l'échelle "
            f"régionale, la région <b>{reg['region']}</b> concentre les besoins les plus élevés. "
            f"Au plan national, la réussite à l'examen de compétence au primaire s'établit à "
            f"<b>{C.fmt1(r['valeur'])} %</b> ({int(r['annee'])}). L'analyse combine "
            f"{C.fmt(C.META['nb_etablissements'])} établissements géolocalisés, les infrastructures "
            f"recensées et la capacité enseignante du préscolaire.")
        return ui.div(ui.HTML(texte), class_="encart-explication")

    @render.ui
    def indicateurs_nationaux():
        def derniere(indicateur, niveau="Primaire"):
            d = C.SERIES[(C.SERIES["indicateur"] == indicateur)
                         & (C.SERIES["niveau"] == niveau) & (C.SERIES["secteur"] == "Total")]
            return d.sort_values("annee").iloc[-1]["valeur"] if len(d) else None
        elec = C.UIS_INFRA[C.UIS_INFRA["code"] == "SCHBSP.1.WELEC"].sort_values("annee")
        lignes = [
            ("Écoles (2022)", C.fmt(derniere("Nombre d'écoles", "Total"))),
            ("Enseignants (2022)", C.fmt(derniere("Nombre d'enseignants", "Total"))),
            ("Taux de scolarisation (primaire)", C.fmt1(derniere("Taux de scolarisation")) + " %"),
            ("Taux d'achèvement (primaire)",
             C.fmt1(derniere("Taux d'achèvement ou de diplomation")) + " %"),
            ("Réussite examen de compétence (primaire)",
             C.fmt1(derniere("Résultats de l'examen de compétence")) + " %"),
            ("Écoles primaires électrifiées", C.fmt1(elec.iloc[-1]["valeur"]) + " %"),
        ]
        return ui.tags.table(
            *[ui.tags.tr(ui.tags.td(a),
                         ui.tags.td(b, style="text-align:right;font-weight:700;color:#00563F;"))
              for a, b in lignes],
            class_="table table-sm", style="margin:0;")

    @render.ui
    def mises_a_jour():
        return ui.tags.ul(
            ui.tags.li(ui.tags.b("Prétraitement des données : "), C.META["date_generation"]),
            ui.tags.li(ui.tags.b("Établissements scolaires : "), "geodata.gouv.tg, décembre 2024"),
            ui.tags.li(ui.tags.b("Résultats scolaires : "), "opendata.gouv.tg, séries 2013-2022"),
            ui.tags.li(ui.tags.b("Indicateurs UNESCO-ISU : "), "dernière année 2022"),
            ui.tags.li(ui.tags.b("Enseignants du préscolaire : "), "annuaire 2021-2022"),
            class_="liste-points", style="font-size:13px;")

    @render.download(filename=lambda: f"rapport_national_{date.today():%Y%m%d}.pdf")
    def dl_rapport():
        buf = io.BytesIO()
        with PdfPages(buf) as pdf:
            # Page 1 — synthèse
            fig, ax = plt.subplots(figsize=(11.7, 8.3))
            ax.set_axis_off()
            top10 = C.ISPE["commune"].nsmallest(10, "rang")
            lignes = [
                "RAPPORT NATIONAL — PRIORITÉS D'INVESTISSEMENT ÉDUCATIF AU TOGO", "",
                f"Généré le {date.today():%d/%m/%Y} par le SAD Éducation Togo (version Python)", "",
                f"Territoires : {C.META['nb_regions']} régions, {C.META['nb_prefectures']} préfectures, "
                f"{C.META['nb_communes']} communes",
                f"Établissements : {C.fmt(C.META['nb_etablissements'])} | Bâtiments : "
                f"{C.fmt(C.META['nb_batiments'])} | Toilettes : {C.fmt(C.META['nb_toilettes'])}", "",
                "TOP 10 DES COMMUNES PRIORITAIRES (score ISPE) :"]
            for _, r in top10.iterrows():
                lignes.append(f"   {int(r['rang']):>2}. {r['commune']:<22} ({r['prefecture']})"
                              f"   ISPE : {r['ispe']}  ({r['niveau_priorite']})")
            ax.text(0.02, 0.98, "\n".join(lignes), va="top", fontsize=11, family="monospace",
                    transform=ax.transAxes)
            pdf.savefig(fig); plt.close(fig)
            # Page 2 — carte nationale
            fig, ax = plt.subplots(figsize=(11.7, 8.3))
            C.dessiner_carte_statique(ax, C.SF["commune"], "niveau_priorite",
                                      "Carte nationale des priorités éducatives (communes)",
                                      "Indice Synthétique de Priorité Éducative (ISPE)",
                                      categorielle=True)
            pdf.savefig(fig); plt.close(fig)
        buf.seek(0)
        yield buf.read()
