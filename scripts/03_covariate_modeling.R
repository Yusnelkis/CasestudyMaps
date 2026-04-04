# =============================================================================
# 03_covariate_modeling.R — Modelado ML de covariables (stacking)
# =============================================================================
# Objetivo: Usar multiples algoritmos ML para modelar la relacion entre
#           covariables raster y la variable de respuesta. Los resultados
#           se combinan ("stacking") como insumo para el modelo espacial.

source("R/utils.R")
load_project_packages()

# --- 0. Cargar datos preparados (ejecutar 02 primero) ------------------------
# Si guardaste los objetos:
# point_data <- readRDS("data/prepared_points.rds")
# covariates <- terra::rast("data/covariates_stack.tif")

# Para este ejemplo, usamos datos del paquete
data("benin_stunting_data", package = "mbg")
data("benin_covariates", package = "mbg")

# --- 1. Configurar validacion cruzada ----------------------------------------

cv_settings <- caret::trainControl(
  method = "repeatedcv",
  number = 5,          # 5 folds
  repeats = 5,         # 5 repeticiones
  savePredictions = "final",
  allowParallel = TRUE
)

cat("Validacion cruzada: 5-fold x 5 repeticiones\n")

# --- 2. Definir modelos ML ---------------------------------------------------

# Lista de algoritmos para stacking
model_list <- c(
  "glmnet",     # Elastic Net (regresion regularizada)
  "gbm",        # Gradient Boosted Trees
  "ranger"      # Random Forest (implementacion rapida)
)

cat("Modelos a entrenar:", paste(model_list, collapse = ", "), "\n")

# --- 3. Entrenar modelos de covariables --------------------------------------
# mbg puede hacer el stacking internamente via MbgModelRunner,
# pero tambien puedes hacerlo manualmente con caret.

# Ejemplo manual con caret:
# results <- list()
# for (model_name in model_list) {
#   cat("Entrenando:", model_name, "...\n")
#   results[[model_name]] <- caret::train(
#     x = covariate_values,   # Valores de covariables en puntos de observacion
#     y = response,            # Variable de respuesta
#     method = model_name,
#     trControl = cv_settings,
#     tuneLength = 5
#   )
# }

# --- 4. Evaluar importancia de covariables ------------------------------------

# Para cada modelo entrenado, evaluar que covariables son mas importantes:
# for (model_name in names(results)) {
#   imp <- caret::varImp(results[[model_name]])
#   cat("\n=== Importancia de variables:", model_name, "===\n")
#   print(imp)
# }

# --- 5. Nota sobre stacking en mbg -------------------------------------------
# En la practica, MbgModelRunner maneja el stacking automaticamente.
# Solo necesitas especificar:
#   - Los rasters de covariables
#   - Los metodos ML a usar
#   - La configuracion de CV
#
# El runner genera predicciones stacked que se usan como covariable
# en el modelo geoestadistico (script 04).

cat("\nModelado de covariables completado.\n")
cat("Continua con 04_spatial_model.R\n")
