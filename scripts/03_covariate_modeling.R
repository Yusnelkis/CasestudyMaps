# =============================================================================
# 03_covariate_modeling.R — Modelado ML de covariables para emisiones CO2
# =============================================================================
# Objetivo: Entrenar modelos ML para predecir emisiones CO2 a partir de
#           covariables espaciales (uso del suelo, poblacion, etc.)
#           Los resultados se usan como stacking en el modelo geoestadistico.

source("R/utils.R")
load_project_packages()

# --- 0. Cargar datos preparados -----------------------------------------------

mbg_input <- readRDS("data/prepared_emissions.rds")
nuts2_eu <- readRDS("data/nuts2_eu.rds")

cat(sprintf("Datos cargados: %d instalaciones\n", nrow(mbg_input)))

# --- 1. Configurar validacion cruzada ----------------------------------------

cv_settings <- caret::trainControl(
  method = "repeatedcv",
  number = 5,          # 5 folds
  repeats = 3,         # 3 repeticiones
  savePredictions = "final",
  allowParallel = TRUE
)

cat("Validacion cruzada: 5-fold x 3 repeticiones\n")

# --- 2. Definir modelos ML ---------------------------------------------------

model_list <- c(
  "glmnet",     # Elastic Net (regularizacion L1+L2)
  "gbm",        # Gradient Boosted Trees
  "ranger"      # Random Forest (implementacion rapida)
)

cat("Modelos a entrenar:", paste(model_list, collapse = ", "), "\n")

# --- 3. Extraer valores de covariables en puntos de emision -------------------
# Si tienes covariables raster, extrae sus valores en las ubicaciones
# de las instalaciones.

# Ejemplo con covariables raster:
# covariate_stack <- terra::rast(list.files("data/covariates", "\\.tif$",
#                                           full.names = TRUE))
# cov_values <- terra::extract(covariate_stack,
#                              cbind(mbg_input$longitude, mbg_input$latitude))

# Mientras no tengamos rasters, podemos usar coordenadas como proxy
# (la latitud y longitud capturan gradientes climaticos a escala continental)
train_x <- data.frame(
  longitude = mbg_input$longitude,
  latitude = mbg_input$latitude
)
train_y <- mbg_input$log_co2

cat(sprintf("\nMatriz de entrenamiento: %d obs x %d covariables\n",
            nrow(train_x), ncol(train_x)))

# --- 4. Entrenar modelos de covariables --------------------------------------

results <- list()

for (model_name in model_list) {
  cat(sprintf("Entrenando: %s...\n", model_name))

  tryCatch({
    results[[model_name]] <- caret::train(
      x = train_x,
      y = train_y,
      method = model_name,
      trControl = cv_settings,
      tuneLength = 5,
      verbose = FALSE
    )
    cat(sprintf("  RMSE (CV): %.3f\n", min(results[[model_name]]$results$RMSE)))
  }, error = function(e) {
    cat(sprintf("  Error: %s\n", e$message))
  })
}

# --- 5. Comparar modelos -----------------------------------------------------

if (length(results) > 1) {
  cat("\n=== Comparacion de modelos ML ===\n")
  comparison <- caret::resamples(results)
  print(summary(comparison))

  # Importancia de variables
  for (model_name in names(results)) {
    cat(sprintf("\n--- Importancia de variables: %s ---\n", model_name))
    tryCatch({
      imp <- caret::varImp(results[[model_name]])
      print(imp)
    }, error = function(e) {
      cat("  No disponible para este modelo\n")
    })
  }
}

# --- 6. Nota sobre stacking en mbg -------------------------------------------
# En el pipeline completo, MbgModelRunner maneja el stacking internamente:
#
#   runner <- mbg::MbgModelRunner$new(
#     ...
#     use_stacking = TRUE,
#     stacking_cv_settings = list(method = "repeatedcv", number = 5, repeats = 3),
#     stacking_model_settings = list(enet = NULL, gbm = NULL, treebag = NULL),
#     ...
#   )
#
# Aqui entrenamos manualmente para entender el proceso y evaluar
# que covariables son mas informativas antes del modelo espacial.

# --- 7. Guardar resultados ---------------------------------------------------

saveRDS(results, "output/ml_covariate_models.rds")
cat("\nModelos guardados en output/ml_covariate_models.rds\n")

cat("\nModelado de covariables completado.\n")
cat("Continua con 04_spatial_model.R\n")
