library(leaflet)
library(igraph)

nodes_df <- data.frame(
  id  = vertex.attributes(tm.graph)$id,
  lon = vertex.attributes(tm.graph)$longitude,
  lat = vertex.attributes(tm.graph)$latitude,
  stringsAsFactors = FALSE
)

edges_idx <- as_edgelist(tm.graph, names = FALSE)

# Construir vectores lng/lat con NA como separador de segmentos
edge_lng <- as.vector(rbind(
  nodes_df$lon[edges_idx[, 1]],
  nodes_df$lon[edges_idx[, 2]],
  NA
))

edge_lat <- as.vector(rbind(
  nodes_df$lat[edges_idx[, 1]],
  nodes_df$lat[edges_idx[, 2]],
  NA
))

m <- leaflet(nodes_df) |>
  addProviderTiles(providers$CartoDB.Positron) |>
  setView(
    lng = mean(range(nodes_df$lon)),
    lat = mean(range(nodes_df$lat)),
    zoom = 13
  ) |>
  addPolylines(
    lng = edge_lng,
    lat = edge_lat,
    color = "red",
    weight = 1,
    opacity = 0.6
  ) |>
  addCircleMarkers(
    data = nodes_df,
    lng = ~lon,
    lat = ~lat,
    radius = 5,
    color = "salmon",
    fillColor = "salmon",
    fillOpacity = 0.9,
    stroke = TRUE,
    weight = 1,
    label = ~id,
    labelOptions = labelOptions(
      style = list("font-size" = "11px"),
      direction = "auto",
      textOnly = TRUE
    )
  )

m

