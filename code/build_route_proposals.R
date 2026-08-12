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
match.stratum   <- outer(stratum, stratum, '==') * 1
match.locality  <- outer(locality, locality, '==') * 1

# ------------------------------------- ERGM ---------------------------------------------

# El estrato es una variable ORDINAL, no de intervalo: absdiff() asume que la diferencia entre
# estrato 1 y 2 "vale lo mismo" que entre 5 y 6, lo cual no está garantizado. Se ajustan ambas
# versiones (absdiff y nodematch) y se elige la de menor AIC, en vez de asumir de entrada cuál es
# la correcta.
modelo.ergm.absdiff   <- ergm(red.tm ~ edges + edgecov(distancia) + absdiff('stratum') + nodematch('locality'))
modelo.ergm.nodematch <- ergm(red.tm ~ edges + edgecov(distancia) + nodematch('stratum') + nodematch('locality'))

cat('AIC absdiff(estrato):', round(AIC(modelo.ergm.absdiff), 2),
    '| AIC nodematch(estrato):', round(AIC(modelo.ergm.nodematch), 2), '\n')
cat('BIC absdiff(estrato):', round(BIC(modelo.ergm.absdiff), 2),
    '| BIC nodematch(estrato):', round(BIC(modelo.ergm.nodematch), 2), '\n')

usar.nodematch <- AIC(modelo.ergm.nodematch) < AIC(modelo.ergm.absdiff)
modelo.ergm    <- if (usar.nodematch) modelo.ergm.nodematch else modelo.ergm.absdiff

beta.ergm <- coef(modelo.ergm)

if (usar.nodematch) {
  logit.p.ergm <- beta.ergm['edges'] +
    beta.ergm['edgecov.distancia'] * distancia +
    beta.ergm['nodematch.stratum'] * match.stratum +
    beta.ergm['nodematch.locality'] * match.locality
} else {
  logit.p.ergm <- beta.ergm['edges'] +
    beta.ergm['edgecov.distancia'] * distancia +
    beta.ergm['absdiff.stratum'] * absdiff.stratum +
    beta.ergm['nodematch.locality'] * match.locality
}

p.ergm <- plogis(logit.p.ergm)

# CALCULO -> bondad de ajuste del modelo ganador: compara estadísticos estructurales simulados
#            desde el modelo contra los observados (grado, distancia geodésica, ESP)
gof.ergm <- gof(modelo.ergm)
print(gof.ergm)

tabla.ergm <- rank_missing_dyads(p.ergm, red.tm, tm.graph)
colnames(tabla.ergm)[3] <- 'probabilidad ergm'

# ------------------------------------- MODELO DE ESPACIO LATENTE ---------------------------------------------

# Se usa la misma versión del estrato (absdiff o nodematch) que ganó en el ERGM, por consistencia.
formula.latente <- if (usar.nodematch) {
  red.tm ~ euclidean(d = 2) + edgecov(distancia) + nodematch('stratum') + nodematch('locality')
} else {
  red.tm ~ euclidean(d = 2) + edgecov(distancia) + absdiff('stratum') + nodematch('locality')
}

# La configuración por defecto deja factores de dependencia altos (~20-60) en el diagnóstico de
# Raftery-Lewis, señal de autocorrelación fuerte / mixing lento; se sube burn-in y tamaño de
# muestra para que la cadena efectiva sea más larga que el mínimo que el propio diagnóstico sugiere.
modelo.latente <- ergmm(formula.latente,
                        control = control.ergmm(burnin = 5000, sample.size = 8000, interval = 10))

# CALCULO -> diagnóstico de convergencia de la cadena MCMC (sin esto no hay forma de saber si las
#            posiciones/coeficientes estimados son estables o un artefacto de mal mixing)
mcmc.diagnostics(modelo.latente)

# CALCULO -> probabilidades predichas: se usa predict() directamente (type = 'mkl' es el argumento
#            válido del paquete; 'response' no existe en predict.ergmm) en vez de recalcular la
#            fórmula del predictor lineal a mano.
p.latente <- predict(modelo.latente, type = 'mkl')

# Validación: la fórmula manual (logit = beta0 + beta·covariables - distancia_latente) debería dar
# prácticamente lo mismo que predict(); se deja el chequeo para no confiar en el paquete a ciegas.
Z            <- modelo.latente$mkl$Z
beta.latente <- modelo.latente$mkl$beta
dist.latente <- as.matrix(dist(Z))

covariable.stratum <- if (usar.nodematch) match.stratum else absdiff.stratum
logit.p.latente.manual <- beta.latente[1] +
  beta.latente[2] * distancia +
  beta.latente[3] * covariable.stratum +
  beta.latente[4] * match.locality -
  dist.latente

diferencia.prediccion <- max(abs(plogis(logit.p.latente.manual) - p.latente), na.rm = TRUE)
cat('Diferencia máxima entre predict(type = "mkl") y la fórmula manual:', diferencia.prediccion, '\n')

tabla.latente <- rank_missing_dyads(p.latente, red.tm, tm.graph)
colnames(tabla.latente)[3] <- 'probabilidad latente'

# ------------------------------------- TABLA COMBINADA ---------------------------------------------

candidatos.rutas <- merge(tabla.ergm, tabla.latente, by = c('estacion.1', 'estacion.2'))
candidatos.rutas$'probabilidad promedio' <- rowMeans(candidatos.rutas[, c('probabilidad ergm', 'probabilidad latente')])
candidatos.rutas <- candidatos.rutas[order(-candidatos.rutas$`probabilidad promedio`), ]

write.csv(candidatos.rutas, data.path, row.names = FALSE)
