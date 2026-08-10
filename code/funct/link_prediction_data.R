station_distance_matrix <- function(graph){

  # Matriz de distancias geográficas (en km) entre todas las estaciones, usando la fórmula de
  # Haversine sobre latitud/longitud. Sirve como covariable de arista para los modelos de
  # predicción de enlaces (ERGM / espacio latente).

  latitud   <- igraph::vertex_attr(graph, 'latitude')
  longitud  <- igraph::vertex_attr(graph, 'longitude')
  nombres   <- igraph::vertex_attr(graph, 'name')

  rad      <- pi / 180
  lat.rad  <- latitud * rad
  lon.rad  <- longitud * rad

  n <- length(latitud)
  distancia <- matrix(0, n, n, dimnames = list(nombres, nombres))

  for (i in seq_len(n - 1)) {
    for (j in (i + 1):n) {
      delta.lat <- lat.rad[j] - lat.rad[i]
      delta.lon <- lon.rad[j] - lon.rad[i]
      a <- sin(delta.lat / 2)^2 + cos(lat.rad[i]) * cos(lat.rad[j]) * sin(delta.lon / 2)^2
      d <- 2 * 6371 * asin(sqrt(a))   # radio de la Tierra en km
      distancia[i, j] <- d
      distancia[j, i] <- d
    }
  }

  return(distancia)
}

build_tm_network <- function(graph, social.path = '../data/estaciones estrato localidad.csv', demand = NULL){

  # Construye el objeto 'network' (paquete network) que usan los modelos ERGM y de espacio latente
  # para proponer rutas nuevas: se simetriza el grafo de TM (interesa si DEBERÍA existir un servicio
  # entre dos estaciones, sin importar el sentido) y se le pegan los atributos sociales por estación.

  if (!file.exists(social.path)) {
    social.path <- sub('^\\.\\./', '', social.path)
  }
  social <- read.csv(social.path)

  nombres <- igraph::vertex_attr(graph, 'name')
  orden   <- match(nombres, social$id.station)

  adyacencia <- as.matrix(igraph::as_adjacency_matrix(graph, sparse = FALSE))
  adyacencia <- ((adyacencia + t(adyacencia)) > 0) * 1
  diag(adyacencia) <- 0

  red <- network::network(adyacencia, matrix.type = 'adjacency', directed = FALSE)

  network::set.vertex.attribute(red, 'name',      nombres)
  network::set.vertex.attribute(red, 'stratum',   social$stratum[orden])
  network::set.vertex.attribute(red, 'locality',  social$locality[orden])
  network::set.vertex.attribute(red, 'latitude',  igraph::vertex_attr(graph, 'latitude'))
  network::set.vertex.attribute(red, 'longitude', igraph::vertex_attr(graph, 'longitude'))

  if (!is.null(demand)) {
    network::set.vertex.attribute(red, 'demand', demand[nombres])
  }

  return(red)
}

rank_missing_dyads <- function(p, red, graph){

  # A partir de una matriz de probabilidades predichas p (n x n, en el mismo orden de vértices que
  # 'red'), devuelve el ranking (de mayor a menor probabilidad) de los pares de estaciones que HOY
  # no tienen un tramo directo — los candidatos a ruta nueva.

  ids     <- network::get.vertex.attribute(red, 'name')
  nombres <- igraph::vertex_attr(graph, 'id')

  adyacencia <- as.matrix(red)
  diag(adyacencia) <- 1

  dimnames(p) <- list(ids, ids)
  p[adyacencia == 1] <- NA
  p[lower.tri(p)]    <- NA

  candidatos <- which(!is.na(p), arr.ind = TRUE)

  tabla <- data.frame(
    'estacion.1'   = nombres[match(rownames(p)[candidatos[, 1]], ids)],
    'estacion.2'   = nombres[match(colnames(p)[candidatos[, 2]], ids)],
    'probabilidad' = p[candidatos]
  )

  return(tabla[order(-tabla$probabilidad), ])
}
