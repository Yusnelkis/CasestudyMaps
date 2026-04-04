# =============================================================================
# 04_spatial_model.R — Ajuste del modelo geoestadistico
# =============================================================================
# Objetivo: Ajustar un modelo Bayesiano espacial usando INLA con mesh SPDE.
#           Este modelo captura la autocorrelacion espacial que los modelos ML
#           por si solos no pueden manejar.

source("R/utils.R")
load_project_packages()

# --- 0. Cargar datos (ejecutar scripts previos primero) ----------------------

data("benin_stunting_data", package = "mbg")
data("benin_covariates", package = "mbg")
data("benin_admin_boundaries", package = "mbg")

# --- 1. Construir mesh SPDE --------------------------------------------------
# El mesh es una triangulacion del espacio que aproxima el proceso Gaussiano.
# mesh_max_edge controla la resolucion (valores menores = mas detalle, mas lento)

mesh <- mbg::build_mesh(
  data = benin_stunting_data,
  mesh_max_edge = c(0.2, 5.0)   # c(interior, exterior)
)

cat("Mesh SPDE construido:\n")
cat("  Vertices:", mesh$n, "\n")

# --- 2. Configurar MbgModelRunner --------------------------------------------

runner <- mbg::MbgModelRunner$new(
  # Datos de entrada
  data = benin_stunting_data,
  outcome_column = "stunting_indicator",
  sample_size_column = "sample_size",
  longitude_column = "longitude",
  latitude_column = "latitude",

  # Covariables raster
  covariate_rasters = benin_covariates,

  # Limites administrativos
  shapefile = benin_admin_boundaries,

  # Configuracion del modelo
  mesh_max_edge = c(0.2, 5.0),
  family = "binomial",
  include_nugget = TRUE,

  # Priors (penalized complexity)
  prior_spde_range = c(1, 0.05),      # P(range < 1) = 0.05
  prior_spde_sigma = c(1, 0.05),      # P(sigma > 1) = 0.05

  verbose = TRUE
)

cat("\nMbgModelRunner configurado.\n")

# --- 3. Ajustar el modelo ----------------------------------------------------

cat("\n=== Ajustando modelo geoestadistico ===\n")
cat("Esto puede tardar varios minutos...\n")

# runner$fit()

# --- 4. Diagnosticos del modelo -----------------------------------------------

# Despues de ajustar:
# summary(runner$model)
#
# Revisar:
# - WAIC (menor es mejor)
# - Efectos fijos (coeficientes de covariables)
# - Hiperparametros (range y variance del proceso Gaussiano)
# - DIC

cat("\nModelo ajustado. Revisar diagnosticos antes de continuar.\n")
cat("Continua con 05_prediction_validation.R\n")
