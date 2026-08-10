# ------------------- ANÁLISIS DESCRIPTIVO DEL GRAFO DEL SISTEMA TRONCAL DE TM ------------------
# Descriptivo básico del grafo (estaciones, tramos, servicios) y descriptivo de la red siguiendo
# el mismo marco conceptual del curso de Análisis Estadístico de Redes (Juan Sosa, UNAL):
#
# - Grado y fuerza
# - Conectividad (componentes, distancias, cliques)
# - Agrupamiento (coeficiente de clustering / transitividad)
#
# https://sites.google.com/view/juansosa/networks

library(igraph)   # Manejo de grafos

# ------------------------------------- CARGA DEL GRAFO ---------------------------------------------

# READ -> Grafo de TM ya construido (se admite correr esto parado en la raíz del repo o en code/)
graph.path <- '../data/TM graph.graphml'
if (!file.exists(graph.path)) {
  graph.path <- sub('^\\.\\./', '', graph.path)
}
tm.graph <- read_graph(graph.path, format = 'graphml')

station.names <- vertex_attr(tm.graph, 'id')

# ------------------------------------- DESCRIPTIVO BÁSICO ---------------------------------------------

# CALCULO -> Tamaño del grafo
n.estaciones <- vcount(tm.graph)
n.tramos     <- ecount(tm.graph)

cat('Estaciones:', n.estaciones, '\n')
cat('Tramos (aristas dirigidas):', n.tramos, '\n')

# CALCULO -> Rutas totales del sistema (a partir de la lista aplanada de servicios por tramo)
rutas.por.tramo <- strsplit(edge_attr(tm.graph, 'services_flat'), ';')
rutas.totales   <- unique(unlist(rutas.por.tramo))
cat('Rutas troncales distintas en el sistema:', length(rutas.totales), '\n')

# CALCULO -> Resumen del peso de los tramos (cuántas rutas cubren cada tramo)
weight <- edge_attr(tm.graph, 'weight')
summary(weight)

# PLOT -> Distribución del peso de los tramos
hist(weight,
     breaks = max(weight),
     main   = 'Distribución del peso de los tramos',
     xlab   = 'Rutas que cubren el tramo',
     ylab   = 'Número de tramos',
     col    = 'steelblue',
     border = 'white')

# ------------------------------------- GRADO Y FUERZA ---------------------------------------------

# CALCULO -> Grado (número de tramos incidentes) y fuerza (grado ponderado por número de rutas)
grado.entrada <- degree(tm.graph, mode = 'in')
grado.salida  <- degree(tm.graph, mode = 'out')

fuerza.entrada <- strength(tm.graph, mode = 'in',  weights = weight)
fuerza.salida  <- strength(tm.graph, mode = 'out', weights = weight)

resumen.grado <- data.frame(
  'station'        = station.names,
  'grado entrada'  = grado.entrada,
  'grado salida'   = grado.salida,
  'fuerza entrada' = fuerza.entrada,
  'fuerza salida'  = fuerza.salida,
  check.names = FALSE
)

# PLOT -> Top 15 estaciones por grado total (entrada + salida)
top.grado <- resumen.grado[order(-(resumen.grado$`grado entrada` + resumen.grado$`grado salida`)), ][1:15, ]

par(mar = c(4, 10, 4, 2))
barplot(rev(top.grado$`grado entrada` + top.grado$`grado salida`),
        names.arg = rev(top.grado$station),
        horiz     = TRUE,
        las       = 1,
        col       = 'salmon',
        border    = NA,
        main      = 'Top 15 estaciones por grado total',
        xlab      = 'Grado (entrada + salida)')

# PLOT -> Distribución de grado (entrada vs salida)
par(mar = c(5, 4, 4, 2))
boxplot(grado.entrada, grado.salida,
        names = c('Entrada', 'Salida'),
        main  = 'Distribución del grado por dirección',
        ylab  = 'Grado',
        col   = c('steelblue', 'salmon'))

# ------------------------------------- CENTRALIDAD ---------------------------------------------

