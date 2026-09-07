# =============================================================================
# SAD ÉDUCATION TOGO — version Shiny for Python
# commun.py — chargement des données prétraitées et fonctions partagées.
# AUCUN calcul statistique ici : tout provient du prétraitement R
# (Rscript preprocessing/00_run_all.R puis 07_export_python.R).
# =============================================================================
from pathlib import Path
import json
import io
import unicodedata

import hashlib
import numpy as np
import pandas as pd
import geopandas as gpd
import plotly.graph_objects as go
import folium
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages

DATA = Path(__file__).parent / "data"

# ---- Couleurs institutionnelles (drapeau du Togo) -----------------------------
TG_VERT, TG_VERT_F = "#006A4E", "#00563F"
TG_JAUNE, TG_ROUGE, TG_BLANC = "#FFCE00", "#D21034", "#FFFFFF"

PAL_PRIORITE = {
    "Très prioritaire": "#C62828",
    "Prioritaire":      "#E65100",
    "À surveiller":     "#F9A825",
    "Modéré":           "#7CB342",
    "Satisfaisant":     "#2E7D32",
}
PAL_SEQ = ["#f7fcf5", "#c7e9c0", "#74c476", "#238b45", "#00441b"]
COULEURS_SERIES = [TG_VERT, TG_ROUGE, TG_JAUNE, "#1B5E20", "#8D6E63", "#455A64"]

NIVEAUX = ["region", "prefecture", "commune"]
NIVEAUX_LABELS = {"region": "Région", "prefecture": "Préfecture", "commune": "Commune"}

# ---- Chargement ------------------------------------------------------------------
def _csv(nom):
    return pd.read_csv(DATA / nom, encoding="utf-8")

IND = {n: _csv(f"indicateurs_{n}.csv") for n in NIVEAUX}
ISPE = {n: _csv(f"ispe_{n}.csv") for n in NIVEAUX}
Z = {n: _csv(f"z_{n}.csv") for n in NIVEAUX}
RECO = {n: _csv(f"recommandations_{n}.csv") for n in NIVEAUX}
EXPL = {n: _csv(f"explications_{n}.csv") for n in NIVEAUX}
PROFILS = _csv("profils_classes.csv")
DICO = _csv("dictionnaire.csv")
SERIES = _csv("resultats_series.csv")
UIS_INFRA = _csv("uis_infrastructures.csv")
UIS_RATIO = _csv("uis_ratio.csv")
POINTS = _csv("points_etablissements.csv")
META = json.loads((DATA / "meta.json").read_text(encoding="utf-8"))
SIMUL = json.loads((DATA / "simulation.json").read_text(encoding="utf-8"))

GEO = {
    "region": gpd.read_file(DATA / "carte_regions.geojson"),
    "prefecture": gpd.read_file(DATA / "carte_prefectures.geojson"),
    "commune": gpd.read_file(DATA / "carte_communes.geojson"),
}

LIB = dict(zip(DICO["variable"], DICO["libelle"]))

def cles(niveau):
    return {"region": ["region"], "prefecture": ["region", "prefecture"],
            "commune": ["region", "prefecture", "commune"]}[niveau]

# Couches enrichies : polygones + indicateurs + ISPE
SF = {}
for _n in NIVEAUX:
    _g = GEO[_n].merge(IND[_n], on=cles(_n), how="left", suffixes=("", "_ind"))
    _cols = [c for c in ISPE[_n].columns
             if c in cles(_n) or c.startswith(("deficit_", "contrib_"))
             or c in ("ispe", "rang", "niveau_priorite", "classe")]
    SF[_n] = _g.merge(ISPE[_n][_cols], on=cles(_n), how="left")

def fmt(x):
    try:
        return f"{int(round(float(x))):,}".replace(",", " ")
    except (TypeError, ValueError):
        return str(x)

def fmt1(x):
    try:
        return f"{float(x):.1f}".replace(".", ",")
    except (TypeError, ValueError):
        return str(x)

def normaliser(x):
    x = unicodedata.normalize("NFKD", str(x).lower()).encode("ascii", "ignore").decode()
    return " ".join("".join(c if c.isalnum() else " " for c in x).split())

# ---- Thème plotly ------------------------------------------------------------------
def theme_plotly(fig, titre=None, hauteur=380):
    fig.update_layout(
        template="plotly_white", colorway=COULEURS_SERIES,
        title=dict(text=titre, font=dict(size=15, color="#1a1a1a")) if titre else None,
        font=dict(family="Arial", size=12), height=hauteur,
        margin=dict(l=40, r=20, t=48 if titre else 20, b=40),
        paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
        legend=dict(orientation="h", yanchor="bottom", y=-0.25),
    )
    return fig

def barres(d, x, y, titre=None, couleur=TG_VERT, horizontal=True, couleurs=None, hauteur=380):
    fig = go.Figure(go.Bar(
        x=d[y] if horizontal else d[x], y=d[x] if horizontal else d[y],
        orientation="h" if horizontal else "v",
        marker_color=couleurs if couleurs is not None else couleur))
    if horizontal:
        fig.update_yaxes(autorange="reversed")
    return theme_plotly(fig, titre, hauteur)

