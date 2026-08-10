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
│   └── score criticidad rutas.csv        # criticidad + redundancia + % estaciones vulnerables por ruta
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

6. **`code/funct/null_graphs.R`** / **`code/funct/robustness_index.R`** — infraestructura para comparar la robustez real de TM contra la esperable solo por su distribución de grado: `null_graphs()` genera réplicas del modelo de configuración (misma secuencia de grados de entrada/salida), y `robustness_curve()`/`robustness_index()` calculan el índice de robustez `R` (Schneider et al., 2011) ante remoción de estaciones. **Hallazgo**: TM es sistemáticamente menos robusto de lo esperable solo por su distribución de grado (`R` real muy por debajo del rango de 500 réplicas nulas) — la fragilidad viene de la forma específica de los corredores, no solo de cuántas rutas tiene cada estación.

7. **`code/funct/remove_route.R`** / **`code/funct/route_cascade.R`** — simulación de cascada de fallas (adaptación de Motter & Lai, 2002) al eliminar una ruta: `remove_route()` la quita del grafo, `route_cascade()` redistribuye la carga (intermediación de arista, opcionalmente pesada por demanda real relativizada por su promedio) y hace fallar los tramos que superan su capacidad, y `critical_alpha()` encuentra por búsqueda binaria el margen de tolerancia mínimo para que no se desate una cascada grande. La capacidad queda anclada a la magnitud de la intermediación (para no desajustar la escala) pero se modula por `weight` relativizado por su promedio — un tramo con más rutas instaladas que el promedio tiene proporcionalmente más margen, y con menos, proporcionalmente menos; ignorar esto (como en una primera versión) hacía que un tramo servido por 10 rutas y uno servido por 1 sola tuvieran exactamente la misma capacidad, lo cual no tiene sentido físico. La capacidad nunca se pondera por demanda directamente (si se ponderaran igual carga y capacidad, el factor se cancelaría en la comparación y la demanda nunca podría cambiar el resultado). **Hallazgo**: las rutas más "peligrosas" bajo este modelo no son las de mayor centralidad clásica, sino rutas cortas que actúan como válvula de escape del sistema.

8. **`code/funct/link_prediction_data.R`** / **`code/build_route_proposals.R`** — propone rutas nuevas con respaldo estadístico: se ajustan un ERGM y un modelo de espacio latente (`ergm`/`latentnet`) sobre la versión no dirigida del grafo, con distancia geográfica, diferencia de estrato y coincidencia de localidad como covariables. Ambos modelos coinciden en que la distancia y la localidad predicen fuertemente la conectividad, mientras que la diferencia de estrato no es significativa. El resultado combinado (pares de estaciones sin tramo directo, ordenados por probabilidad predicha) queda en `data/candidatos ruta nueva.csv`.

   *Nota metodológica pendiente*: el estrato se trata como variable numérica (`absdiff`) en ambos modelos, lo que asume intervalos iguales entre categorías aunque es una variable ordinal; queda por decidir si vale la pena usar `nodematch` o una agrupación categórica en su lugar.

9. **`code/funct/station_demand.R`** / **`code/build_route_criticality.R`** — agrega la demanda real (validaciones + salidas) por estación con `station_demand()`, incluyendo un crosswalk manual entre la codificación de estación de TMSA (validaciones/salidas) y el `stop_id` del GTFS, ya que no coinciden 1 a 1 (plataformas alternas, ampliaciones, puntos temporales por obras se remapean a su estación permanente; TransMiCable, bicicleteros y patios de alimentadoras se excluyen por no ser estaciones troncales). `build_route_criticality.R` corre `critical_alpha()` topológico y ponderado por demanda sobre las 111 rutas y guarda el ranking combinado en `data/criticidad rutas.csv`.

