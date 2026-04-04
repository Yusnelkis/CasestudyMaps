# CasestudyMaps: Geospatial ML with `mbg`

Proyecto para explorar **Model-Based Geostatistics (mbg)** — un paquete de R para Machine Learning espacial que respeta la autocorrelacion espacial mediante modelos Bayesianos.

## Que es mbg?

La mayoria de modelos ML ignoran la autocorrelacion espacial, lo que puede generar errores graves. `mbg` resuelve esto combinando ML con geoestadistica Bayesiana:

- Soporte completo para objetos `sf` y `terra`
- Ajuste Bayesiano via INLA o TMB
- Predicciones espaciales con intervalos de credibilidad
- Validacion cruzada espacial (spatial CV)
- Aplicaciones en epidemiologia, medio ambiente, agricultura y mas

## Inicio rapido

```r
# 1. Abrir el proyecto en RStudio (CasestudyMaps.Rproj)

# 2. Instalar dependencias
source("scripts/00_setup.R")

# 3. Explorar el paquete
source("scripts/01_explore_mbg.R")
```

## Estructura del proyecto

```
scripts/
  00_setup.R                 # Instalacion de dependencias
  01_explore_mbg.R           # Exploracion del paquete y datos ejemplo
  02_data_preparation.R      # Carga y preparacion de datos espaciales
  03_covariate_modeling.R    # Modelado ML de covariables (stacking)
  04_spatial_model.R         # Ajuste del modelo geoestadistico
  05_prediction_validation.R # Predicciones, validacion y mapas

R/
  utils.R                    # Funciones auxiliares compartidas

data/                        # Datos espaciales (rasters, shapefiles, CSV)
output/                      # Resultados generados (mapas, tablas)
docs/                        # Referencias y documentacion
```

## Flujo de trabajo

1. **Preparacion de datos** — Cargar puntos observados, covariables raster y limites administrativos
2. **Modelado de covariables** — Stacking con multiples algoritmos ML (elastic net, GBM, random forest)
3. **Modelo geoestadistico** — Ajustar proceso Gaussiano espacial con mesh SPDE via INLA
4. **Prediccion** — Generar superficies continuas con cuantificacion de incertidumbre
5. **Validacion** — Cross-validation espacial y agregacion a regiones administrativas

## Recursos

- [CRAN: mbg](https://cran.r-project.org/package=mbg)
- [GitHub: henryspatialanalysis/mbg](https://github.com/henryspatialanalysis/mbg)
- [Documentacion completa](https://henryspatialanalysis.github.io/mbg/)
- [Vignette: Getting Started](https://cran.r-project.org/web/packages/mbg/vignettes/mbg.html)
- [Vignette: Spatial ML Models](https://cran.r-project.org/web/packages/mbg/vignettes/spatial-ml-models.html)
- [Vignette: Model Comparison](https://cran.r-project.org/web/packages/mbg/vignettes/model-comparison.html)
