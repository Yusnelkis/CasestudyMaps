# =============================================================================
# 04_spatial_model.R — Modelo geoestadistico de emisiones CO2
# =============================================================================
# Objetivo: Ajustar un modelo Bayesiano espacial (INLA + SPDE) para modelar
#           la distribucion de emisiones industriales de CO2 en Europa.
#           El modelo captura la autocorrelacion espacial que los modelos ML
#           por si solos no pueden manejar.

source("R/utils.R")
load_project_packages()

# --- 0. Cargar datos preparados -----------------------------------------------

mbg_input <- readRDS("data/prepared_emissions.rds")
nuts2_eu <- readRDS("data/nuts2_eu.rds")

cat(sprintf("Datos: %d instalaciones\n", nrow(mbg_input)))

# --- 1. Construir mesh SPDE --------------------------------------------------
# El mesh es una triangulacion del espacio que aproxima el proceso Gaussiano.
# Para escala europea:
#   - mesh_max_edge interior: ~1-2 grados (~100-200 km)
#   - mesh_max_edge exterior: ~5-10 grados (zona de amortiguacion)

mesh <- mbg::build_mesh(
  data = mbg_input,
  mesh_max_edge = c(1.5, 8.0)  # Ajustar segun resolucion deseada
)

cat(sprintf("Mesh SPDE construido: %d vertices\n", mesh$n))

# Visualizar mesh
# plot(mesh)
# points(mbg_input$longitude, mbg_input$latitude, col = "red", pch = 16, cex = 0.3)

# --- 2. Preparar covariables raster (si disponibles) -------------------------

# Verificar si hay covariables raster
cov_files <- list.files("data/covariates", pattern = "\\.tif$", full.names = TRUE)

if (length(cov_files) > 0) {
  cat("Covariables raster encontradas:\n")
  covariate_rasters <- terra::rast(cov_files)
  for (i in seq_along(cov_files)) {
    cat(sprintf("  - %s\n", basename(cov_files[i])))
  }
} else {
  cat("Sin covariables raster — modelo solo con proceso Gaussiano espacial.\n")
  covariate_rasters <- NULL
}

# --- 3. Configurar MbgModelRunner (Modelo Gaussiano) -------------------------
# Nota: mbg usa familia Gaussiana para datos continuos (log-emisiones).
# Para emisiones en escala log, usamos family = "gaussian".

cat("\n=== Configurando MbgModelRunner ===\n")

# Preparar template raster para predicciones
eu_extent <- terra::ext(-12, 45, 34, 72)
template_raster <- terra::rast(eu_extent, res = 0.1, crs = "EPSG:4326")
template_raster[] <- 1

# Construir id_raster
id_raster <- mbg::build_id_raster(
  raster_template = template_raster,
  shapefile = nuts2_eu
)

# Construir tabla de agregacion
aggregation_table <- mbg::build_aggregation_table(
  polygons = nuts2_eu,
  id_raster = id_raster,
  polygon_id_field = "NUTS_ID"
)

# Configurar el runner
runner <- mbg::MbgModelRunner$new(
  input_data = mbg_input,
  id_raster = id_raster,

  # Columnas de datos
  outcome_column = "log_co2",
  longitude_column = "longitude",
  latitude_column = "latitude",

  # Covariables (NULL si no hay rasters)
  covariate_rasters = covariate_rasters,

  # Limites administrativos
  shapefile = nuts2_eu,
  aggregation_table = aggregation_table,

  # Configuracion del mesh
  mesh_max_edge = c(1.5, 8.0),

  # Familia del modelo (Gaussiana para datos continuos)
  family = "gaussian",
  include_nugget = TRUE,

  # Priors (penalized complexity)
  # Para escala europea: rango esperado de varios grados
  prior_spde_range = c(5, 0.05),      # P(range < 5 grados) = 0.05
  prior_spde_sigma = c(2, 0.05),      # P(sigma > 2) = 0.05

  verbose = TRUE
)

cat("MbgModelRunner configurado.\n")

# --- 4. Ajustar el modelo ---------------------------------------------------

cat("\n=== Ajustando modelo geoestadistico ===\n")
cat("Esto puede tardar varios minutos para escala europea...\n\n")

# Descomentar para ejecutar:
# runner$run_mbg_pipeline()

# --- 5. Diagnosticos del modelo ----------------------------------------------

# Despues de ajustar el pipeline:
#
# cat("\n=== Diagnosticos ===\n")
#
# # WAIC y DIC
# cat("WAIC:", runner$inla_fitted_model$waic$waic, "\n")
#
# # Efectos fijos
# cat("\nEfectos fijos:\n")
# print(runner$inla_fitted_model$summary.fixed)
#
# # Hiperparametros (rango y varianza del proceso Gaussiano)
# cat("\nHiperparametros:\n")
# print(runner$inla_fitted_model$summary.hyperpar)
#
# # El rango practico indica la distancia a la que la correlacion
# # espacial cae a ~0.13. Para emisiones europeas, esperamos
# # valores de varios cientos de km.

# --- 6. Guardar modelo -------------------------------------------------------

# saveRDS(runner, "output/fitted_spatial_model.rds")
cat("\nModelo configurado. Descomentar lineas para ejecutar el pipeline.\n")
cat("Continua con 05_prediction_validation.R\n")
