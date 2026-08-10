station_social_context <- function(graph.path = '../data/TM graph.graphml',
                                   strata.url = 'https://datosabiertos.bogota.gov.co/dataset/55467552-0af4-4524-a390-a2956035744e/resource/29f2d770-bd5d-4450-9e95-8737167ba12f/download/manzanaestratificacion.json',
                                   locality.url = 'https://datosabiertos.bogota.gov.co/dataset/856cb657-8ca3-4ee8-857f-37211173b1f8/resource/497b8756-0927-4aee-8da9-ca4e32ca3a8a/download/loca.json',
                                   radius = 400){

  # Esta función cruza espacialmente cada estación del grafo de TM con las capas de estratificación
  # por manzana y de localidades del portal de datos abiertos de Bogotá, para tener el componente
  # social (estrato predominante, localidad) asociado a cada estación.

  # estaciones del grafo ya construido (se admite correr esto parado en la raíz del repo o en code/)
  if (!file.exists(graph.path)) {
    graph.path <- sub('^\\.\\./', '', graph.path)
  }
  tm.graph <- igraph::read_graph(graph.path, format = 'graphml')

  stations <- data.frame(
    'id station' = igraph::vertex_attr(tm.graph, 'name'),
    'station'    = igraph::vertex_attr(tm.graph, 'id'),
    'latitude'   = igraph::vertex_attr(tm.graph, 'latitude'),
    'longitude'  = igraph::vertex_attr(tm.graph, 'longitude'),
    check.names = FALSE
  )

  # capas espaciales del portal de datos abiertos (se leen directo desde la URL en GeoJSON)
  strata     <- sf::st_read(strata.url, quiet = TRUE)
  localities <- sf::st_read(locality.url, quiet = TRUE)

  # las geometrías oficiales suelen venir con topología inválida (vértices duplicados); se
  # desactiva la validación esférica s2 (no es relevante a la escala de una sola ciudad) y se
  # fuerza a que las geometrías sean válidas antes de cruzar
  s2.previo <- sf::sf_use_s2()
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(s2.previo), add = TRUE)

  strata     <- sf::st_make_valid(strata)
  localities <- sf::st_make_valid(localities)

  # estaciones a objeto espacial en WGS84 (mismo sistema del GTFS) y homologación de las capas
  stations.sf <- sf::st_as_sf(stations, coords = c('longitude', 'latitude'), crs = 4326)
  localities  <- sf::st_transform(localities, crs = 4326)

  # cruce espacial: localidad que contiene cada estación
  # OJO: 'LocNombre' es el nombre de columna esperado según la documentación del dataset; si el
  # GeoJSON trae otro nombre hay que ajustarlo acá.
  stations.sf <- sf::st_join(stations.sf, localities[, 'LocNombre'])

  # las estaciones caen sobre vías/separadores, y la manzana más cercana suele ser un lote
  # comercial de fachada (estrato 0) aunque el barrio alrededor sea residencial. En vez de eso, se
  # define un radio de influencia (en metros, sobre la proyección métrica original de la capa de
  # manzanas) y se toma el estrato residencial (distinto de 0) más frecuente dentro de ese radio,
  # como proxy del contexto socioeconómico real de la zona de la estación.
  strata.crs        <- sf::st_crs(strata)
  stations.metric   <- sf::st_transform(stations.sf, strata.crs)
  stations.buffer   <- sf::st_buffer(stations.metric, dist = radius)

  buffer.hits <- sf::st_join(stations.buffer[, 'id station'],
                             strata[, 'ESTRATO'],
                             join = sf::st_intersects) |>
    sf::st_drop_geometry()

  stratum.by.station <- buffer.hits |>
    dplyr::group_by(`id station`) |>
    dplyr::summarise(
      stratum = {
        estratos       <- ESTRATO[!is.na(ESTRATO)]
        residenciales  <- estratos[estratos != 0]
        candidatos     <- if (length(residenciales) > 0) residenciales else estratos
        if (length(candidatos) == 0) {
          NA
        } else {
          as.numeric(names(sort(table(candidatos), decreasing = TRUE))[1])
        }
      },
      .groups = 'drop'
    )

  # estaciones sin ninguna manzana dentro del radio (casos aislados, p.ej. las de Soacha que caen
  # fuera de la cobertura del dataset de manzanas de Bogotá) quedan con stratum = NA en el paso
  # anterior; se resuelven con la manzana más cercana como respaldo
  sin.manzanas <- stratum.by.station$`id station`[is.na(stratum.by.station$stratum)]
  if (length(sin.manzanas) > 0) {
    respaldo <- sf::st_join(stations.metric[stations.metric$`id station` %in% sin.manzanas, 'id station'],
                            strata[, 'ESTRATO'],
                            join = sf::st_nearest_feature) |>
      sf::st_drop_geometry() |>
      dplyr::rename('stratum' = ESTRATO)

    stratum.by.station <- stratum.by.station |>
      dplyr::filter(!(`id station` %in% sin.manzanas)) |>
      rbind(respaldo)
  }

  stations.social <- stations.sf |>
    sf::st_drop_geometry() |>
    dplyr::rename('locality' = LocNombre) |>
    dplyr::left_join(stratum.by.station, by = 'id station')

  # la capa de localidades solo cubre Bogotá D.C.; como el troncal de TM solo se extiende fuera
  # del distrito hacia Soacha, cualquier estación sin localidad es de Soacha
  stations.social$locality[is.na(stations.social$locality)] <- 'SOACHA'

  return(stations.social)
}