10. **`code/funct/route_utils.R`** / **`code/build_route_score.R`** — combina, para cada ruta, su criticidad (topológica y por demanda, de `criticidad rutas.csv`), su redundancia (`route_redundancy()`: cuántas otras rutas comparten, en promedio, sus tramos) y su componente social (`route_stations()` + % de estaciones vulnerables que cubre, no promedio de estrato, por ser una variable ordinal) en un cuadrante en vez de un solo índice. Como la distribución cruda de `alpha_c demanda` queda muy concentrada, el cuadrante se grafica por **percentil** de cada eje (no el valor crudo), para que la mediana divida el plano de forma útil. Guarda el resultado en `data/score criticidad rutas.csv`.

## Resultados

Hallazgos principales hasta ahora, con el paso del pipeline que los produjo:

| Hallazgo | Paso |
|---|---|
| El grafo es fuertemente conexo (139/139 estaciones en un solo componente), con distancia promedio de 7 tramos y diámetro de 12 — topología alargada, no una malla densa. Transitividad global de 0.35. | 5 · `descriptive_analysis.R` |
| Avenida Jiménez y Ricaurte son las estaciones más importantes tanto por grado/fuerza como por intermediación — coincide con su rol real de intercambio en el sistema. La intermediación también revela estaciones "silenciosamente críticas" (Bosa, Gobernación) que no destacan por grado pero son paso obligado entre ramales. | 5 · `descriptive_analysis.R` |
| TM es sistemáticamente **menos robusto** de lo esperable solo por su distribución de grado: el índice de robustez real (R ≈ 0.39, rango 0.31–0.46 en 500 corridas) queda por debajo de todo el rango de 500 réplicas del modelo nulo (R ≈ 0.46–0.50). La fragilidad viene de la forma específica de los corredores. | 6 · `null_graphs.R` + `robustness_index.R` |
| Las rutas más "peligrosas" bajo el modelo de cascada de fallas **no son** las de mayor centralidad clásica — son rutas cortas tipo atajo cuya eliminación sobrecarga el corredor compartido. Se observa una transición de fase nítida: una misma ruta pasa de ~400 tramos caídos en cascada a ~3 con solo 2 puntos porcentuales más de margen de tolerancia. | 7 · `remove_route.R` + `route_cascade.R` |
| La distancia geográfica y compartir localidad predicen fuertemente si dos estaciones tienen un tramo directo (ERGM y espacio latente coinciden en signo y significancia); la diferencia de estrato **no** es significativa en ningún modelo. El candidato a ruta nueva más sólido (aparece en el top 15 de ambos modelos) es **Centro Memoria ↔ Calle 26 - Atrio**. | 8 · `link_prediction_data.R` + `build_route_proposals.R` |
| La demanda real reordena bastante la criticidad de las rutas frente al ranking puramente topológico — sigue tratándose de rutas cortas tipo atajo, pero no las mismas ni en el mismo orden que sin datos de demanda. Además, ~29% de las rutas del sistema (32 de 111), sin importar su propia criticidad estructural, terminan colapsando por el **mismo cuello de botella compartido**: el tramo **Portal 20 de Julio → Av. Primero de Mayo**. La resiliencia de TM ante demanda real depende más de reforzar ese punto específico que de proteger rutas individuales. | 9 · `station_demand.R` + `build_route_criticality.R` |
| El componente social (% de estaciones vulnerables que cubre una ruta) no se concentra en ningún cuadrante particular del score de criticidad — las rutas que sirven más población vulnerable no son ni las más ni las menos críticas por red, aparecen repartidas entre criticidad alta y baja. Confirma, desde otro ángulo, el hallazgo del ERGM: el estrato no está alineado con la estructura de la red. | 10 · `route_utils.R` + `build_route_score.R` |

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
- [ ] Visualización final integrando todos los componentes

## Autores

- [Mendivenson](https://github.com/Mendivenson)
- [CapStat-ML](https://github.com/CapStat-ML)

## Licencia

Este proyecto está bajo licencia [MIT](LICENSE).

Los datasets del portal de datos abiertos de Bogotá se usan bajo licencia Creative Commons Attribution 4.0.
