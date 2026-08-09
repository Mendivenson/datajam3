library(leaflet)
library(igraph)
library(sf)
library(htmltools)

# 1. Nodos
nodes_df <- data.frame(
  id  = vertex.attributes(tm.graph)$id,
  lon = vertex.attributes(tm.graph)$longitude,
  lat = vertex.attributes(tm.graph)$latitude,
  stringsAsFactors = FALSE
)

# 2. Atributos de aristas
edges_idx <- as_edgelist(tm.graph, names = FALSE)
weight    <- edge.attributes(tm.graph)$weight
svc_names <- edge.attributes(tm.graph)$`services names`  # lista por fila

# 3. Construir geometría LINESTRING por arista
edge_lines <- lapply(seq_len(nrow(edges_idx)), function(i) {
  st_linestring(matrix(
    c(nodes_df$lon[edges_idx[i, 1]], nodes_df$lat[edges_idx[i, 1]],
      nodes_df$lon[edges_idx[i, 2]], nodes_df$lat[edges_idx[i, 2]]),
    ncol = 2, byrow = TRUE
  ))
})

# 4. Etiqueta HTML por arista: negrita + lista de servicios separada por comas
edge_labels <- mapply(function(w, svc) {
  HTML(sprintf(
    "<b>Servicios totales:</b> %s<br><b>Servicios:</b> %s",
    w,
    paste(svc, collapse = ", ")
  ))
}, weight, svc_names, SIMPLIFY = FALSE)

# 5. Ensamblar sf con geometría + atributos
edges_sf <- st_sf(
  weight = weight,
  label  = I(edge_labels),   # I() para que quede como lista-columna, no se aplane
  geometry = st_sfc(edge_lines, crs = 4326)
)

# 6. Mapa
m <- leaflet(nodes_df) |>
  addProviderTiles(providers$CartoDB.Positron) |>
  setView(
    lng = mean(range(nodes_df$lon)),
    lat = mean(range(nodes_df$lat)),
    zoom = 13
  ) |>
  addPolylines(
    data = edges_sf,
    color = "red",
    weight = 1,
    opacity = 0.6,
    label = ~label,
    labelOptions = labelOptions(
      style = list("font-size" = "11px"),
      direction = "auto",
      textOnly = FALSE   # importante: FALSE para que interprete el HTML (negritas, <br>)
    ),
    highlightOptions = highlightOptions(
      weight = 3,
      color = "steelblue",
      opacity = 1,
      bringToFront = TRUE
    )
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
