# datajam3 — Grafo dirigido del sistema troncal de TransMilenio

![R](https://img.shields.io/badge/R-276DC3?style=flat&logo=r&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)
![Status](https://img.shields.io/badge/status-en%20desarrollo-yellow)

Proyecto para el **DataJam**: modelar el sistema troncal de TransMilenio (Bogotá) como un **grafo dirigido**, donde los nodos son estaciones y las aristas son los tramos servidos por al menos una ruta troncal, ponderados por la cantidad de servicios que los cubren.

El objetivo final combina tres ejes de análisis sobre ese grafo:

- **Análisis de red**: centralidad, cuellos de botella, robustez ante fallas.
- **Optimización**: simulación de qué pasa al agregar/eliminar rutas, scoring de criticidad de rutas.
- **Impacto social**: cruce con estratificación socioeconómica y localidad, para ver si las estaciones/rutas más críticas concentran población vulnerable o con pocas alternativas de transporte.

## Estructura del repositorio

```
datajam3/
├── code/
│   ├── graph building.R              # Pipeline principal: GTFS -> grafo dirigido (igraph)
│   ├── get_downloads_url.R           # Scraping de URLs de descarga diarias (TMSA)
│   ├── build_social_context.R        # Corre el cruce espacial y guarda el CSV de estrato/localidad
│   ├── descriptive_analysis.R        # Descriptivo básico y de red (grado, fuerza, centralidad, conectividad, agrupamiento)
│   ├── build_route_proposals.R       # Ajusta ERGM + espacio latente y guarda candidatos a ruta nueva
│   ├── build_route_criticality.R     # Corre critical_alpha() (topológico y por demanda) sobre las 111 rutas
│   ├── build_route_score.R           # Combina criticidad + redundancia + % vulnerables en un cuadrante
│   ├── build_robustness_comparison.R # p-valor empírico y z-score de la robustez real vs. modelo nulo
│   ├── build_monotonicity_check.R    # Verifica si alpha_c es monótono en alpha (barrido fino)
│   ├── build_frequency_graph.R       # Reprocesa el GTFS por viaje (no por ruta) para un peso de frecuencia real
│   ├── build_route_criticality_frequency.R  # critical_alpha() con capacidad por frecuencia real (sensibilidad)
│   └── funct/
│       ├── station_stress.R          # stop_stress(): demanda real (validaciones/salidas) por estación/hora
│       ├── station_demand.R          # station_demand(): agrega demanda por estación (con crosswalk TMSA↔GTFS)
│       ├── station_social_context.R  # station_social_context(): estrato y localidad por estación
│       ├── null_graphs.R             # null_graphs(): réplicas del modelo de configuración (misma secuencia de grados)
│       ├── robustness_index.R        # robustness_curve() / robustness_index(): robustez (Schneider et al., 2011)
│       ├── remove_route.R            # remove_route(): quita una ruta del grafo (ajusta weight/services_flat)
│       ├── route_cascade.R           # edge_load() / route_cascade() / critical_alpha(): cascada de fallas (Motter-Lai)
│       ├── route_utils.R             # route_name() / route_edge_count() / route_redundancy() / route_stations()
│       └── link_prediction_data.R    # matriz de distancia, objeto network, ranking de pares sin tramo directo
├── data/
│   ├── GTFS.txt                          # URL del ZIP GTFS vigente de TransMilenio
│   ├── TM graph.graphml                  # Grafo exportado (nodos, aristas, pesos, servicios)
│   ├── download url salidas.csv          # URLs diarias de archivos de salidas (auto-actualizado)
│   ├── download url validaciones.csv     # URLs diarias de archivos de validaciones (auto-actualizado)
│   ├── estaciones estrato localidad.csv  # Estrato + localidad por estación
│   ├── candidatos ruta nueva.csv         # Ranking de pares de estaciones sin tramo directo (ERGM + espacio latente)
│   ├── criticidad rutas.csv              # alpha_c topológico y ponderado por demanda para las 111 rutas
│   ├── criticidad rutas (frecuencia).csv # lo mismo, con capacidad basada en frecuencia real de viajes
│   ├── score criticidad rutas.csv        # criticidad + redundancia + % estaciones vulnerables (3 umbrales) por ruta
│   └── robustez modelo nulo.csv          # p-valor empírico y z-score de R real vs. modelo nulo
├── archive/                           # Exploraciones de visualización (leaflet, maptiles) fuera del pipeline principal
└── .github/workflows/
    └── update_download_urls.yml      # Cron diario que actualiza los CSV de URLs de descarga
```

## Fuentes de datos

Todas de acceso abierto:

- **GTFS de TransMilenio** — rutas, paradas y horarios del sistema troncal. [Portal GTFS TM](https://datosabiertos-transmilenio.hub.arcgis.com/search?q=GTFS&sort=Date%20Updated%7Cmodified%7Cdesc)
- **Validaciones diarias del sistema troncal** — entradas por estación/hora. [Dataset](https://datosabiertos.bogota.gov.co/dataset/validaciones-diarias-sitp)
- **Salidas registradas del sistema troncal** — salidas por estación/franja horaria. [Dataset](https://datosabiertos.bogota.gov.co/dataset/consolidado-de-salidas-sistema-troncal-por-franja-horaria)
- **Estratificación por manzana** — estrato socioeconómico. [Dataset](https://datosabiertos.bogota.gov.co/dataset/estratificacion-para-bogota)
- **Localidades de Bogotá D.C.** — límites de las 20 localidades. [Dataset](https://datosabiertos.bogota.gov.co/dataset/localidad-bogota-d-c)

## Pipeline

1. **`code/graph building.R`** — descarga el GTFS (sin bajar el ZIP completo, lee directo del archivo comprimido), filtra los servicios troncales, y construye `tm.graph`: un grafo dirigido en `igraph` donde cada arista guarda `weight` (cantidad de rutas que la cubren) y la lista de `services`/`services names` que la recorren. El bloque de exportación a GraphML está comentado mientras se itera sobre la estructura del grafo; `data/TM graph.graphml` es la última versión exportada.

2. **`code/get_downloads_url.R`** — hace scraping de las páginas de listados de TMSA y guarda las URLs de descarga diarias de validaciones y salidas en `data/*.csv`. Se ejecuta automáticamente todos los días mediante `.github/workflows/update_download_urls.yml`, que commitea los cambios si los hay.

3. **`code/funct/station_stress.R`** — `stop_stress(dates, format)` descarga y agrega, para un rango de fechas, las validaciones y salidas reales por estación y hora, usando las URLs generadas en el paso anterior.

4. **`code/funct/station_social_context.R`** / **`code/build_social_context.R`** — `station_social_context()` toma las estaciones del grafo (`TM graph.graphml`) y las cruza espacialmente con las capas de estratificación y localidades del portal de datos abiertos de Bogotá:
   - **Localidad**: contención directa punto-en-polígono.
   - **Estrato**: como las estaciones caen sobre vías/separadores (rara vez dentro de una manzana residencial), se usa un radio de influencia de 400 m y se toma el estrato residencial más frecuente alrededor; si no hay ninguna manzana en ese radio (p. ej. estaciones de Soacha, fuera de la cobertura del dataset), se usa la manzana más cercana como respaldo.

   `build_social_context.R` corre la función y guarda el resultado en `data/estaciones estrato localidad.csv`.

5. **`code/descriptive_analysis.R`** — descriptivo básico (tamaño del grafo, rutas distintas, distribución del peso de los tramos) y descriptivo de red siguiendo el marco del curso de Análisis Estadístico de Redes (Juan Sosa, UNAL): grado y fuerza, centralidad (intermediación, cercanía), conectividad (componentes, distancias, cliques) y agrupamiento (transitividad).

6. **`code/funct/null_graphs.R`** / **`code/funct/robustness_index.R`** / **`code/build_robustness_comparison.R`** — infraestructura para comparar la robustez real de TM contra la esperable solo por su distribución de grado: `null_graphs()` genera réplicas del modelo de configuración (misma secuencia de grados de entrada/salida, vía edge-switching), y `robustness_curve()`/`robustness_index()` calculan el índice de robustez `R` (Schneider et al., 2011) ante remoción aleatoria de estaciones. `build_robustness_comparison.R` no se queda en comparar rangos a simple vista: calcula el **p-valor empírico** y el **z-score** de la robustez real contra 500 réplicas nulas. **Hallazgo**: TM es sistemáticamente menos robusto de lo esperable solo por su distribución de grado (R real ≈ 0.39 vs. R nulo ≈ 0.48; **p = 0.002, z = -15.93**) — la fragilidad viene de la forma específica de los corredores, no solo de cuántas rutas tiene cada estación, y la diferencia es estadísticamente contundente, no solo visualmente sugestiva.

7. **`code/funct/remove_route.R`** / **`code/funct/route_cascade.R`** / **`code/build_monotonicity_check.R`** — simulación de cascada de fallas al eliminar una ruta, enmarcada como un escenario de contingencia **N-k** (remoción simultánea de k componentes relacionados — todos los tramos de una ruta — un marco establecido en infraestructura crítica/sistemas de potencia) con una función de carga tipo Motter & Lai (2002): `remove_route()` quita la ruta del grafo, `route_cascade()` redistribuye la carga (intermediación de arista, opcionalmente pesada por demanda real relativizada por su promedio) y hace fallar los tramos que superan su capacidad. La capacidad queda anclada a la magnitud de la intermediación (para no desajustar la escala) pero se modula por un atributo de capacidad instalada (`capacity.attr`, por defecto `weight` = cuántas rutas sirven el tramo) relativizado por su promedio — un tramo con más capacidad instalada que el promedio tiene proporcionalmente más margen, y con menos, proporcionalmente menos. La capacidad nunca se pondera por demanda directamente (si se ponderaran igual carga y capacidad, el factor se cancelaría en la comparación y la demanda nunca podría cambiar el resultado).

   `critical_alpha()` encuentra el margen de tolerancia mínimo (`alpha_c`) para que no se desate una cascada grande — pero **no por bisección**: `build_monotonicity_check.R` verificó con un barrido fino que 8 de 10 rutas de prueba violan la monotonicidad que la bisección asumía (comportamiento no monótono documentado en la literatura para redes espacialmente embebidas), así que `critical_alpha()` hace un barrido fino y exige que la cascada se **mantenga** por debajo del umbral en el resto de la rejilla, no que solo la cruce una vez. **Hallazgo**: las rutas más "peligrosas" bajo este modelo no son las de mayor centralidad clásica, sino rutas cortas que actúan como válvula de escape del sistema.

8. **`code/funct/link_prediction_data.R`** / **`code/build_route_proposals.R`** — propone rutas nuevas con respaldo estadístico: se ajustan un ERGM y un modelo de espacio latente (`ergm`/`latentnet`) sobre la versión no dirigida del grafo, con distancia geográfica, coincidencia de localidad y estrato (`nodematch`, no `absdiff` — ver nota) como covariables. El script ajusta ambas versiones del término de estrato (`absdiff` y `nodematch`) y compara AIC/BIC en vez de asumir cuál es correcta; salen estadísticamente empatadas (ΔAIC < 2), así que se usa `nodematch` por ser la elección teóricamente correcta para una variable ordinal. El `gof()` del ERGM ganador ajusta bien en grado y en los términos incluidos, pero **falla en "edgewise shared partners"** (agrupamiento local/triángulos) — confirma que un ERGM de independencia diádica no puede capturar la estructura de clustering real de la red (consistente con la transitividad de 0.35 vista en el descriptivo). El modelo de espacio latente se corre con una cadena MCMC más larga que la default (los factores de dependencia de Raftery-Lewis bajaron sustancialmente al subirla) y usa `predict(type = 'mkl')` en vez de recalcular la fórmula del predictor a mano. Ambos modelos coinciden en que la distancia y la localidad predicen fuertemente la conectividad, mientras que el estrato no es significativo. El resultado combinado queda en `data/candidatos ruta nueva.csv`.

9. **`code/funct/station_demand.R`** / **`code/build_route_criticality.R`** — agrega la demanda real (validaciones + salidas) por estación con `station_demand()`, incluyendo un crosswalk manual entre la codificación de estación de TMSA (validaciones/salidas) y el `stop_id` del GTFS, ya que no coinciden 1 a 1 (plataformas alternas, ampliaciones, puntos temporales por obras se remapean a su estación permanente; TransMiCable, bicicleteros y patios de alimentadoras se excluyen por no ser estaciones troncales). `build_route_criticality.R` corre `critical_alpha()` topológico y ponderado por demanda sobre las 111 rutas y guarda el ranking combinado en `data/criticidad rutas.csv`.

10. **`code/funct/route_utils.R`** / **`code/build_route_score.R`** — combina, para cada ruta, su criticidad (topológica y por demanda, de `criticidad rutas.csv`), su redundancia (`route_redundancy()`: cuántas otras rutas comparten, en promedio, sus tramos) y su componente social (`route_stations()` + % de estaciones vulnerables que cubre, no promedio de estrato, por ser una variable ordinal) en un cuadrante en vez de un solo índice. Como la distribución cruda de `alpha_c demanda` queda muy concentrada, el cuadrante se grafica por **percentil** de cada eje. Se probó la sensibilidad del umbral "vulnerable" (estrato ≤1, ≤2, ≤3): las correlaciones de Spearman entre los 3 rankings son solo moderadas a débiles (0.25-0.69) — el ranking de rutas "más vulnerables" **no es robusto** al corte exacto elegido, una limitación honesta que queda documentada en vez de ocultada. Guarda el resultado en `data/score criticidad rutas.csv`.

11. **`code/build_frequency_graph.R`** / **`code/build_route_criticality_frequency.R`** — chequeo de sensibilidad: ¿cambia el cuello de botella si la capacidad se basa en frecuencia real de viajes en vez de solo cuántas rutas comparten el tramo? `build_frequency_graph.R` reprocesa el GTFS manteniendo granularidad de viaje individual (que `graph building.R` colapsa deliberadamente) para obtener `weight_viajes`, correlacionado (Spearman = 0.83) pero no idéntico al peso por conteo de rutas. **Hallazgo**: con capacidad por frecuencia real, el cuello de botella sistémico **cambia** — de Portal 20 de Julio → Av. Primero de Mayo a **Restrepo → Avenida Jiménez** (59/61 rutas empatadas, 97%), coherente con que Avenida Jiménez ya era la estación más importante del sistema por grado e intermediación desde el descriptivo inicial. Esta versión (capacidad por frecuencia real) es más realista y es el hallazgo que se reporta como principal; la versión por conteo de rutas queda como referencia de cuánto puede cambiar la conclusión según cómo se defina la capacidad.

## Resultados

Hallazgos principales hasta ahora, con el paso del pipeline que los produjo:

| Hallazgo | Paso |
|---|---|
| El grafo es fuertemente conexo (139/139 estaciones en un solo componente), con distancia promedio de 7 tramos y diámetro de 12 — topología alargada, no una malla densa. Transitividad global de 0.35. | 5 · `descriptive_analysis.R` |
| Avenida Jiménez y Ricaurte son las estaciones más importantes tanto por grado/fuerza como por intermediación — coincide con su rol real de intercambio en el sistema. La intermediación también revela estaciones "silenciosamente críticas" (Bosa, Gobernación) que no destacan por grado pero son paso obligado entre ramales. | 5 · `descriptive_analysis.R` |
| TM es sistemáticamente **menos robusto** de lo esperable solo por su distribución de grado: R real ≈ 0.39 vs. R nulo ≈ 0.48 (500 réplicas). La diferencia es estadísticamente contundente, no solo visualmente sugestiva: **p = 0.002, z = -15.93**. La fragilidad viene de la forma específica de los corredores. | 6 · `null_graphs.R` + `build_robustness_comparison.R` |
| Las rutas más "peligrosas" bajo el modelo de cascada de fallas (enmarcado como contingencia N-k) **no son** las de mayor centralidad clásica — son rutas cortas tipo atajo cuya eliminación sobrecarga el corredor compartido, con transiciones de fase nítidas en el margen de tolerancia. La cascada **no es monótona** en ese margen (8/10 rutas de prueba violan la monotonicidad) — `critical_alpha()` se corrigió para no asumirla. | 7 · `route_cascade.R` + `build_monotonicity_check.R` |
| La distancia geográfica y compartir localidad predicen fuertemente si dos estaciones tienen un tramo directo; el estrato (tratado correctamente como `nodematch`, no `absdiff`) **no** es significativo en ningún modelo — aunque el ERGM falla en capturar el agrupamiento local real de la red (`gof()` en edgewise shared partners). El candidato a ruta nueva más sólido (aparece en el top 15 de ambos modelos) es **Centro Memoria ↔ Calle 26 - Atrio**. | 8 · `build_route_proposals.R` |
| La demanda real reordena bastante la criticidad de las rutas frente al ranking puramente topológico. **El cuello de botella sistémico depende de cómo se define la capacidad**: con capacidad por conteo de rutas, es Portal 20 de Julio → Av. Primero de Mayo (32/111 rutas empatadas); con capacidad por **frecuencia real de viajes** (más realista), cambia a **Restrepo → Avenida Jiménez** (59/61 rutas empatadas, 97%) — coherente con que Jiménez ya era la estación más central del sistema desde el descriptivo. | 9, 11 · `build_route_criticality.R` + `build_frequency_graph.R` |
| El componente social (% de estaciones vulnerables que cubre una ruta) no se concentra en ningún cuadrante particular del score de criticidad — confirma, desde otro ángulo, el hallazgo del ERGM: el estrato no está alineado con la estructura de la red. Ojo: este ranking de vulnerabilidad **no es robusto** al umbral de corte elegido (correlación de Spearman de solo 0.25-0.69 entre distintos cortes de estrato). | 10 · `build_route_score.R` |

## Limitaciones conocidas y trabajo futuro

Esta sección documenta explícitamente las limitaciones metodológicas identificadas en una revisión crítica del proyecto contra literatura académica, que no se corrigieron por su costo (tiempo/datos) frente al alcance de un DataJam, en vez de dejarlas implícitas:

- **El grafo está en L-space, no P-space.** La arista conecta paradas consecutivas dentro de una misma ruta (representación estándar de Von Ferber et al. 2009 y Derrible & Kennedy), pero la literatura muestra que la representación P-space (parada-a-parada, considerando transferencias) puede dar rankings de criticidad distintos específicamente para análisis de robustez/cascada de fallas (ej. comparación en Shenzhen Metro). Rehacer el análisis en P-space y comparar si el cuello de botella se mantiene es el trabajo futuro más importante pendiente.
- **Las transferencias entre corredores en la misma estación física se asumen de costo cero.** El L-space no representa el "costo" real de un transbordo (caminata, espera); la literatura sobre "transfer constraint" en redes de metro muestra que esto puede sobreestimar la robustez real del sistema.
- **La demanda se aproxima con un producto de demandas por estación, no con pares origen-destino reales.** No se cuenta con datos de viajes OD (solo demanda agregada por estación), así que no se pudo calcular una intermediación pesada por flujo real; la aproximación usada (raíz del producto de demandas, relativizada por su promedio) es razonable pero no equivalente.
- **El umbral de "estación vulnerable" (estrato ≤2) no es robusto** (ver Resultados) — una métrica que no dependa de un corte arbitrario (índice de Gini o de Theil sobre la distribución completa de estrato) sería más defendible para la narrativa de equidad.

## Requisitos

Paquetes de R usados en el proyecto:

```r
install.packages(c("archive", "dplyr", "igraph", "terra", "maptiles",
                   "sf", "rvest", "pbapply", "leaflet", "htmltools",
                   "network", "ergm", "latentnet"))
```

## Estado actual

- [x] Construcción del grafo dirigido base a partir de GTFS
- [x] Ingesta automatizada (diaria) de demanda real (validaciones/salidas)
- [x] Componente social: estrato y localidad por estación
- [x] Descriptivo básico y de red (grado, fuerza, centralidad, conectividad, agrupamiento)
- [x] Modelo nulo + índice de robustez ante remoción de estaciones
- [x] Simulación de cascada de fallas al eliminar una ruta (Motter-Lai)
- [x] Propuesta de rutas nuevas con respaldo estadístico (ERGM + espacio latente)
- [x] Simulación de cascada ponderada por demanda real y ranking de criticidad (topológico + demanda) de las 111 rutas
- [x] Score unificado de criticidad de rutas (estructura + demanda + redundancia + componente social) en cuadrante
- [x] Revisión crítica contra literatura académica: significancia formal, diagnósticos de bondad de ajuste/convergencia, verificación de monotonicidad, sensibilidad de umbrales, chequeo de capacidad por frecuencia real
- [ ] Visualización final integrando todos los componentes
- [ ] (Futuro) Comparación L-space vs. P-space y modelado de fricción de transbordo

## Autores

- [Mendivenson](https://github.com/Mendivenson)
- [CapStat-ML](https://github.com/CapStat-ML)

## Licencia

Este proyecto está bajo licencia [MIT](LICENSE).

Los datasets del portal de datos abiertos de Bogotá se usan bajo licencia Creative Commons Attribution 4.0.
