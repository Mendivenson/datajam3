# ------------------- VERIFICACIÓN DE MONOTONICIDAD DE LA CASCADA ------------------
# critical_alpha() busca por búsqueda binaria el alpha mínimo que evita una cascada grande,
# asumiendo que a mayor alpha la cascada es igual o menor (monotonicidad). La literatura de redes
# espacialmente embebidas (ej. arXiv:1706.04579) muestra que ese supuesto puede fallar. Este script
# hace un barrido FINO y completo de alpha (no bisección) sobre una muestra de rutas, para
# confirmar si el % de tramos caídos decrece de forma monótona o si hay comportamiento errático que
# invalidaría la búsqueda binaria para esas rutas.

library(igraph)
library(pbapply)

# se admite correr esto parado en la raíz del repo o en code/
funct.dir <- 'funct'
if (!dir.exists(funct.dir)) {
  funct.dir <- file.path('code', funct.dir)
}
source(file.path(funct.dir, 'remove_route.R'))
source(file.path(funct.dir, 'route_cascade.R'))

data.path <- '../data/verificacion monotonicidad.csv'
if (!dir.exists(dirname(data.path))) {
  data.path <- sub('^\\.\\./', '', data.path)
}

# ------------------------------------- MUESTRA DE RUTAS ---------------------------------------------

rutas.disponibles <- unique(unlist(strsplit(edge_attr(tm.graph, 'services_flat'), ';')))

set.seed(1305)
rutas.muestra <- sample(rutas.disponibles, 10)

alphas <- seq(0, 3, by = 0.05)

# ------------------------------------- BARRIDO COMPLETO ---------------------------------------------

barrido <- pblapply(rutas.muestra, function(r) {
  caidas <- sapply(alphas, function(a) route_cascade(tm.graph, r, alpha = a)$`aristas caidas`)
  data.frame('route.id' = r, 'alpha' = alphas, 'aristas caidas' = caidas, check.names = FALSE)
})

barrido <- do.call(rbind, barrido)

# ------------------------------------- CHEQUEO DE MONOTONICIDAD ---------------------------------------------

# CALCULO -> por ruta, cuántas veces el % de tramos caídos SUBE al aumentar alpha (debería ser 0
#            si la cascada es monótona no creciente en alpha)
violaciones <- sapply(rutas.muestra, function(r) {
  caidas <- barrido$`aristas caidas`[barrido$route.id == r]
  sum(diff(caidas) > 0)
})

resumen.monotonicidad <- data.frame(
  'route.id'    = rutas.muestra,
  'violaciones' = violaciones
)

print(resumen.monotonicidad)
cat('Rutas con al menos una violación de monotonicidad:', sum(violaciones > 0), 'de', length(rutas.muestra), '\n')

write.csv(barrido, data.path, row.names = FALSE)

# ------------------------------------- GRÁFICO ---------------------------------------------

colores <- rainbow(length(rutas.muestra))

plot(NULL, xlim = range(alphas), ylim = c(0, max(barrido$`aristas caidas`)),
     xlab = 'alpha (margen de tolerancia)', ylab = 'Tramos caídos en cascada',
     main = 'Monotonicidad de la cascada por ruta (barrido completo)')

for (i in seq_along(rutas.muestra)) {
  r <- rutas.muestra[i]
  lines(alphas, barrido$`aristas caidas`[barrido$route.id == r], col = colores[i], lwd = 2)
}

legend('topright', legend = rutas.muestra, col = colores, lwd = 2, cex = 0.6, ncol = 2)
