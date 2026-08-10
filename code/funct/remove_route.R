remove_route <- function(graph, route.id){

  # Esta función elimina una ruta del grafo de TM sin reconstruirlo desde cero: por cada tramo
  # donde la ruta aparece en 'services_flat', se le resta su aporte al peso ('weight') y se le
  # quita de la lista de servicios; si el peso de un tramo llega a 0 (la ruta era la única que lo
  # cubría), el tramo desaparece del grafo.

  servicios <- strsplit(igraph::edge_attr(graph, 'services_flat'), ';')
  tiene.ruta <- sapply(servicios, function(x) route.id %in% x)

  if (!any(tiene.ruta)) {
    message('La ruta ', route.id, ' no cubre ningún tramo del grafo; no se modifica nada.')
    return(graph)
  }

  servicios[tiene.ruta] <- lapply(servicios[tiene.ruta], function(x) x[x != route.id])

  peso.nuevo <- igraph::edge_attr(graph, 'weight')
  peso.nuevo[tiene.ruta] <- peso.nuevo[tiene.ruta] - 1

  graph <- igraph::set_edge_attr(graph, 'weight', value = peso.nuevo)
  graph <- igraph::set_edge_attr(graph, 'services_flat',
                                 value = sapply(servicios, paste, collapse = ';'))

  # los tramos que se quedaron en 0 (la ruta era la única que los cubría) desaparecen del grafo
  graph <- igraph::delete_edges(graph, which(peso.nuevo == 0))

  return(graph)
}
