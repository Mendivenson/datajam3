route_name <- function(route.id, graph){

  # Nombre de una ruta a partir de su id, buscando en la lista de servicios de cada tramo (los ids
  # y los nombres van alineados posicionalmente dentro de 'services_flat'/'services_names_flat').

  ids     <- strsplit(igraph::edge_attr(graph, 'services_flat'), ';')
  nombres <- strsplit(igraph::edge_attr(graph, 'services_names_flat'), ';')

  for (i in seq_along(ids)) {
    pos <- which(ids[[i]] == route.id)
    if (length(pos) > 0) return(nombres[[i]][pos[1]])
  }

  return(NA)
}

route_edge_count <- function(route.id, graph){

  # Cantidad de tramos que cubre una ruta.

  sum(sapply(strsplit(igraph::edge_attr(graph, 'services_flat'), ';'), function(x) route.id %in% x))
}

route_covers <- function(route.id, graph){

  # Vector lógico: qué tramos del grafo cubre la ruta (para no repetir el strsplit en cada función).

  sapply(strsplit(igraph::edge_attr(graph, 'services_flat'), ';'), function(x) route.id %in% x)
}

route_redundancy <- function(route.id, graph){

  # Redundancia promedio de una ruta: cuántas OTRAS rutas comparten, en promedio, cada uno de sus
  # tramos (peso del tramo menos 1, ya que el peso cuenta la ruta misma). Valores bajos indican
  # tramos exclusivos, más difíciles de reemplazar si la ruta se elimina.

  cubre <- route_covers(route.id, graph)
  pesos <- igraph::edge_attr(graph, 'weight')[cubre]

  return(mean(pesos - 1))
}

route_stations <- function(route.id, graph){

  # Estaciones (id) que cubre una ruta: extremos de todos los tramos donde aparece en 'services_flat'.

  cubre    <- route_covers(route.id, graph)
  extremos <- igraph::ends(graph, igraph::E(graph)[cubre], names = TRUE)

  return(unique(as.vector(extremos)))
}
