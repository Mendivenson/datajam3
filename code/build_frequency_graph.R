# ------------------- PESO POR FRECUENCIA REAL (VIAJES) EN VEZ DE SOLO CONTEO DE RUTAS ------------------
# El grafo base (code/graph building.R) pondera cada tramo por cuántas RUTAS distintas lo cubren,
# pero no por cuántos VIAJES (trips) realmente pasan por ahí en un día — dos tramos servidos por
# la misma cantidad de rutas pueden tener frecuencias muy distintas si una ruta pasa cada 5 minutos
# y otra cada 30. Este script reprocesa el GTFS manteniendo la granularidad de viaje (que
# 'graph building.R' descarta deliberadamente al hacer distinct() sobre trip_id) para obtener un
# proxy real de frecuencia/headway por tramo, SIN modificar el script ni el grafo del compañero.
#
# Se usa como chequeo de robustez: ¿cambia mucho el ranking de tramos críticos si la capacidad se
# basa en viajes reales en vez de solo en cuántas rutas comparten el tramo?

library(archive)
library(dplyr)
library(igraph)

# ------------------------------------- CARGA DE DATOS (mismo GTFS, misma lógica de filtrado) ---------------------------------------------

gtfs.path <- '../data/GTFS.txt'
if (!file.exists(gtfs.path)) {
  gtfs.path <- sub('^\\.\\./', '', gtfs.path)
}
GTFS <- readLines(gtfs.path)

stops  <- read.csv(archive_read(GTFS, file = 'stops.txt', format = 'zip'))
routes <- read.csv(archive_read(GTFS, file = 'routes.txt', format = 'zip'))
trips  <- read.csv(archive_read(GTFS, file = 'trips.txt', format = 'zip'))

options(timeout = 180)
stop.times <- read.csv(archive_read(GTFS, file = 'stop_times.txt', format = 'zip'))

routes <- routes |> filter(agency_id == '1')

stop.times <- stop.times |>
  select(-arrival_time, -departure_time, -stop_headsign, -timepoint) |>
  left_join(trips[, c('trip_id', 'route_id')], by = 'trip_id') |>
  left_join(routes, by = 'route_id') |>
  filter(!is.na(agency_id)) |>
  select(-agency_id, -route_text_color, -route_type)

# OJO: a diferencia de graph building.R, aquí NO se hace select(-trip_id) |> distinct() — se
# mantiene la granularidad de viaje individual para poder contar frecuencia real.

stop.times <- stop.times |>
  left_join(stops[, c('stop_id', 'parent_station')], by = 'stop_id') |>
  select(-stop_id) |>
  rename(c('stop_id' = 'parent_station'))

stop.times$stop_id <- as.character(stop.times$stop_id)

# ------------------------------------- ARISTAS POR VIAJE (FRECUENCIA REAL) ---------------------------------------------

tm.edges.viajes <- stop.times |>
  arrange(trip_id, stop_sequence) |>
  group_by(trip_id) |>
  summarise(stops = list(stop_id), route_id = dplyr::first(route_id), .groups = 'drop')

tm.edges.viajes <- apply(tm.edges.viajes, MARGIN = 1,
                         function(x) {
                           stops <- x$stops
                           if (length(stops) < 2) return(NULL)
                           edges <- do.call(rbind, lapply(2:length(stops), function(i) stops[(i - 1):i]))
                           cbind(edges, x$route_id)
                         }) |>
  (\(x) do.call(rbind, x[!sapply(x, is.null)]))() |>
  as.data.frame()

colnames(tm.edges.viajes) <- c('out', 'in', 'route_id')

tm.edges.viajes <- tm.edges.viajes |>
  group_by(out, `in`) |>
  summarise('weight_viajes'  = n(),
           'weight_rutas'   = n_distinct(route_id),
           .groups = 'drop')

# ------------------------------------- COMPARACIÓN CONTRA EL GRAFO BASE ---------------------------------------------

clave.viajes <- paste(tm.edges.viajes$out, tm.edges.viajes$`in`, sep = ' -> ')
clave.grafo  <- apply(igraph::ends(tm.graph, igraph::E(tm.graph), names = TRUE), 1, paste, collapse = ' -> ')

idx <- match(clave.grafo, clave.viajes)

weight.viajes.alineado <- tm.edges.viajes$weight_viajes[idx]
weight.rutas.alineado  <- tm.edges.viajes$weight_rutas[idx]

cat('Tramos del grafo sin match en el reproceso por viaje:', sum(is.na(idx)), 'de', length(idx), '\n')
cat('Correlación (Spearman) peso por rutas vs. peso por viajes:',
    round(cor(igraph::edge_attr(tm.graph, 'weight'), weight.viajes.alineado, method = 'spearman', use = 'complete.obs'), 3), '\n')

# CALCULO -> grafo con el peso de frecuencia real como atributo adicional, sin tocar tm.graph
tm.graph.viajes <- igraph::set_edge_attr(tm.graph, 'weight_viajes', value = weight.viajes.alineado)

# ------------------------------------- SENSIBILIDAD: ¿CAMBIA EL CUELLO DE BOTELLA? ---------------------------------------------

source(if (file.exists('funct/remove_route.R')) 'funct/remove_route.R' else 'code/funct/remove_route.R')

# misma mecánica de route_cascade() pero con capacidad basada en viajes reales en vez de en
# conteo de rutas, sobre una muestra de rutas (no las 111, para que sea rápido de correr)
carga.base <- igraph::edge_betweenness(tm.graph.viajes, directed = TRUE, weights = NA)
peso.relativo.viajes <- weight.viajes.alineado / mean(weight.viajes.alineado, na.rm = TRUE)
capacidad.viajes <- carga.base * peso.relativo.viajes

clave.original <- clave.grafo

set.seed(1305)
rutas.disponibles <- unique(unlist(strsplit(igraph::edge_attr(tm.graph, 'services_flat'), ';')))
rutas.muestra     <- sample(rutas.disponibles, 15)

peor.tramo.viajes <- sapply(rutas.muestra, function(r) {
  grafo.sin.ruta <- remove_route(tm.graph.viajes, r)
  carga.actual   <- igraph::edge_betweenness(grafo.sin.ruta, directed = TRUE, weights = NA)
  clave.actual   <- apply(igraph::ends(grafo.sin.ruta, igraph::E(grafo.sin.ruta), names = TRUE), 1, paste, collapse = ' -> ')
  idx.actual     <- match(clave.actual, clave.original)
  ratio          <- carga.actual / (1.2 * capacidad.viajes[idx.actual])
  clave.actual[which.max(ratio)]
})

cat('Tramo más sobrecargado (capacidad por viajes reales), muestra de 15 rutas:\n')
print(table(peor.tramo.viajes))