# CALCULO -> Centralidad de intermediación (betweenness): cuántos caminos más cortos entre pares
#            de estaciones pasan por cada estación. Se usa la versión no ponderada (weights = NA)
#            porque acá 'weight' representa cantidad de rutas (atractivo del tramo), no un costo
#            de viaje, así que la centralidad se calcula sobre la topología pura del grafo.
intermediacion <- betweenness(tm.graph, directed = TRUE, weights = NA, normalized = TRUE)

# CALCULO -> Centralidad de cercanía (closeness): qué tan cerca está cada estación, en promedio,
#            de las demás. Se puede calcular porque el grafo es fuertemente conexo.
cercania <- closeness(tm.graph, mode = 'out', normalized = TRUE)

resumen.centralidad <- data.frame(
  'station'         = station.names,
  'intermediacion'  = intermediacion,
  'cercania'        = cercania
)

# PLOT -> Top 15 estaciones por centralidad de intermediación (candidatas a cuello de botella)
top.intermediacion <- resumen.centralidad[order(-resumen.centralidad$intermediacion), ][1:15, ]

par(mar = c(4, 10, 4, 2))
barplot(rev(top.intermediacion$intermediacion),
        names.arg = rev(top.intermediacion$station),
        horiz     = TRUE,
        las       = 1,
        col       = 'darkred',
        border    = NA,
        main      = 'Top 15 estaciones por intermediación',
        xlab      = 'Centralidad de intermediación (normalizada)')

# PLOT -> Grado vs. intermediación: estaciones con mucho tráfico estructural (grado) pero que
#         además son puente obligado entre otras zonas de la red (intermediación) resaltan en la
#         esquina superior derecha
par(mar = c(5, 5, 4, 2))
plot(grado.entrada + grado.salida, intermediacion,
     main = 'Grado total vs. intermediación por estación',
     xlab = 'Grado total (entrada + salida)',
     ylab = 'Centralidad de intermediación (normalizada)',
     pch  = 19,
     col  = 'steelblue')

# ------------------------------------- CONECTIVIDAD ---------------------------------------------

# CALCULO -> Conectividad fuerte y débil del grafo
conexo.fuerte <- is_connected(tm.graph, mode = 'strong')
conexo.debil  <- is_connected(tm.graph, mode = 'weak')

cat('¿Fuertemente conexo?', conexo.fuerte, '\n')
cat('¿Débilmente conexo?', conexo.debil, '\n')

# CALCULO -> Componentes y tamaño del componente más grande
componentes    <- components(tm.graph, mode = 'weak')
tam.componente <- max(componentes$csize)

cat('Número de componentes (débiles):', componentes$no, '\n')
cat('Tamaño del componente más grande:', tam.componente, 'de', n.estaciones, '\n')

# CALCULO -> Distancia promedio y diámetro (sobre el componente conectado)
distancia.promedio <- mean_distance(tm.graph, directed = TRUE)
diametro           <- diameter(tm.graph, directed = TRUE, weights = NA)

cat('Distancia promedio (número de tramos):', round(distancia.promedio, 2), '\n')
cat('Diámetro de la red:', diametro, '\n')

# CALCULO -> Cliques máximos (sobre el grafo no dirigido, como se trabajan en el curso)
tm.graph.no.dirigido <- as_undirected(tm.graph, mode = 'collapse')
tam.clique.maximo     <- clique_num(tm.graph.no.dirigido)

cat('Tamaño del clique máximo:', tam.clique.maximo, '\n')

# ------------------------------------- AGRUPAMIENTO ---------------------------------------------

# CALCULO -> Coeficiente de clustering (transitividad) global y local
transitividad.global <- transitivity(tm.graph, type = 'global')
transitividad.local   <- transitivity(tm.graph, type = 'local', isolates = 'zero')

cat('Transitividad global:', round(transitividad.global, 4), '\n')

# PLOT -> Distribución de la transitividad local
hist(transitividad.local,
     breaks = 15,
     main   = 'Distribución de la transitividad local por estación',
     xlab   = 'Coeficiente de clustering local',
     ylab   = 'Número de estaciones',
     col    = 'steelblue',
     border = 'white')
