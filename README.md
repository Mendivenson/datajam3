# datajam3 — Grafo dirigido del sistema troncal de TransMilenio

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
│   └── funct/
│       ├── station_stress.R          # stop_stress(): demanda real (validaciones/salidas) por estación/hora
│       └── station_social_context.R  # station_social_context(): estrato y localidad por estación
├── data/
│   ├── GTFS.txt                          # URL del ZIP GTFS vigente de TransMilenio
│   ├── TM graph.graphml                  # Grafo exportado (nodos, aristas, pesos, servicios)
│   ├── download url salidas.csv          # URLs diarias de archivos de salidas (auto-actualizado)
│   ├── download url validaciones.csv     # URLs diarias de archivos de validaciones (auto-actualizado)
│   └── estaciones estrato localidad.csv  # Estrato + localidad por estación
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

## Requisitos

Paquetes de R usados en el proyecto:

```r
install.packages(c("archive", "dplyr", "igraph", "terra", "maptiles",
                   "sf", "rvest", "pbapply", "leaflet", "htmltools"))
```

## Estado actual

- [x] Construcción del grafo dirigido base a partir de GTFS
- [x] Ingesta automatizada (diaria) de demanda real (validaciones/salidas)
- [x] Componente social: estrato y localidad por estación
- [ ] Simulación de impacto al agregar/eliminar rutas (robustez de red)
- [ ] Scoring de criticidad de rutas (estructural + demanda + redundancia + social)
- [ ] Visualización final integrando todos los componentes

## Licencia de los datos

Los datasets del portal de datos abiertos de Bogotá se usan bajo licencia Creative Commons Attribution 4.0.
