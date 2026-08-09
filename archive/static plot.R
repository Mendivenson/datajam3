# 1. Layout correcto: x = longitud, y = latitud
lay <- cbind(
  x = vertex.attributes(tm.graph)$longitude,
  y = vertex.attributes(tm.graph)$latitude
)

# 2. Bounding box de Bogotá en formato SpatVector (EPSG:4326)
bbox <- vect(
  data.frame(
    x = range(lay[, "x"]),
    y = range(lay[, "y"])
  ),
  geom = c("x", "y"),
  crs = "EPSG:4326"
)

# 3. Descargar los tiles (CartoDB Positron va bien con grafos, fondo limpio)
bogota_tiles <- get_tiles(
  bbox,
  provider = "OpenStreetMap",
  crop = FALSE,
  zoom = 14
)

# 4. Dibujar el mapa y luego el grafo encima
plot(bogota_tiles)

plot(tm.graph,
     add = TRUE,
     rescale = FALSE,
     layout = lay,
     xlim = range(lay[, "x"]),
     ylim = range(lay[, "y"]),
     vertex.label = vertex.attributes(tm.graph)$id,
     vertex.color = 'salmon',
     vertex.frame.color = 'salmon',
     vertex.size = 0.5,
     vertex.label.cex = 0.4,
     edge.arrow.size = 0.05,
     edge.color = 'gray50')
