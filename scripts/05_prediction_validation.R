# =============================================================================
# 05_prediction_validation.R — Predicciones, validacion y mapas
# =============================================================================
# Objetivo: Generar predicciones espaciales con incertidumbre, validar el
#           modelo y crear mapas de resultados.

source("R/utils.R")
load_project_packages()

# --- 0. Cargar modelo ajustado (ejecutar script 04 primero) ------------------

# runner <- readRDS("output/fitted_runner.rds")
# O re-ejecutar 04_spatial_model.R

# --- 1. Generar predicciones espaciales ---------------------------------------
# mbg genera 250 draws posteriores por pixel, permitiendo cuantificar
# la incertidumbre en cada ubicacion.

cat("=== Generando predicciones espaciales ===\n")
cat("(250 draws posteriores por pixel)\n")

# predictions <- runner$predict()

# --- 2. Resumir predicciones -------------------------------------------------
# Calcular estadisticos a partir de los draws posteriores

# pred_summary <- data.frame(
#   mean   = apply(predictions, 1, mean),
#   median = apply(predictions, 1, median),
#   lower  = apply(predictions, 1, quantile, probs = 0.025),
#   upper  = apply(predictions, 1, quantile, probs = 0.975)
# )
#
# cat("Rango de predicciones (media):",
#     round(range(pred_summary$mean), 3), "\n")
# cat("Ancho promedio del IC 95%:",
#     round(mean(pred_summary$upper - pred_summary$lower), 3), "\n")

# --- 3. Validacion cruzada espacial ------------------------------------------

cat("\n=== Validacion cruzada ===\n")

# cv_results <- runner$cross_validate(
#   n_folds = 5
# )
#
# cat("RMSE:", round(cv_results$rmse, 4), "\n")
# cat("LPD (Log Predictive Density):", round(cv_results$lpd, 4), "\n")

# --- 4. Agregacion a regiones administrativas ---------------------------------
# Resumir las predicciones raster a poligonos administrativos,
# ponderando por poblacion si se dispone de un raster de poblacion.

# admin_estimates <- mbg::aggregate_raster_to_polygon(
#   predictions = predictions,
#   shapefile = admin_boundaries,
#   id_raster = id_raster
#   # population_raster = pop_raster  # Opcional: ponderacion por poblacion
# )

# --- 5. Visualizacion de resultados ------------------------------------------

# Mapa de prediccion media
# p_mean <- tmap::tm_shape(pred_raster) +
#   tmap::tm_raster(
#     col = "mean",
#     palette = "YlOrRd",
#     title = "Prevalencia estimada"
#   ) +
#   tmap::tm_shape(admin_boundaries) +
#   tmap::tm_borders(col = "black") +
#   tmap::tm_layout(title = "Prediccion media - mbg")
#
# print(p_mean)
# save_plot(p_mean, "05_mapa_prediccion_media.png")

# Mapa de incertidumbre (ancho del IC 95%)
# p_uncertainty <- tmap::tm_shape(pred_raster) +
#   tmap::tm_raster(
#     col = "width_ci",
#     palette = "Blues",
#     title = "Ancho IC 95%"
#   ) +
#   tmap::tm_layout(title = "Incertidumbre espacial")
#
# print(p_uncertainty)
# save_plot(p_uncertainty, "05_mapa_incertidumbre.png")

cat("\nPipeline completo.\n")
cat("Resultados disponibles en la carpeta output/\n")
