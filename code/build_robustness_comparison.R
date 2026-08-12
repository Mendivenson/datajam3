# ------------------- COMPARACIÓN FORMAL: ROBUSTEZ REAL VS. MODELO NULO ------------------
# Calcula el índice de robustez R (Schneider et al., 2011) de TM ante remoción aleatoria de
# estaciones, y lo compara contra la distribución de R en 500 réplicas del modelo de configuración
# (misma secuencia de grados). A diferencia de una primera exploración informal (donde solo se
# comparaban los rangos de valores a simple vista), aquí se calcula un p-valor empírico y un
# z-score, que es el estándar para reportar significancia contra un modelo nulo.

library(igraph)
library(pbapply)

# se admite correr esto parado en la raíz del repo o en code/
funct.dir <- 'funct'
if (!dir.exists(funct.dir)) {
  funct.dir <- file.path('code', funct.dir)
}
source(file.path(funct.dir, 'null_graphs.R'))
source(file.path(funct.dir, 'robustness_index.R'))

data.path <- '../data/robustez modelo nulo.csv'
if (!dir.exists(dirname(data.path))) {
  data.path <- sub('^\\.\\./', '', data.path)
}

# ------------------------------------- ROBUSTEZ REAL (500 CORRIDAS ALEATORIAS) ---------------------------------------------

set.seed(1305)
R.tm <- pbsapply(1:500, function(i) robustness_index(tm.graph))

# ------------------------------------- ROBUSTEZ NULA (500 RÉPLICAS DEL MODELO DE CONFIGURACIÓN) ---------------------------------------------

set.seed(1305)
nulos   <- null_graphs(tm.graph, n = 500)
R.nulos <- pbsapply(nulos, robustness_index)

# ------------------------------------- SIGNIFICANCIA EMPÍRICA ---------------------------------------------

# CALCULO -> p-valor empírico: proporción de réplicas nulas con robustez menor o igual a la real
#            (más 1 en numerador y denominador, para no reportar p = 0 con un número finito de
#            réplicas; es la corrección estándar en pruebas de permutación)
p.valor <- (1 + sum(R.nulos <= mean(R.tm))) / (1 + length(R.nulos))

# CALCULO -> z-score: cuántas desviaciones estándar de la distribución nula está la robustez real
z.score <- (mean(R.tm) - mean(R.nulos)) / sd(R.nulos)

cat('R real (media de 500 corridas):', round(mean(R.tm), 4), '\n')
cat('R nulo (media de 500 réplicas):', round(mean(R.nulos), 4), '\n')
cat('p-valor empírico:', round(p.valor, 4), '\n')
cat('z-score:', round(z.score, 2), '\n')

# ------------------------------------- GUARDAR ---------------------------------------------

resumen <- data.frame(
  'R real media'    = mean(R.tm),
  'R real sd'       = sd(R.tm),
  'R nulo media'    = mean(R.nulos),
  'R nulo sd'       = sd(R.nulos),
  'p valor'         = p.valor,
  'z score'         = z.score,
  check.names = FALSE
)

write.csv(resumen, data.path, row.names = FALSE)

# ------------------------------------- GRÁFICO ---------------------------------------------

hist(R.nulos, breaks = 30, col = 'steelblue', border = 'white',
     main = 'Robustez esperable vs. robustez real de TM',
     xlab = 'Índice de robustez R')
abline(v = mean(R.tm), col = 'darkred', lwd = 2)
