# =============================================================================
# 03_cartes.R — Préparation des données cartographiques
# - Frontières officielles geoBoundaries (5 régions, 37 préfectures)
# - Reconstruction des 39 préfectures et 117 communes du découpage 2019
#   par tessellation de Voronoï des 15 000+ établissements géolocalisés
# Produit : cartes.rds
# =============================================================================

message("== [3/6] Préparation des données cartographiques ==")

sf::sf_use_s2(FALSE)

adm1 <- sf::st_read(file.path(CHEMIN_BRUTES, "geodata/tgo_regions_geoboundaries.geojson"), quiet = TRUE)
adm2 <- sf::st_read(file.path(CHEMIN_BRUTES, "geodata/tgo_prefectures_geoboundaries.geojson"), quiet = TRUE)

togo_contour <- adm1 |> sf::st_make_valid() |> sf::st_union() |> sf::st_as_sf() |>
  sf::st_set_crs(4326)

# ---- Tessellation de Voronoï sur les établissements ---------------------------
pts <- etabs |>
  distinct(lon, lat, .keep_all = TRUE) |>
  select(region, prefecture, commune, lon, lat)

pts_sf <- sf::st_as_sf(pts, coords = c("lon", "lat"), crs = 4326)

vor <- sf::st_voronoi(sf::st_union(sf::st_geometry(pts_sf)),
                      envelope = sf::st_geometry(sf::st_as_sfc(sf::st_bbox(togo_contour) + c(-1, -1, 1, 1))))
vor <- sf::st_collection_extract(sf::st_sf(geometry = sf::st_cast(vor)), "POLYGON")

# Rattache chaque cellule à son établissement d'origine
idx <- sf::st_nearest_feature(sf::st_centroid(vor), pts_sf)
vor$region     <- pts$region[idx]
vor$prefecture <- pts$prefecture[idx]
vor$commune    <- pts$commune[idx]

dissoudre <- function(cellules, cles) {
  cellules |>
    group_by(across(all_of(cles))) |>
    summarise(.groups = "drop") |>
    sf::st_make_valid() |>
    sf::st_intersection(togo_contour) |>
    sf::st_make_valid() |>
    sf::st_collection_extract("POLYGON") |>
    group_by(across(all_of(cles))) |>
    summarise(.groups = "drop") |>
    sf::st_simplify(dTolerance = 0.002, preserveTopology = TRUE) |>
    sf::st_make_valid()
}

carte_communes    <- dissoudre(vor, c("region", "prefecture", "commune"))
carte_prefectures <- dissoudre(vor, c("region", "prefecture"))
carte_regions     <- dissoudre(vor, "region")

# Surfaces (km²) et centroïdes
enrichir <- function(couche) {
  proj <- sf::st_transform(couche, 32631)
  couche$superficie_km2 <- round(as.numeric(sf::st_area(proj)) / 1e6, 1)
  ctr <- suppressWarnings(sf::st_coordinates(sf::st_centroid(sf::st_geometry(couche))))
  couche$ctr_lon <- ctr[, 1]; couche$ctr_lat <- ctr[, 2]
  couche
}
carte_communes    <- enrichir(carte_communes)
carte_prefectures <- enrichir(carte_prefectures)
carte_regions     <- enrichir(carte_regions)

message(sprintf("   Polygones : %s régions, %s préfectures, %s communes",
                nrow(carte_regions), nrow(carte_prefectures), nrow(carte_communes)))

# ---- Couches de points pour les cartes interactives ---------------------------
points_etabs <- etabs |>
  select(region, prefecture, commune, canton, nom, categorie,
         est_public, a_terrain_sport, lon, lat)

cartes <- list(
  regions        = carte_regions,
  prefectures    = carte_prefectures,
  communes       = carte_communes,
  contour        = togo_contour,
  points_etabs   = points_etabs,
  points_toilettes = toilettes |> select(region, prefecture, commune, type, amelioree, lon, lat),
  points_batiments = batiments |> select(region, prefecture, commune, fonction, annee, recent, lon, lat),
  points_creches  = creches |> select(region, prefecture, commune, nom, statut, active, lon, lat),
  points_terrains = terrains,
  points_biblio   = biblio,
  points_sup      = sup,
  source_frontieres = "geoBoundaries (gbOpen) + tessellation de Voronoï des établissements géolocalisés"
)

saveRDS(cartes, file.path(CHEMIN_SORTIES, "cartes.rds"))
message("[OK] cartes.rds enregistré")