def series_temporelles(d, groupe, titre, unite="", hauteur=360):
    fig = go.Figure()
    for i, (g, dd) in enumerate(d.groupby(groupe, sort=False)):
        dd = dd.sort_values("annee")
        fig.add_trace(go.Scatter(x=dd["annee"], y=dd["valeur"], mode="lines+markers",
                                 name=str(g), line=dict(color=COULEURS_SERIES[i % 6])))
    fig.update_yaxes(title=unite)
    return theme_plotly(fig, titre, hauteur)

def radar(traces, axes, titre, hauteur=420):
    fig = go.Figure()
    for nom, vals in traces:
        fig.add_trace(go.Scatterpolar(r=list(vals) + [vals[0]],
                                      theta=axes + [axes[0]],
                                      fill="toself", name=nom, opacity=0.6))
    fig.update_layout(polar=dict(radialaxis=dict(range=[0, 100])))
    return theme_plotly(fig, titre, hauteur)

# ---- Cartes interactives (folium rendues en fichier HTML, intégrées par iframe) -----
# L'iframe a une taille fixe (aucun bug d'onglet masqué) et charge Leaflet dans une
# vraie page. Trois fonds comme dans R Shiny : Fond clair, OpenStreetMap, Satellite,
# avec un sélecteur de couches. Les fichiers sont mis en cache par empreinte.
DOSSIER_CARTES = Path(__file__).parent / "www" / "cartes"
DOSSIER_CARTES.mkdir(parents=True, exist_ok=True)
for _f in DOSSIER_CARTES.glob("*.html"):   # nettoyage au démarrage
    try: _f.unlink()
    except OSError: pass

def _bornes_bins(vals, n=5):
    v = pd.Series(vals).dropna()
    if v.empty or v.min() == v.max():
        return [float(v.min()) if not v.empty else 0.0,
                float(v.min()) + 1 if not v.empty else 1.0]
    return list(np.linspace(float(v.min()), float(v.max()) * 1.0001, n + 1))

def _couleur_seq(val, bornes):
    if pd.isna(val):
        return "#ececec"
    for i in range(len(bornes) - 1):
        if val <= bornes[i + 1] or i == len(bornes) - 2:
            return PAL_SEQ[min(i, len(PAL_SEQ) - 1)]
    return PAL_SEQ[-1]

URL_SATELLITE = ("https://server.arcgisonline.com/ArcGIS/rest/services/"
                 "World_Imagery/MapServer/tile/{z}/{y}/{x}")

# La bibliothèque Leaflet est servie localement (www/lib/leaflet) : l'application
# fonctionne hors ligne pour l'affichage des cartes ; seules les tuiles (fonds de
# carte) nécessitent Internet, exactement comme la version R Shiny.
import re as _re
def _localiser_leaflet(html):
    html = _re.sub(r'https://cdn\.jsdelivr\.net/npm/leaflet@[0-9.]+/dist/leaflet\.js',
                   '/lib/leaflet/leaflet.js', html)
    html = _re.sub(r'https://cdn\.jsdelivr\.net/npm/leaflet@[0-9.]+/dist/leaflet\.css',
                   '/lib/leaflet/leaflet.css', html)
    return html

