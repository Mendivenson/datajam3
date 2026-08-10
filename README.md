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
│   └── funct/
│       ├── station_stress.R          # stop_stress(): demanda real (validaciones/salidas) por estación/hora
│       ├── station_social_context.R  # station_social_context(): estrato y localidad por estación
│       ├── null_graphs.R             # null_graphs(): réplicas del modelo de configuración (misma secuencia de grados)
│       ├── robustness_index.R        # robustness_curve() / robustness_index(): robustez (Schneider et al., 2011)
│       ├── remove_route.R            # remove_route(): quita una ruta del grafo (ajusta weight/services_flat)
│       ├── route_cascade.R           # edge_load() / route_cascade() / critical_alpha(): cascada de fallas (Motter-Lai)
│       └── link_prediction_data.R    # matriz de distancia, objeto network, ranking de pares sin tramo directo
├── data/
│   ├── GTFS.txt                          # URL del ZIP GTFS vigente de TransMilenio
│   ├── TM graph.graphml                  # Grafo exportado (nodos, aristas, pesos, servicios)
│   ├── download url salidas.csv          # URLs diarias de archivos de salidas (auto-actualizado)
│   ├── download url validaciones.csv     # URLs diarias de archivos de validaciones (auto-actualizado)
│   ├── estaciones estrato localidad.csv  # Estrato + localidad por estación
│   └── candidatos ruta nueva.csv         # Ranking de pares de estaciones sin tramo directo (ERGM + espacio latente)
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

7. **`code/funct/remove_route.R`** / **`code/funct/route_cascade.R`** — simulación de cascada de fallas (adaptación de Motter & Lai, 2002) al eliminar una ruta: `remove_route()` la quita del grafo, `route_cascade()` redistribuye la carga (intermediación de arista, opcionalmente pesada por demanda) y hace fallar los tramos que superan su capacidad, y `critical_alpha()` encuentra por búsqueda binaria el margen de tolerancia mínimo para que no se desate una cascada grande. **Hallazgo**: las rutas más "peligrosas" bajo este modelo no son las de mayor centralidad clásica, sino rutas cortas que actúan como válvula de escape del sistema.

8. **`code/funct/link_prediction_data.R`** / **`code/build_route_proposals.R`** — propone rutas nuevas con respaldo estadístico: se ajustan un ERGM y un modelo de espacio latente (`ergm`/`latentnet`) sobre la versión no dirigida del grafo, con distancia geográfica, diferencia de estrato y coincidencia de localidad como covariables. Ambos modelos coinciden en que la distancia y la localidad predicen fuertemente la conectividad, mientras que la diferencia de estrato no es significativa. El resultado combinado (pares de estaciones sin tramo directo, ordenados por probabilidad predicha) queda en `data/candidatos ruta nueva.csv`.

   *Nota metodológica pendiente*: el estrato se trata como variable numérica (`absdiff`) en ambos modelos, lo que asume intervalos iguales entre categorías aunque es una variable ordinal; queda por decidir si vale la pena usar `nodematch` o una agrupación categórica en su lugar.

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
- [ ] Scoring de criticidad de rutas combinando todos los componentes anteriores
- [ ] Visualización final integrando todos los componentes

## Autores

- [Mendivenson](https://github.com/Mendivenson)
- [CapStat-ML](https://github.com/CapStat-ML)

## Licencia

Este proyecto está bajo licencia [MIT](LICENSE).

Los datasets del portal de datos abiertos de Bogotá se usan bajo licencia Creative Commons Attribution 4.0.
