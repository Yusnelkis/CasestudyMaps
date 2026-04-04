# =============================================================================
# 02_data_preparation.R — Carga y preparacion de datos espaciales
# =============================================================================
# Objetivo: Preparar los insumos para el modelo geoestadistico.
#   - Datos de puntos (observaciones con coordenadas)
#   - Covariables raster (variables predictoras)
#   - Limites administrativos (para agregacion)

source("R/utils.R")
load_project_packages()

# --- 1. Cargar datos de puntos -----------------------------------------------
# Opcion A: Datos de ejemplo del paquete
data("benin_stunting_data", package = "mbg")
point_data <- benin_stunting_data

# Opcion B: Cargar tus propios datos (descomenta y ajusta)
# point_data <- read.csv("data/tu_archivo.csv")
# point_data <- sf::st_read("data/tu_archivo.shp")

cat("Datos cargados:", nrow(point_data), "observaciones\n")

# --- 2. Cargar covariables raster --------------------------------------------
# Las covariables son capas raster que cubren el area de estudio
# (clima, elevacion, infraestructura, etc.)

# Opcion A: Datos de ejemplo del paquete
data("benin_covariates", package = "mbg")
covariates <- benin_covariates

# Opcion B: Cargar tus propios rasters
# cov_files <- list.files("data/covariates", pattern = "\\.tif$", full.names = TRUE)
# covariates <- terra::rast(cov_files)

cat("Covariables cargadas:", terra::nlyr(covariates), "capas\n")
print(names(covariates))

# --- 3. Cargar limites administrativos ----------------------------------------

# Opcion A: Datos de ejemplo del paquete
data("benin_admin_boundaries", package = "mbg")
admin_boundaries <- benin_admin_boundaries

# Opcion B: Cargar tus propios limites
# admin_boundaries <- sf::st_read("data/admin_boundaries.gpkg")

cat("Limites administrativos:", nrow(admin_boundaries), "regiones\n")

# --- 4. Verificar alineacion de CRS ------------------------------------------

cat("\n=== Verificacion de CRS ===\n")
cat("CRS covariables:", terra::crs(covariates, describe = TRUE)$code, "\n")
cat("CRS limites admin:", sf::st_crs(admin_boundaries)$epsg, "\n")

# Reproyectar si es necesario
# admin_boundaries <- sf::st_transform(admin_boundaries, terra::crs(covariates))

# --- 5. Construir raster de IDs para prediccion ------------------------------
# mbg necesita un raster de referencia que define la grilla de prediccion

id_raster <- mbg::build_id_raster(
  raster_template = covariates[[1]],
  shapefile = admin_boundaries
)

cat("\nRaster de IDs creado:", terra::ncell(id_raster), "celdas\n")

# --- 6. Guardar objetos preparados -------------------------------------------

cat("\nDatos preparados. Los objetos estan en memoria para usar en los\n")
cat("siguientes scripts. En un proyecto real, puedes guardarlos:\n")
cat('  saveRDS(point_data, "data/prepared_points.rds")\n')
cat('  terra::writeRaster(id_raster, "data/id_raster.tif")\n')

cat("\nContinua con 03_covariate_modeling.R\n")
