# ------------------- COMPONENTE SOCIAL DE LAS ESTACIONES DEL SISTEMA TRONCAL DE TM ------------------
# Corre el cruce espacial de las estaciones del grafo (code/funct/station_social_context.R) contra
# las capas de estratificación por manzana y de localidades del portal de datos abiertos de Bogotá,
# y guarda el resultado como CSV para poder unirlo más adelante con la demanda por estación
# (code/funct/station_stress.R) y con el score de criticidad de rutas.
#
# NOTA: se asume que este script se corre parado en code/ (igual que graph building.R)

source('code/funct/station_social_context.R')

stations.social <- station_social_context()

write.csv(stations.social, 'data/estaciones estrato localidad.csv', row.names = FALSE)
