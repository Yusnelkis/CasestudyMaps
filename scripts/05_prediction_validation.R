# =============================================================================
# 05_prediction_validation.R — Predicciones, validacion y mapas de emisiones
# =============================================================================
# Objetivo: Generar mapas finales de prediccion, validar el modelo y
#           agregar resultados a regiones NUTS2.

source("R/utils.R")
load_project_packages()

# --- 0. Cargar datos y modelo ajustado ----------------------------------------

mbg_input <- readRDS("data/prepared_emissions.rds")
nuts2_eu <- readRDS("data/nuts2_eu.rds")

# Cargar rasters de prediccion (guardados como GeoTIFF)
mean_raster <- if (file.exists("output/04_pred_mean.tif"))
  terra::rast("output/04_pred_mean.tif") else NULL
unc_raster <- if (file.exists("output/04_pred_uncertainty.tif"))
  terra::rast("output/04_pred_uncertainty.tif") else NULL

cat(sprintf("Datos: %d instalaciones\n", nrow(mbg_input)))

# --- 1. Predicciones agregadas a NUTS2 ----------------------------------------

cat("\n=== Agregacion a NUTS 2 ===\n")

# Intentar cargar predicciones agregadas del modelo
runner <- tryCatch(readRDS("output/fitted_spatial_model.rds"), error = function(e) NULL)
admin_preds <- if (!is.null(runner)) runner$aggregated_predictions else NULL

if (!is.null(admin_preds) && length(admin_preds) > 0) {
  # Inspeccionar estructura
  cat("Predicciones agregadas disponibles.\n")

  # Si es lista de data.tables (por nivel de agregacion)
  if (is.list(admin_preds) && !is.data.frame(admin_preds)) {
    pred_dt <- admin_preds[[1]]
  } else {
    pred_dt <- admin_preds
  }

  if (!is.null(pred_dt) && nrow(pred_dt) > 0) {
    cat(sprintf("Regiones con prediccion: %d\n", nrow(pred_dt)))
    print(head(pred_dt))

    # Unir con geometria para mapear
    nuts2_results <- merge(
      nuts2_eu,
      pred_dt,
      by.x = "NUTS_ID",
      by.y = names(pred_dt)[1],  # Primera columna = ID del poligono
      all.x = TRUE
    )

    # Mapa coropletico NUTS2
    # Buscar columna de media
    mean_col <- intersect(c("mean", "median", "estimate"), names(pred_dt))
    if (length(mean_col) > 0) {
      mean_col <- mean_col[1]

      p_nuts <- ggplot2::ggplot(nuts2_results) +
        ggplot2::geom_sf(
          ggplot2::aes(fill = .data[[mean_col]]),
          color = col_borders, linewidth = 0.15
        ) +
        scale_fill_emissions(
          name = "Media\nlog(CO2)",
          na.value = "#E8E6E0"
        ) +
        ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
        theme_map() +
        ggplot2::labs(
          title = "Emisiones CO2 por NUTS 2 — Estimaciones del modelo mbg",
          subtitle = "Predicciones agregadas con incertidumbre Bayesiana",
          caption = "Fuente: E-PRTR | Modelo: mbg (INLA + SPDE)"
        )

      print(p_nuts)
      save_plot(p_nuts, "05_mapa_nuts2_modelo.png")
    }
  }
} else {
  cat("No hay predicciones agregadas disponibles.\n")
}

# --- 2. Predicciones por celda ------------------------------------------------

cat("\n=== Predicciones por celda ===\n")

# Usar rasters cargados desde GeoTIFF (evita problema de serialization de SpatRaster)