def carte_leaflet(couche, variable, titre_legende, niveau, categorielle=False,
                  points=None, hauteur=620):
    """Construit la carte folium, l'enregistre en HTML et renvoie une balise
    <iframe> (chaîne HTML) à insérer via ui.HTML()."""
    g = couche.copy()
    g["_nom"] = g[niveau].astype(str)

    if categorielle:
        g["_coul"] = g[variable].map(PAL_PRIORITE).fillna("#ececec")
        entrees_legende = list(PAL_PRIORITE.items())
        g["_val"] = g[variable].fillna("n.d.").astype(str)
        champs = ["_nom", "_val", "ispe", "rang"]
        alias = ["Territoire :", "Priorité :", "Score ISPE :", "Rang :"]
    else:
        bornes = _bornes_bins(g[variable])
        g["_coul"] = g[variable].map(lambda v: _couleur_seq(v, bornes))
        entrees_legende = [(f"{round(bornes[i],1)} – {round(bornes[i+1],1)}",
                            PAL_SEQ[min(i, len(PAL_SEQ) - 1)]) for i in range(len(bornes) - 1)]
        g["_val"] = g[variable].round(1).astype(str)
        champs = ["_nom", "_val"]
        alias = ["Territoire :", titre_legende + " :"]

    # Empreinte pour la mise en cache du fichier
    n_pts = 0 if points is None else len(points)
    cle = f"{niveau}|{variable}|{categorielle}|{hauteur}|{n_pts}|{'.'.join(g['_nom'])}"
    empreinte = hashlib.md5(cle.encode()).hexdigest()[:16]
    fichier = DOSSIER_CARTES / f"{empreinte}.html"

    if not fichier.exists():
        m = folium.Map(location=[8.55, 1.05], zoom_start=7, tiles=None,
                       control_scale=True, width="100%", height="100%")
        folium.TileLayer("cartodbpositron", name="Fond clair", control=True).add_to(m)
        folium.TileLayer("openstreetmap", name="OpenStreetMap", control=True).add_to(m)
        folium.TileLayer(tiles=URL_SATELLITE, attr="Esri", name="Satellite",
                         control=True).add_to(m)

        cols = ["geometry", "_coul"] + [c for c in champs if c not in ("_nom",)] + ["_nom"]
        gj = g[list(dict.fromkeys(cols))].to_json()

        def style_fn(feat):
            return {"fillColor": feat["properties"]["_coul"], "color": "white",
                    "weight": 1, "fillOpacity": 0.78}

        folium.GeoJson(
            gj, name=titre_legende, style_function=style_fn,
            highlight_function=lambda f: {"weight": 2.5, "color": TG_JAUNE,
                                          "fillOpacity": 0.95},
            tooltip=folium.GeoJsonTooltip(fields=champs, aliases=alias, sticky=True),
        ).add_to(m)

        if points is not None and len(points):
            # Cercles simples (Leaflet natif, sans extension CDN) — sous-échantillonnés
            pts = points.dropna(subset=["lat", "lon"])
            if len(pts) > 2500:
                pts = pts.sample(2500, random_state=1)
            fg = folium.FeatureGroup(name="Établissements")
            for r in pts.itertuples():
                folium.CircleMarker([float(r.lat), float(r.lon)], radius=2,
                                    color=TG_ROUGE, weight=0, fill=True,
                                    fill_color=TG_ROUGE, fill_opacity=0.55).add_to(fg)
            fg.add_to(m)

        folium.LayerControl(collapsed=True, position="topleft").add_to(m)

        # Légende HTML (coin bas-droite)
        items = "".join(
            f"<div style='margin:2px 0;'><span style='background:{c};display:inline-block;"
            f"width:14px;height:14px;border-radius:3px;margin-right:6px;vertical-align:middle;'>"
            f"</span>{k}</div>" for k, c in entrees_legende)
        m.get_root().html.add_child(folium.Element(
            f"<div style='position:fixed;bottom:18px;right:12px;z-index:9999;background:white;"
            f"padding:10px 12px;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,.25);"
            f"font-size:12px;line-height:1.3;'><b>{titre_legende}</b><br/>{items}</div>"))
        html = m.get_root().render()
        html = _localiser_leaflet(html)
        fichier.write_text(html, encoding="utf-8")

    return (f"<iframe src='cartes/{empreinte}.html' "
            f"style='width:100%;height:{hauteur}px;border:3px solid {TG_VERT};"
            f"border-radius:10px;box-shadow:0 6px 18px rgba(0,74,55,.18);'></iframe>")

# ---- Export d'images de cartes (matplotlib / geopandas) -----------------------------
def dessiner_carte_statique(ax, couche, variable, titre, sous_titre,
                            categorielle=False):
    if categorielle:
        couleurs = couche[variable].map(PAL_PRIORITE).fillna("#ececec")
        couche.plot(ax=ax, color=couleurs, edgecolor="white", linewidth=0.5)
        for k, c in PAL_PRIORITE.items():
            ax.scatter([], [], c=c, marker="s", s=80, label=k)
        ax.legend(loc="lower right", fontsize=8, title="Légende", frameon=False)
    else:
        couche.plot(ax=ax, column=variable, cmap="Greens", edgecolor="white",
                    linewidth=0.5, legend=True,
                    legend_kwds={"shrink": 0.5},
                    missing_kwds={"color": "#ececec"})
    ax.set_axis_off()
    ax.set_title(titre, fontsize=15, fontweight="bold", loc="left")
    ax.text(0, 1.005, sous_titre, transform=ax.transAxes, fontsize=9, color="#555")
    ax.text(0, -0.02, "SAD Éducation Togo — Sources : geodata.gouv.tg, opendata.gouv.tg, UNESCO-ISU",
            transform=ax.transAxes, fontsize=7, color="#888")

def exporter_carte(couche, variable, titre, sous_titre, format_, categorielle=False):
    fig, ax = plt.subplots(figsize=(11, 10), dpi=300 if format_ != "pdf" else 100)
    dessiner_carte_statique(ax, couche, variable, titre, sous_titre, categorielle)
    buf = io.BytesIO()
    fig.savefig(buf, format="jpg" if format_ == "jpeg" else format_,
                bbox_inches="tight", facecolor="white")
    plt.close(fig)
    buf.seek(0)
    return buf.read()

def exporter_excel(feuilles: dict) -> bytes:
    buf = io.BytesIO()
    with pd.ExcelWriter(buf, engine="openpyxl") as xls:
        for nom, df in feuilles.items():
            df.to_excel(xls, sheet_name=nom[:31], index=False)
    buf.seek(0)
    return buf.read()

def exporter_csv(df) -> bytes:
    return df.to_csv(index=False).encode("utf-8-sig")
