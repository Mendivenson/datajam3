null_graphs <- function(graph, n = 500, max.attempts = 50){

  # Esta función genera n grafos aleatorios que preservan la misma secuencia de grados de entrada
  # y salida del grafo original (modelo de configuración), para poder comparar la robustez real de
  # TM contra la robustez esperable solo por su distribución de grado.

  grado.entrada <- igraph::degree(graph, mode = 'in')
  grado.salida  <- igraph::degree(graph, mode = 'out')

  # un intento de generación; puede fallar si la secuencia de grados no admite un grafo simple, por
  # lo que se reintenta hasta max.attempts veces
  generar.uno <- function(...) {
    intento <- 0
    grafo.nulo <- NULL

    while (is.null(grafo.nulo) && intento < max.attempts) {
      intento <- intento + 1
      grafo.nulo <- tryCatch(
        igraph::sample_degseq(out.deg = grado.salida,
                              in.deg  = grado.entrada,
                              method  = 'edge.switching.simple'),
        error = function(e) NULL
      )
    }

    grafo.nulo
  }

  # Bucle de generación (con barra de progreso)
  grafos.nulos <- pbapply::pblapply(seq_len(n), generar.uno)

  fallidos <- sum(sapply(grafos.nulos, is.null))
  if (fallidos > 0) {
    message(fallidos, ' de ', n, ' réplicas no se pudieron generar (secuencia de grados no admite grafo simple).')
  }

  return(grafos.nulos)
}
