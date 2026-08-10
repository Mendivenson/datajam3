stop_stress <- function(dates = seq(as.Date('01-01-2026', format='%d-%m-%Y'),
                                    as.Date('31-01-2026', format='%d-%m-%Y')),
                        format='%d-%m-%Y'){

  # Esta función resume la información de las salidas y entradas por estación del sistema troncal
  # de TM con frecuencia horaria para un rango de días dado.
  dates <- as.Date(dates, format=format)

  if (any(dates < as.Date('2024-03-01'))) {
    stop('NO HAY DATOS DE FECHAS ANTERIORES AL 1RO DE MARZO DE 2024.')
  }

  # nombres archivos zip
  dates     <- format(dates, format='%Y%m%d')
  exit.file <- paste0('salidas', dates, '.zip')

  # tabla de archivos x url (el archivo de salidas ya trae entradas y salidas, no hace falta el de validaciones)
  exit.table <- read.csv('https://raw.githubusercontent.com/Mendivenson/datajam3/refs/heads/main/data/download%20url%20salidas.csv')

  # urls de descarga solicitadas
  exit.url <- exit.table[exit.table$nombre_archivo %in% exit.file, "url_descarga"]

  # Bucle de descarga
  exit <- pbapply::pblapply(exit.url,
                 FUN = function(x){
                   x = read.csv(archive::archive_read(x, format = 'zip'))
                   x$Tiempo = x$Tiempo |> substr(start = 1, stop = 2) |> as.numeric()
                   x$Estacion = regmatches(x$Estacion, gregexpr("(?<=\\()[^()]*(?=\\))", x$Estacion, perl = TRUE)) |>
                     unlist() |>
                     as.numeric() |>
                     as.character()

                   x |>
                     dplyr::select('date' = Fecha_Transaccion,
                                   'hour' = Tiempo,
                                   'id station' = Estacion,
                                   'validations' = Entradas_E,
                                   'exits' = Salidas_S) |>
                     group_by(date, hour, `id station`) |>
                     dplyr::summarise(validations = sum(validations),
                                      exits = sum(exits), .groups = 'drop')
                 }) |>
    do.call(what = rbind)

  return(exit)
}
