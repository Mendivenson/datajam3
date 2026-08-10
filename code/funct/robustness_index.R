robustness_curve <- function(graph, order = NULL){

  # Esta función calcula, para un orden de remoción de nodos (estaciones) dado, el tamaño del
  # componente (débilmente) conexo más grande después de remover cada estación, como fracción del
  # tamaño original de la red. Es la curva de robustez de Schneider et al. (2011). 'order' se recibe
  # como los nombres (id) de las estaciones, no como una secuencia de vértices, para que siga
  # siendo válido a medida que se van eliminando nodos del grafo.

  # los grafos nulos del modelo de configuración no traen nombres de vértice; se les asignan unos
  # temporales para poder remover por nombre sin que el orden se desalinee al reducir el grafo
  if (is.null(igraph::V(graph)$name)) {
    igraph::V(graph)$name <- as.character(seq_len(igraph::vcount(graph)))
  }

  if (is.null(order)) {
    order <- sample(igraph::V(graph)$name)
  }

  n <- igraph::vcount(graph)
  tamanos <- numeric(n + 1)
  tamanos[1] <- 1  # antes de remover nada, el componente más grande es el 100% de la red

  grafo.actual <- graph
  for (paso in seq_along(order)) {
    grafo.actual <- igraph::delete_vertices(grafo.actual, order[paso])
    componentes  <- igraph::components(grafo.actual, mode = 'weak')
    tamanos[paso + 1] <- if (igraph::vcount(grafo.actual) == 0) 0 else max(componentes$csize) / n
  }

  return(tamanos)
}

robustness_index <- function(graph, order = NULL){

  # Índice de robustez R (Schneider et al., 2011): promedio del tamaño del componente más grande a
  # lo largo de toda la secuencia de remoción, normalizado entre 0 y 1. Un R más alto significa una
  # red más robusta frente al orden de remoción dado (aleatorio o dirigido según el 'order' que se
  # le pase).

  curva <- robustness_curve(graph, order)
  return(mean(curva))
}