if (!is.null(mean_raster)) {

  # Mapa de prediccion media
  mean_df <- as.data.frame(mean_raster, xy = TRUE, na.rm = TRUE)
  names(mean_df)[3] <- "log_co2"

  p_surface <- ggplot2::ggplot() +
    ggplot2::geom_raster(data = mean_df,
                         ggplot2::aes(x = x, y = y, fill = log_co2)) +
    ggplot2::geom_sf(data = nuts2_eu, fill = NA, color = "white",
                     linewidth = 0.1) +
    scale_fill_emissions(name = "log(CO2\nton/anio)") +
    ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
    theme_map_dark() +
    ggplot2::labs(
      title = "Superficie de emisiones CO2 en Europa",
      subtitle = "Interpolacion geoestadistica Bayesiana (mbg)",
      caption = "Fuente: E-PRTR | Modelo: INLA + SPDE"
    )

  print(p_surface)
  save_plot(p_surface, "05_superficie_emisiones.png")

  # Mapa de incertidumbre
  if (!is.null(unc_raster)) {
    unc_df <- as.data.frame(unc_raster, xy = TRUE, na.rm = TRUE)
    names(unc_df)[3] <- "uncertainty"

    p_unc <- ggplot2::ggplot() +
      ggplot2::geom_raster(data = unc_df,
                           ggplot2::aes(x = x, y = y, fill = uncertainty)) +
      ggplot2::geom_sf(data = nuts2_eu, fill = NA, color = "white",
                       linewidth = 0.1) +
      ggplot2::scale_fill_gradientn(
        colours = c(palette_satellite$cyan_light, palette_satellite$cyan,
                    palette_satellite$blue_river, palette_satellite$navy),
        name = "Ancho\nIC 95%"
      ) +
      ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
      theme_map_dark() +
      ggplot2::labs(
        title = "Incertidumbre en la prediccion de emisiones CO2",
        subtitle = "Ancho del intervalo de credibilidad 95%",
        caption = "Fuente: E-PRTR | Modelo: mbg (INLA + SPDE)"
      )

    print(p_unc)
    save_plot(p_unc, "05_mapa_incertidumbre.png")
  }
}

# --- 3. Validacion in-sample -------------------------------------------------

cat("\n=== Validacion in-sample ===\n")

# Comparar predicciones vs. observaciones
if (!is.null(mean_raster)) {
  # Extraer prediccion media en puntos observados
  obs_coords <- cbind(mbg_input$x, mbg_input$y)
  pred_at_obs <- terra::extract(mean_raster, obs_coords)[, 1]

  valid_idx <- !is.na(pred_at_obs)
  observed <- mbg_input$indicator[valid_idx]
  predicted <- pred_at_obs[valid_idx]

  rmse <- sqrt(mean((observed - predicted)^2))
  cor_val <- cor(observed, predicted)
  mae <- mean(abs(observed - predicted))

  cat(sprintf("  RMSE:        %.3f\n", rmse))
  cat(sprintf("  MAE:         %.3f\n", mae))
  cat(sprintf("  Correlacion: %.3f\n", cor_val))
  cat(sprintf("  N validos:   %d / %d\n", sum(valid_idx), length(valid_idx)))

  # Scatterplot observado vs predicho
  val_df <- data.frame(observed = observed, predicted = predicted)

  p_scatter <- ggplot2::ggplot(val_df,
      ggplot2::aes(x = observed, y = predicted)) +
    ggplot2::geom_point(alpha = 0.3, color = palette_satellite$blue_river,
                        size = 1.5) +
    ggplot2::geom_abline(slope = 1, intercept = 0,
                         color = palette_satellite$magenta,
                         linetype = "dashed", linewidth = 0.8) +
    ggplot2::labs(
      title = "Validacion in-sample: Observado vs. Predicho",
      subtitle = sprintf("RMSE = %.3f | r = %.3f | n = %d",
                         rmse, cor_val, sum(valid_idx)),
      x = "log(CO2) observado",
      y = "log(CO2) predicho",
      caption = "Linea roja = 1:1 (prediccion perfecta)"
    ) +
    theme_satellite()

  print(p_scatter)
  save_plot(p_scatter, "05_validacion_scatter.png")
}

# --- 4. Resumen final --------------------------------------------------------

cat("\n")
cat(strrep("=", 60), "\n")
cat("PIPELINE COMPLETADO\n")
cat(strrep("=", 60), "\n\n")

cat("Graficos generados en output/:\n")
output_files <- list.files("output", pattern = "^0[45]_.*\\.png$")
for (f in output_files) {
  cat(sprintf("  %s\n", f))
}

cat("\nInterpretacion:\n")
cat("  - Hotspots: zonas con alta media y baja incertidumbre\n")
cat("  - Gaps de datos: zonas con alta incertidumbre\n")
cat("  - Transicion climatica: comparar hotspots vs. politicas regionales\n")
cat("  - Autocorrelacion: el rango del GP indica la distancia de influencia\n")
