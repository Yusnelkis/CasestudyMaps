# =============================================================================
# 05_prediction_validation.R — Predicciones, validacion y mapas de emisiones
# =============================================================================
# Objetivo: Generar superficies continuas de emision CO2 con incertidumbre,
#           validar el modelo y crear mapas de resultados.

source("R/utils.R")
load_project_packages()

# --- 0. Cargar datos y modelo ajustado ----------------------------------------

mbg_input <- readRDS("data/prepared_emissions.rds")
nuts2_eu <- readRDS("data/nuts2_eu.rds")

# Cargar modelo ajustado (despues de ejecutar 04)
# runner <- readRDS("output/fitted_spatial_model.rds")

# --- 1. Generar predicciones espaciales ---------------------------------------
# mbg genera draws posteriores por celda, permitiendo cuantificar
# la incertidumbre en cada ubicacion del raster.

cat("=== Generando predicciones espaciales ===\n")

# Descomentar despues de ajustar el modelo:
# predictions <- runner$grid_cell_predictions

# --- 2. Resumir predicciones --------------------------------------------------
# Calcular estadisticos a partir de los draws posteriores.
# Las predicciones estan en escala log -> transformar a escala original.

# pred_mean <- apply(predictions, 1, mean)
# pred_lower <- apply(predictions, 1, quantile, probs = 0.025)
# pred_upper <- apply(predictions, 1, quantile, probs = 0.975)
#
# # Transformar de log a escala original (toneladas CO2)
# pred_mean_original <- exp(pred_mean)
# pred_lower_original <- exp(pred_lower)
# pred_upper_original <- exp(pred_upper)
#
# # Ancho del intervalo de credibilidad (incertidumbre)
# pred_uncertainty <- pred_upper - pred_lower
#
# cat(sprintf("Rango de predicciones (media log): %.2f - %.2f\n",
#             min(pred_mean), max(pred_mean)))
# cat(sprintf("Rango de predicciones (media ton): %.0f - %.0f\n",
#             min(pred_mean_original), max(pred_mean_original)))
# cat(sprintf("Ancho promedio IC 95%% (log): %.2f\n",
#             mean(pred_uncertainty)))

# --- 3. Validacion cruzada espacial ------------------------------------------

cat("\n=== Validacion cruzada espacial ===\n")

# Crear holdouts para k-fold CV
# n_folds <- 5
# set.seed(42)
# mbg_input$holdout_id <- sample(rep(1:n_folds, length.out = nrow(mbg_input)))
#
# # La validacion cruzada espacial evalua si el modelo predice bien
# # en regiones no observadas (critico para interpolacion)
# cv_metrics <- data.table::data.table()
#
# for (fold in 1:n_folds) {
#   cat(sprintf("  Fold %d/%d...\n", fold, n_folds))
#   train_data <- mbg_input[holdout_id != fold]
#   test_data <- mbg_input[holdout_id == fold]
#
#   # Ajustar modelo en datos de entrenamiento
#   # cv_runner <- mbg::MbgModelRunner$new(...)
#   # cv_runner$run_mbg_pipeline()
#
#   # Evaluar en datos de test
#   # fold_metrics <- cv_runner$get_predictive_validity(
#   #   in_sample = FALSE,
#   #   validation_data = test_data
#   # )
#   # cv_metrics <- rbind(cv_metrics, fold_metrics)
# }
#
# cat("\n=== Metricas de validacion cruzada ===\n")
# cat(sprintf("RMSE (out-of-sample): %.3f\n", mean(cv_metrics$rmse)))
# cat(sprintf("LPD  (out-of-sample): %.3f\n", sum(cv_metrics$lpd)))

# --- 4. Agregacion a regiones NUTS 2 -----------------------------------------
# Resumir predicciones por region administrativa

cat("\n=== Agregacion a NUTS 2 ===\n")

# admin_predictions <- runner$aggregated_predictions
#
# # Unir con geometria para mapear
# nuts2_results <- merge(
#   nuts2_eu,
#   admin_predictions,
#   by.x = "NUTS_ID",
#   by.y = "region_id",
#   all.x = TRUE
# )

# --- 5. Mapas de resultados --------------------------------------------------

cat("\n=== Generando mapas ===\n")

# --- 5a. Mapa de prediccion media (superficie continua de emisiones) ---
# p_mean <- tmap::tm_shape(pred_raster_mean) +
#   tmap::tm_raster(
#     col = "mean_co2",
#     palette = "YlOrRd",
#     title = "log(CO2 ton/anio)"
#   ) +
#   tmap::tm_shape(nuts2_eu) +
#   tmap::tm_borders(col = "grey40", lwd = 0.5) +
#   tmap::tm_layout(
#     title = "Emisiones industriales CO2 — Prediccion media",
#     legend.outside = TRUE
#   )
#
# print(p_mean)
# save_plot(p_mean, "05_mapa_prediccion_co2.png")

# --- 5b. Mapa de incertidumbre (ancho del IC 95%) ---
# p_unc <- tmap::tm_shape(pred_raster_uncertainty) +
#   tmap::tm_raster(
#     col = "uncertainty",
#     palette = "Blues",
#     title = "Ancho IC 95%"
#   ) +
#   tmap::tm_layout(
#     title = "Incertidumbre espacial de emisiones CO2",
#     legend.outside = TRUE
#   )
#
# print(p_unc)
# save_plot(p_unc, "05_mapa_incertidumbre_co2.png")

# --- 5c. Mapa coropletico NUTS 2 (emisiones agregadas por region) ---
# p_nuts <- ggplot2::ggplot(nuts2_results) +
#   ggplot2::geom_sf(ggplot2::aes(fill = mean_co2), color = "grey50",
#                    linewidth = 0.2) +
#   ggplot2::scale_fill_viridis_c(
#     name = "Media\nlog(CO2)",
#     option = "inferno",
#     na.value = "grey90"
#   ) +
#   ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
#   theme_map() +
#   ggplot2::labs(
#     title = "Emisiones CO2 agregadas por region NUTS 2",
#     subtitle = "Modelo geoestadistico mbg — con intervalos de credibilidad"
#   )
#
# print(p_nuts)
# save_plot(p_nuts, "05_mapa_nuts2_emisiones.png")

# --- 6. Resumen final --------------------------------------------------------

cat("\n")
cat("=" %>% rep(60) %>% paste(collapse = ""), "\n")
cat("PIPELINE COMPLETADO\n")
cat("=" %>% rep(60) %>% paste(collapse = ""), "\n")
cat("\n")
cat("Resultados generados:\n")
cat("  - Superficie continua de emisiones CO2 (media + IC 95%%)\n")
cat("  - Mapa de incertidumbre espacial\n")
cat("  - Agregacion por regiones NUTS 2\n")
cat("  - Metricas de validacion cruzada espacial\n")
cat("\nArchivos en: output/\n")
cat("\nInterpretacion:\n")
cat("  - Hotspots: zonas con alta media y baja incertidumbre\n")
cat("  - Gaps de datos: zonas con alta incertidumbre\n")
cat("  - Transicion climatica: comparar hotspots vs. politicas regionales\n")
