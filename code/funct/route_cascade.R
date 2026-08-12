edge_load <- function(graph, demand = NULL){

  # Carga de cada tramo: intermediación de arista (topología pura). Si se pasa 'demand' (vector
  # nombrado por id de estación, ej. validaciones + salidas totales de station_stress()), la carga
  # se escala por la demanda promedio (media geométrica) de las dos estaciones extremo del tramo.
  # OJO: esto es una aproximación, no la intermediación exacta pesada por pares origen-destino
  # (que requeriría enumerar caminos más cortos con su multiplicidad, mucho más costoso).

  carga <- igraph::edge_betweenness(graph, directed = TRUE, weights = NA)

  if (!is.null(demand)) {
    # as.numeric() por sí solo borra los nombres (los id de estación); hay que reponerlos
    demand <- setNames(as.numeric(demand), names(demand))

    # se relativiza la demanda (dividiendo por su promedio) para que el factor quede centrado en 1
    # en vez de en la escala absoluta (millones) de validaciones/salidas; de lo contrario, al
    # comparar contra una capacidad que no está ponderada por demanda (ver route_cascade()),
    # cualquier tramo la superaría trivialmente solo por el desajuste de escala, sin importar la ruta
    demand <- demand / mean(demand, na.rm = TRUE)

    extremos        <- igraph::ends(graph, igraph::E(graph), names = TRUE)
    demanda.origen  <- demand[extremos[, 1]]
    demanda.destino <- demand[extremos[, 2]]
    carga <- carga * sqrt(demanda.origen * demanda.destino)
  }

  return(carga)
}

route_cascade <- function(graph, route.id, alpha = 0.2, demand = NULL){

  # Simula el efecto de eliminar una ruta sobre la red, incluyendo posibles fallas en cadena
  # (adaptación de Motter & Lai, 2002): se calcula la carga inicial de cada tramo y se le asigna una
  # capacidad = (1 + alpha) * carga inicial. Se elimina la ruta y se recalcula la carga en el grafo
  # reducido; cualquier tramo que supere su capacidad también falla (se elimina), y se repite hasta
  # que no haya más fallas nuevas.
  #
  # OJO: la capacidad queda anclada a la magnitud de la intermediación (para no desajustar la
  # escala frente a 'carga.actual', que también se mide en esas unidades), pero se modula por
  # 'weight' (cuántas rutas ya sirven el tramo) relativizado por su promedio: un tramo con más
  # rutas que el promedio recibe proporcionalmente más margen de capacidad, y uno con menos,
  # proporcionalmente menos. 'weight' es la medida directa de capacidad instalada (servicio real),
  # mientras que la intermediación por sí sola es ciega a cuánto servicio ya tiene cada tramo.
  # Además, la capacidad nunca se pondera por demanda (es una propiedad de la infraestructura, no
  # depende de cuánta gente la usa), mientras que la carga durante la cascada sí se pondera por
  # demanda si se pasa. Si ambas usaran el mismo factor de demanda (fijo para un tramo dado, porque
  # sus estaciones extremo no cambian), ese factor se cancelaría en la comparación carga > capacidad
  # y la demanda nunca podría cambiar el resultado de la cascada.

  peso.relativo       <- igraph::edge_attr(graph, 'weight') / mean(igraph::edge_attr(graph, 'weight'))
  capacidad.instalada <- edge_load(graph) * peso.relativo
  capacidad           <- (1 + alpha) * capacidad.instalada
  clave.original <- apply(igraph::ends(graph, igraph::E(graph), names = TRUE), 1, paste, collapse = ' -> ')

  grafo.actual   <- remove_route(graph, route.id)
  aristas.caidas <- 0

  repetir <- TRUE
  while (repetir) {
    carga.actual    <- edge_load(grafo.actual, demand)
    clave.actual    <- apply(igraph::ends(grafo.actual, igraph::E(grafo.actual), names = TRUE), 1, paste, collapse = ' -> ')
    capacidad.actual <- capacidad[match(clave.actual, clave.original)]

    sobrecargadas <- which(carga.actual > capacidad.actual)

    if (length(sobrecargadas) == 0) {
      repetir <- FALSE
    } else {
      aristas.caidas <- aristas.caidas + length(sobrecargadas)
      grafo.actual   <- igraph::delete_edges(grafo.actual, sobrecargadas)
    }
  }

  componentes <- igraph::components(grafo.actual, mode = 'weak')

  return(list(
    'grafo final'          = grafo.actual,
    'aristas caidas'       = aristas.caidas,
    'tamaño componente'    = max(componentes$csize) / igraph::vcount(graph)
  ))
}

critical_alpha <- function(graph, route.id, demand = NULL, umbral = 0.05,
                           alpha.min = 0, alpha.max = 6, paso = 0.1){

  # Margen de tolerancia crítico (alpha_c): el valor más pequeño de alpha para el cual, al quitar
  # la ruta, la cascada de fallas NO supera 'umbral' (fracción de tramos caídos sobre el total) Y
  # SE MANTIENE por debajo del umbral para todo alpha mayor hasta alpha.max.
  #
  # OJO: esto se calcula con un barrido fino (no bisección). La cascada NO es necesariamente
  # monótona en alpha (verificado empíricamente: 8 de 10 rutas de prueba mostraron al menos una
  # subida del % de tramos caídos al aumentar alpha, dentro del mismo rango donde se buscaba el
  # umbral) — la bisección asume monotonicidad y puede converger a un punto donde la cascada cruza
  # el umbral una sola vez por casualidad, no al verdadero punto a partir del cual el sistema queda
  # estable. Exigir que se mantenga estable en TODO el resto de la rejilla evita ese falso positivo.

  n.tramos <- igraph::ecount(graph)
  rejilla  <- seq(alpha.min, alpha.max, by = paso)

  caidas  <- sapply(rejilla, function(a) route_cascade(graph, route.id, alpha = a, demand = demand)$`aristas caidas`)
  colapsa <- (caidas / n.tramos) > umbral

  # estable[i] = TRUE solo si NO colapsa en i y tampoco en ningún punto posterior de la rejilla
  estable <- !colapsa
  for (i in rev(seq_along(estable)[-length(estable)])) {
    estable[i] <- estable[i] && estable[i + 1]
  }

  if (!any(estable)) {
    message('La ruta ', route.id, ' sigue en cascada incluso con alpha.max = ', alpha.max,
            '; el umbral crítico está por fuera del rango explorado.')
    return(list('alpha_c' = NA, 'nota' = paste('alpha_c >', alpha.max)))
  }

  alpha_c <- rejilla[which(estable)[1]]

  return(list('alpha_c' = alpha_c, 'rejilla' = rejilla, 'caidas' = caidas))
}
