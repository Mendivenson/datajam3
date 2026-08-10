station_demand <- function(dates = seq(as.Date('01-07-2026', format = '%d-%m-%Y'),
                                       as.Date('31-07-2026', format = '%d-%m-%Y'),
                                       by = 'day'),
                           format = '%d-%m-%Y'){

  # Agrega la demanda real (validaciones + salidas) de stop_stress() a un solo valor por estación
  # para el rango de fechas dado. Se usa como insumo de la simulación de quitar/agregar rutas
  # (carga ponderada por demanda en route_cascade(), robustez ponderada por demanda, etc.)

  crudo <- stop_stress(dates, format)

  # El dataset de validaciones/salidas usa una codificación de estación (TMSA) que no siempre
  # coincide con el stop_id del GTFS: algunos códigos son la misma estación troncal bajo otra
  # plataforma/ampliación/punto temporal durante obras (se remapean al id de la estación en el
  # grafo), y otros no son estaciones troncales en absoluto (TransMiCable, bicicleteros, patios de
  # alimentadoras), por lo que se excluyen.
  crosswalk <- c('12003' = '7111',  '3011' = '90007', '57503' = '7503',  '59503' = '7503',
                '9000'  = '90004', '9005' = '90008', '9125'  = '9119',  '9126'  = '9118',
                '9127'  = '9121',  '9128' = '9110',  '9129'  = '9113',  '9130'  = '9116')

  excluir <- c('2305', '40000', '40001', '40002', '40003', '40004', '50002', '50003', '50008', '4100')

  crudo <- crudo[!(crudo$`id station` %in% excluir), ]
  remapear <- crudo$`id station` %in% names(crosswalk)
  crudo$`id station`[remapear] <- crosswalk[crudo$`id station`[remapear]]

  resumen <- crudo |>
    dplyr::group_by(`id station`) |>
    dplyr::summarise('demand' = sum(validations, na.rm = TRUE) + sum(exits, na.rm = TRUE),
                     .groups = 'drop')

  demanda <- resumen$demand
  names(demanda) <- resumen$`id station`

  return(demanda)
}
