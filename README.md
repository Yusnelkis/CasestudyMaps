# CasestudyMaps: Emisiones Industriales en Europa (E-PRTR)

Caso de estudio de **geoestadistica con Machine Learning** aplicado a emisiones industriales de CO2 en Europa, usando el paquete R [`mbg`](https://cran.r-project.org/package=mbg) (Model-Based Geostatistics).

## Objetivo

Modelar la distribucion espacial de emisiones industriales de CO2 en la UE a partir de datos del **European Pollutant Release and Transfer Register (E-PRTR)**, combinando:

- **Datos puntuales**: ~33,000 instalaciones industriales con coordenadas y emisiones reportadas
- **Covariables raster**: Calidad del aire (CAMS), uso del suelo (CORINE), densidad de poblacion
- **Limites administrativos**: Regiones NUTS para agregacion con incertidumbre

El modelo captura la **autocorrelacion espacial** de las emisiones, algo que los modelos ML tradicionales ignoran.

## Por que es relevante?

- Conecta directamente con la **Directiva de Emisiones Industriales** de la UE
- Identifica **hotspots de descarbonizacion** y patrones espaciales
- Genera superficies continuas de emision con **cuantificacion de incertidumbre**
- Evalua la relacion entre emisiones y factores socio-ambientales

## Inicio rapido

```r
# 1. Abrir el proyecto en RStudio (CasestudyMaps.Rproj)

# 2. Instalar dependencias
source("scripts/00_setup.R")

# 3. Descargar datos publicos
source("scripts/00_download_data.R")

# 4. Explorar los datos
source("scripts/01_explore_data.R")
```

## Estructura del proyecto

```
scripts/
  00_setup.R                 # Instalacion de dependencias
  00_download_data.R         # Descarga de datos E-PRTR, NUTS, CORINE
  01_explore_data.R          # Exploracion de emisiones y covariables
  02_data_preparation.R      # Preparacion de datos para mbg
  03_covariate_modeling.R    # Stacking ML (elastic net, GBM, random forest)
  04_spatial_model.R         # Modelo geoestadistico Bayesiano (INLA + SPDE)
  05_prediction_validation.R # Predicciones, validacion cruzada, mapas

R/
  utils.R                    # Funciones auxiliares compartidas

data/                        # Datos descargados (E-PRTR, NUTS, rasters)
output/                      # Resultados: mapas, tablas, modelos
docs/                        # Referencias y documentacion
```

## Flujo de trabajo

1. **Descarga de datos** -- E-PRTR (emisiones), NUTS (limites), CORINE (uso del suelo), poblacion
2. **Exploracion** -- Distribucion espacial de emisiones, sectores industriales, patrones
3. **Preparacion** -- Limpieza, transformacion log, alineacion CRS, raster de IDs
4. **Covariables ML** -- Stacking con elastic net, GBM y random forest
5. **Modelo espacial** -- Proceso Gaussiano con mesh SPDE via INLA
6. **Prediccion y validacion** -- Superficies de emision, incertidumbre, CV espacial

## Fuentes de datos

| Dataset | Fuente | Formato |
|---------|--------|---------|
| E-PRTR emisiones | [EEA Industrial Emissions Portal](https://industry.eea.europa.eu/download) | CSV |
| NUTS boundaries | [Eurostat GISCO](https://ec.europa.eu/eurostat/web/gisco/geodata/statistical-units/territorial-units-statistics) | GeoJSON |
| CORINE Land Cover | [Copernicus Land](https://land.copernicus.eu/en/products/corine-land-cover) | GeoTIFF |
| Densidad de poblacion | [Eurostat / JRC GHSL](https://ghsl.jrc.ec.europa.eu/) | GeoTIFF |

## Recursos

- [mbg CRAN](https://cran.r-project.org/package=mbg) | [GitHub](https://github.com/henryspatialanalysis/mbg) | [Docs](https://henryspatialanalysis.github.io/mbg/)
- [E-PRTR Industrial Emissions Portal](https://industry.eea.europa.eu/)
- [Copernicus Climate Data Store](https://cds.climate.copernicus.eu/)
- [Eurostat GISCO](https://ec.europa.eu/eurostat/web/gisco)
