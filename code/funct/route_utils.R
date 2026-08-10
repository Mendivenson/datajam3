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
