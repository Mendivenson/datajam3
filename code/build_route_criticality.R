# ------------------- CRITICIDAD DE RUTAS: ALPHA CRÍTICO TOPOLÓGICO Y PONDERADO POR DEMANDA ------------------
# Para cada ruta troncal, calcula el margen de tolerancia crítico (alpha_c) de la cascada de fallas
# al eliminarla (ver route_cascade.R), tanto en su versión topológica pura como ponderada por
# demanda real (validaciones + salidas, vía station_demand()). Guarda el ranking combinado en
# data/criticidad rutas.csv.

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

data.path <- '../data/criticidad rutas.csv'
if (!dir.exists(dirname(data.path))) {
  data.path <- sub('^\\.\\./', '', data.path)
}

# ------------------------------------- INSUMOS ---------------------------------------------

rutas.disponibles <- unique(unlist(strsplit(edge_attr(tm.graph, 'services_flat'), ';')))
demanda           <- station_demand()

# ------------------------------------- ALPHA CRÍTICO POR RUTA ---------------------------------------------

alpha.topologico <- pbsapply(rutas.disponibles, function(r) {
  tryCatch(critical_alpha(tm.graph, r, alpha.max = 6)$alpha_c, error = function(e) NA)
})

alpha.demanda <- pbsapply(rutas.disponibles, function(r) {
  tryCatch(critical_alpha(tm.graph, r, demand = demanda, alpha.max = 6)$alpha_c, error = function(e) NA)
})

# ------------------------------------- TABLA COMBINADA ---------------------------------------------

criticidad.rutas <- data.frame(
  'route.id'            = rutas.disponibles,
  'nombre'              = sapply(rutas.disponibles, route_name, graph = tm.graph),
  'tramos'              = sapply(rutas.disponibles, route_edge_count, graph = tm.graph),
  'alpha_c topologico'  = alpha.topologico,
  'alpha_c demanda'     = alpha.demanda,
  check.names = FALSE
)

criticidad.rutas <- criticidad.rutas[order(-criticidad.rutas$`alpha_c demanda`), ]

write.csv(criticidad.rutas, data.path, row.names = FALSE)
