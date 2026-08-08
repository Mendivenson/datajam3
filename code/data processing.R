# ------------------- CREACIÓN DEL GRAFO REPRESENTACIÓN DEL SISTEMA TRONCAL DE TM ------------------
# Dentro de los datos disponibilizados en el portal de datos abiertos de Bogotá no existe información
# que permita reconstruir un grafo del sistema, pero dentro de la página de datos de TM se
# encuentra la información relacionada con el General Transit Feed Specification (GTFS) que entre otras
# cosas contiene un listado de las rutas y sus paradas que será lo que se use para construir el grafo.
#
# Además de dicha información se asignará a cada nodo del grado las características de entradas y
# salidas (Estos datos sí son del portal de datos abiertos) para generar un proxy de los puntos de
# partida y salida de los usuarios del sistema.
#
# - GTFS TM:
#   https://datosabiertos-transmilenio.hub.arcgis.com/search?q=GTFS&sort=Date%20Updated%7Cmodified%7Cdesc
#
# - Validaciones hechas en el sistema:
#   https://datosabiertos.bogota.gov.co/dataset/validaciones-diarias-sitp
#
# - Salidas registradas del sistema:
#   https://datosabiertos.bogota.gov.co/dataset/consolidado-de-salidas-sistema-troncal-por-franja-horaria
#
# SALIDA:
# Un archivo representando el grafo de TM donde:
#
# - NODOS: Cada nodo representa una estación del sistema troncal acompañado de longitud, latitud, ID
#          de la estación, demanda y salidas de la estación respectivamente.
# - ARISTAS: Cada arista tendrá como peso la cantidad de conexiones directas entre dos estaciones.
#
# Además de esto, se debe tener un listado de rutas + estaciones para poder restar a las aristas
# correspondientes el peso generado por el servicio sin necesidad de generar el grafo desde cero
# sobre todo pensando en la implementación de herramientas de visualización más adelante.

library(archive)     # Leer archivos ZIP sin descargarlos
library(dplyr)       # Manejo de datos

# ------------------------------------- CARGA DE DATOS ---------------------------------------------
# Todas las URLs de acceso a archivos se dejan en un txt aparte para automatizar la ingesta de datos
# en iteraciones posteriores del proyecto.
#
# El GTFS (General Transit Feed Specification) es un éstandar internacional para la especificación de
# sistemas dew transporte y será el insumo para generar el grafo del sistema de troncales de TM dentro
# del marco de este proyecto. Este set de datos se actualiza constantemente en el portal de datos
# abiertos de TM y6 su histórico también se encuentra allí

GTFS <- readLines('../data/GTFS.txt')


# READ -> Ubicación, nombre e identificación de las estaciones y paradas
con <- archive_read(GTFS,
                    file = 'stops.txt',
                    format = 'zip')
stops <- read.csv(con)

# READ -> Nombre, color, identificador, etc. de los servicios
con <- archive_read(GTFS,
                    file = 'routes.txt',
                    format = 'zip')
routes <- read.csv(con)

# READ -> Relación trip con los ids de los servicios
con <- archive_read(GTFS,
                    file = 'trips.txt',
                    format = 'zip')
trips <- read.csv(con)

# READ -> Paradas y orden de las paradas de las rutas
options(timeout = 120)
con <- archive_read(GTFS,
                    file = 'stop_times.txt',
                    format = 'zip')
stop.times <- read.csv(con)

# FILTER -> Servicios solamente pertenecientes al servicio troncal de TM. Dentro de los archivos
#           de GTFS el archivo agency.txt describe los diferentes tipos de servicio y se asume que
#           los IDs no van a cambiar por lo que 1 representa los servicios que son de las rutas
#           troncales
routes <- routes |>
  filter(agency_id == '1')

# FILTER ->  Remove unnecesary columns from  stop.times dataset
stop.times <- stop.times |>
  select(-arrival_time,-departure_time,-stop_headsign, -timepoint)

# JOIN -> Uno de los principales líos con stop.times es que tiene listados varios servicios con el
#         mismo nombre sin el ID del servicio, principalmente se hará acá.

stop.times <- stop.times |>
  left_join(trips[,c("trip_id", "route_id")], by = c('trip_id' = 'trip_id'))

# JOIN -> En este punto, se sabe el id del servicio, pero no las demás características de la misma.
#         Con el recién añadido route_id se mergea la información de los servicios con la información
#         de los trips.

stop.times <- stop.times |>
  left_join(routes, by = c('route_id' = 'route_id'))

# FILTER -> Como funciona el left join y como ya se habían filtrado solamente los servicios troncales
#           las filas que tengan agency_id == NA son filas de servicios no troncales que hay que eliminar

stop.times <- stop.times |>
  filter(!is.na(agency_id))

# DEDUP -> Hay más de un reporte por ruta dentro de la base de datos pues se reportan durante un
#          periodo largo de tiempo los tiempos de llegada. Si eliminamos el id del trip debería ser
#          suficiente para aproximar el grafo del servicio troncal de TM.

stop.times <- stop.times |>
  select(-trip_id) |>
  distinct()

# FILTER -> Drop useless columns
stop.times <- stop.times  |>
  select(-agency_id, -route_text_color, -route_type)

# JOIN -> Los stop_id tiene granularidad por vagón por lo que se trae es el parent_id para obtener
#         la ubicación de la estación solamente.

stop.times <- stop.times |>
  left_join(stops[,c("stop_id", "parent_station")],
            by = c("stop_id" = "stop_id")) |>
  select(-stop_id) |>
  rename(c('stop_id' = 'parent_station'))

# FILTER -> En términos prácticos solamente se usan las estaciones principales y no los vagones
#           por lo que solo se usa un subset de paradas

stops <- stops |>
  filter(is.na(parent_station))

stop.times$stop_id <- as.character(stop.times$stop_id)
stop.times <- stop.times |>
  left_join(stops[,c("stop_id", "stop_name")],
            by = c("stop_id" = "stop_id"))
