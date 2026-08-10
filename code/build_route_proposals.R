# ------------------- PROPUESTA DE RUTAS NUEVAS (ERGM + ESPACIO LATENTE) ------------------
# Ajusta un ERGM y un modelo de espacio latente (ambos con covariables de distancia geográfica,
# diferencia de estrato y coincidencia de localidad) sobre la versión no dirigida del grafo de TM,
# para identificar pares de estaciones que HOY no tienen un tramo directo pero que, según el
# patrón general de la red, estadísticamente "deberían" tenerlo. Guarda el ranking combinado de
# ambos modelos como candidatos a ruta nueva.

library(ergm)
library(latentnet)

# se admite correr esto parado en la raíz del repo o en code/
funct.path <- 'funct/link_prediction_data.R'
if (!file.exists(funct.path)) {
  funct.path <- file.path('code', funct.path)
}
source(funct.path)

data.path <- '../data/candidatos ruta nueva.csv'
if (!dir.exists(dirname(data.path))) {
  data.path <- sub('^\\.\\./', '', data.path)
}

# ------------------------------------- PREPARACIÓN DE INSUMOS ---------------------------------------------

distancia <- station_distance_matrix(tm.graph)
red.tm    <- build_tm_network(tm.graph)

stratum  <- network::get.vertex.attribute(red.tm, 'stratum')
locality <- network::get.vertex.attribute(red.tm, 'locality')

absdiff.stratum <- abs(outer(stratum, stratum, '-'))
match.locality  <- outer(locality, locality, '==') * 1

# ------------------------------------- ERGM ---------------------------------------------

modelo.ergm <- ergm(red.tm ~ edges + edgecov(distancia) + absdiff('stratum') + nodematch('locality'))

beta.ergm <- coef(modelo.ergm)
logit.p.ergm <- beta.ergm['edges'] +
  beta.ergm['edgecov.distancia'] * distancia +
  beta.ergm['absdiff.stratum'] * absdiff.stratum +
  beta.ergm['nodematch.locality'] * match.locality

p.ergm <- plogis(logit.p.ergm)

tabla.ergm <- rank_missing_dyads(p.ergm, red.tm, tm.graph)
colnames(tabla.ergm)[3] <- 'probabilidad ergm'

# ------------------------------------- MODELO DE ESPACIO LATENTE ---------------------------------------------

modelo.latente <- ergmm(red.tm ~ euclidean(d = 2) + edgecov(distancia) + absdiff('stratum') + nodematch('locality'))

Z    <- modelo.latente$mkl$Z
beta.latente <- modelo.latente$mkl$beta
dist.latente <- as.matrix(dist(Z))

logit.p.latente <- beta.latente[1] +
  beta.latente[2] * distancia +
  beta.latente[3] * absdiff.stratum +
  beta.latente[4] * match.locality -
  dist.latente

p.latente <- plogis(logit.p.latente)

tabla.latente <- rank_missing_dyads(p.latente, red.tm, tm.graph)
colnames(tabla.latente)[3] <- 'probabilidad latente'

# ------------------------------------- TABLA COMBINADA ---------------------------------------------

candidatos.rutas <- merge(tabla.ergm, tabla.latente, by = c('estacion.1', 'estacion.2'))
candidatos.rutas$'probabilidad promedio' <- rowMeans(candidatos.rutas[, c('probabilidad ergm', 'probabilidad latente')])
candidatos.rutas <- candidatos.rutas[order(-candidatos.rutas$`probabilidad promedio`), ]

write.csv(candidatos.rutas, data.path, row.names = FALSE)
