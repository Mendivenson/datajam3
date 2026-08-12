# ------------------- SCORE UNIFICADO DE CRITICIDAD DE RUTAS ------------------
# Combina, para cada ruta, su criticidad estructural y ponderada por demanda
# (build_route_criticality.R), su redundancia (cuántas otras rutas comparten, en promedio, sus
# tramos) y su componente social (% de estaciones vulnerables que cubre, estrato 1 o 2), en un
# cuadrante en vez de aplastarlo todo en un solo índice: la idea es distinguir "proteger a toda
# costa" de "candidata a recorte/optimización" sin perder información en el camino.
#
# El componente social se mide como % de estaciones vulnerables y no como promedio de estrato,
# porque el estrato es una variable ordinal (no de intervalo): un promedio asumiría que la
# diferencia entre estrato 1 y 2 "vale lo mismo" que entre 5 y 6, lo cual no está garantizado.

library(igraph)

# se admite correr esto parado en la raíz del repo o en code/
funct.dir <- 'funct'
if (!dir.exists(funct.dir)) {
  funct.dir <- file.path('code', funct.dir)
}
source(file.path(funct.dir, 'route_utils.R'))

data.dir <- '../data'
if (!dir.exists(data.dir)) {
  data.dir <- 'data'
}

# ------------------------------------- INSUMOS ---------------------------------------------

criticidad <- read.csv(file.path(data.dir, 'criticidad rutas.csv'), check.names = FALSE)
social     <- read.csv(file.path(data.dir, 'estaciones estrato localidad.csv'), check.names = FALSE)

criticidad$route.id <- as.character(criticidad$route.id)

# ------------------------------------- REDUNDANCIA Y COMPONENTE SOCIAL POR RUTA ---------------------------------------------

criticidad$redundancia <- sapply(criticidad$route.id, route_redundancy, graph = tm.graph)

pct.vulnerables <- function(route.id, umbral){
  estaciones <- route_stations(route.id, tm.graph)
  estrato    <- social$stratum[social$`id station` %in% estaciones]
  mean(estrato <= umbral, na.rm = TRUE) * 100
}

criticidad$'pct vulnerables estrato 1'     <- sapply(criticidad$route.id, pct.vulnerables, umbral = 1)
criticidad$'pct estaciones vulnerables'    <- sapply(criticidad$route.id, pct.vulnerables, umbral = 2)
criticidad$'pct vulnerables estrato 3'     <- sapply(criticidad$route.id, pct.vulnerables, umbral = 3)

# CALCULO -> sensibilidad del umbral de vulnerabilidad: ¿el ranking de rutas más "vulnerables"
#            cambia mucho si el corte es estrato <=1 o <=3 en vez de <=2? Se compara con
#            correlación de Spearman entre los 3 rankings (no solo el corte que se usa en el
#            cuadrante final)
cat('Correlación (Spearman) del ranking de % vulnerables entre umbrales:\n')
cat('  <=1 vs. <=2:', round(cor(criticidad$`pct vulnerables estrato 1`, criticidad$`pct estaciones vulnerables`, method = 'spearman'), 3), '\n')
cat('  <=2 vs. <=3:', round(cor(criticidad$`pct estaciones vulnerables`, criticidad$`pct vulnerables estrato 3`, method = 'spearman'), 3), '\n')
cat('  <=1 vs. <=3:', round(cor(criticidad$`pct vulnerables estrato 1`, criticidad$`pct vulnerables estrato 3`, method = 'spearman'), 3), '\n')

# ------------------------------------- GUARDAR ---------------------------------------------

write.csv(criticidad, file.path(data.dir, 'score criticidad rutas.csv'), row.names = FALSE)

# ------------------------------------- CUADRANTE ---------------------------------------------

# CALCULO -> reescalar una variable a un rango dado, para usarla como tamaño de punto
reescalar <- function(x, a = 0.6, b = 3) {
  (x - min(x, na.rm = TRUE)) / diff(range(x, na.rm = TRUE)) * (b - a) + a
}

# la distribución de alpha_c demanda está muy concentrada (90% de las rutas caen en un rango
# angosto): la mediana de los valores crudos no divide el cuadrante de forma útil. Se grafica el
# percentil de cada ruta en cada eje en vez del valor crudo, para que el orden relativo (que es lo
# que realmente importa) quede visible de forma pareja, sin perder ninguna información de ranking.
percentil.topologico <- rank(criticidad$`alpha_c topologico`) / nrow(criticidad) * 100
percentil.demanda     <- rank(criticidad$`alpha_c demanda`) / nrow(criticidad) * 100

paleta                  <- colorRampPalette(c('gray80', 'darkred'))(100)
color.por.vulnerabilidad <- paleta[as.numeric(cut(criticidad$`pct estaciones vulnerables`, breaks = 100))]
tamano.por.redundancia  <- reescalar(-criticidad$redundancia)   # menor redundancia -> punto más grande

par(mar = c(5, 5, 5, 2))
plot(percentil.topologico, percentil.demanda,
     pch  = 19,
     col  = color.por.vulnerabilidad,
     cex  = tamano.por.redundancia,
     xlab = 'Percentil de criticidad estructural (alpha_c topológico)',
     ylab = 'Percentil de criticidad ponderada por demanda (alpha_c demanda)',
     main = 'Cuadrante de criticidad de rutas\n(tamaño = menor redundancia · color = % estaciones vulnerables, rojo = más)')
abline(h = 50, lty = 2, col = 'gray50')
abline(v = 50, lty = 2, col = 'gray50')
