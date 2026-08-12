# ------------------- CRITICIDAD DE RUTAS CON CAPACIDAD POR FRECUENCIA REAL (VIAJES) ------------------
# Repite build_route_criticality.R para las 111 rutas completas, pero usando 'weight_viajes'
# (frecuencia real de viajes, ver build_frequency_graph.R) en vez de solo conteo de rutas como base
# de la capacidad instalada de cada tramo. Chequeo de sensibilidad: ¿cambia el ranking de
# criticidad y el cuello de botella sistémico con una medida de capacidad más realista?

library(igraph)
library(dplyr)
library(pbapply)

# se admite correr esto parado en la raíz del repo o en code/
funct.dir <- 'funct'
if (!dir.exists(funct.dir)) {
  funct.dir <- file.path('code', funct.dir)
}
source(file.path(funct.dir, 'station_stress.R'))
source(file.path(funct.dir, 'station_demand.R'))
source(file.path(funct.dir, 'remove_route.R'))
source(file.path(funct.dir, 'route_cascade.R'))
source(file.path(funct.dir, 'route_utils.R'))

# esto reprocesa el GTFS y construye tm.graph.viajes (con el atributo 'weight_viajes')
freq.path <- 'build_frequency_graph.R'
if (!file.exists(freq.path)) {
  freq.path <- file.path('code', freq.path)
}
source(freq.path)

data.path <- '../data/criticidad rutas (frecuencia).csv'
if (!dir.exists(dirname(data.path))) {
  data.path <- sub('^\\.\\./', '', data.path)
}

# ------------------------------------- ALPHA CRÍTICO POR RUTA (CAPACIDAD POR VIAJES) ---------------------------------------------

rutas.disponibles <- unique(unlist(strsplit(edge_attr(tm.graph, 'services_flat'), ';')))
demanda           <- station_demand()

# 'weight_viajes' es mucho más desigual que 'weight' (conteo de rutas): min/promedio ~0.04 vs ~0.5.
# Con esa dispersión, hasta alpha.max=6 deja tramos de baja frecuencia con capacidad menor a su
# propia carga inicial (fallarían aunque no se quitara ninguna ruta). Se sube el rango y se usa un
# paso más grueso (chequeo de sensibilidad secundario, no hace falta la misma precisión fina del
# análisis principal).
alpha.topologico <- pbsapply(rutas.disponibles, function(r) {
  tryCatch(critical_alpha(tm.graph.viajes, r, capacity.attr = 'weight_viajes', alpha.max = 30, paso = 1)$alpha_c,
          error = function(e) NA)
})

alpha.demanda <- pbsapply(rutas.disponibles, function(r) {
  tryCatch(critical_alpha(tm.graph.viajes, r, demand = demanda, capacity.attr = 'weight_viajes', alpha.max = 30, paso = 1)$alpha_c,
          error = function(e) NA)
})

# ------------------------------------- TABLA COMBINADA ---------------------------------------------

criticidad.frecuencia <- data.frame(
  'route.id'                          = rutas.disponibles,
  'nombre'                            = sapply(rutas.disponibles, route_name, graph = tm.graph),
  'tramos'                            = sapply(rutas.disponibles, route_edge_count, graph = tm.graph),
  'alpha_c topologico (frecuencia)'   = alpha.topologico,
  'alpha_c demanda (frecuencia)'      = alpha.demanda,
  check.names = FALSE
)

criticidad.frecuencia <- criticidad.frecuencia[order(-criticidad.frecuencia$`alpha_c demanda (frecuencia)`), ]

write.csv(criticidad.frecuencia, data.path, row.names = FALSE)
