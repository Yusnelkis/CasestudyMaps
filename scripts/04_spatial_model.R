# =============================================================================
# 04_spatial_model.R — Modelo geoestadistico de emisiones CO2
# =============================================================================
# Objetivo: Ajustar un modelo Bayesiano espacial (INLA + SPDE) para modelar
#           la distribucion de emisiones industriales de CO2 en Europa.
#           El modelo captura la autocorrelacion espacial que los modelos ML
#           por si solos no pueden manejar.

source("R/utils.R")
load_project_packages()

# Verificar INLA
if (!requireNamespace("INLA", quietly = TRUE)) {
  stop("INLA no esta instalado. Ejecuta:\n",
       'install.packages("INLA", repos = "https://inla.r-inla-download.org/R/stable")')
}

# --- 0. Cargar datos preparados -----------------------------------------------

mbg_input <- readRDS("data/prepared_emissions.rds")
nuts2_eu <- readRDS("data/nuts2_eu.rds")
id_raster <- readRDS("data/id_raster.rds")
aggregation_table <- readRDS("data/aggregation_table.rds")

cat(sprintf("Datos: %d instalaciones\n", nrow(mbg_input)))
cat(sprintf("ID raster: %d celdas\n", terra::ncell(id_raster)))

# --- 1. Configurar MbgModelRunner --------------------------------------------
# Para datos continuos (log CO2), usamos familia gaussiana.
# mbg espera columnas: x, y, indicator, samplesize, cluster_id

cat("\n=== Configurando MbgModelRunner ===\n")

runner <- mbg::MbgModelRunner$new(
  input_data = mbg_input,
  id_raster = id_raster,

  # Agregacion a NUTS2
  aggregation_table = aggregation_table,

  # Componentes del modelo
  use_covariates = FALSE,    # Sin rasters de covariables (piloto)
  use_gp = TRUE,             # Proceso Gaussiano espacial (SPDE)
  use_admin_effect = FALSE,  # Sin efecto aleatorio por admin
  use_nugget = TRUE,         # Efecto nugget (ruido por observacion)

  # Configuracion del mesh SPDE
  mesh_max_edge = c(1.5, 8.0),   # c(interior, exterior) en grados
  mesh_cutoff = 0.5,              # Distancia minima entre vertices

  # Familia del modelo (gaussiana para log-emisiones)
  inla_family = "gaussian",
  inla_link = "identity",
  inverse_link = "identity",

  # Priors (penalized complexity)
  prior_spde_range = list(threshold = 5, prob_below = 0.05),
  prior_spde_sigma = list(threshold = 2, prob_above = 0.05),
  prior_nugget = list(threshold = 2, prob_above = 0.05),

  verbose = TRUE
)

cat("MbgModelRunner configurado.\n")

# --- 2. Ajustar el modelo ---------------------------------------------------

cat("\n=== Ajustando modelo geoestadistico ===\n")
cat("Esto puede tardar varios minutos para escala europea...\n\n")

runner$run_mbg_pipeline(
  n_samples = 250,
  ui_width = 0.95
)

cat("\nModelo ajustado exitosamente.\n")

# --- 3. Diagnosticos del modelo -----------------------------------------------

cat("\n=== Diagnosticos del modelo ===\n")

# Resumen del modelo INLA
if (!is.null(runner$inla_fitted_model)) {
  cat("\n--- Efectos fijos ---\n")
  print(runner$inla_fitted_model$summary.fixed)

  cat("\n--- Hiperparametros ---\n")
  print(runner$inla_fitted_model$summary.hyperpar)

  # WAIC
  if (!is.null(runner$inla_fitted_model$waic)) {
    cat(sprintf("\nWAIC: %.2f\n", runner$inla_fitted_model$waic$waic))
  }
}

# --- 4. Visualizar predicciones -----------------------------------------------

cat("\n=== Predicciones ===\n")

# Acceder a predicciones por celda
grid_preds <- runner$grid_cell_predictions

if (!is.null(grid_preds)) {
  cat("Predicciones disponibles.\n")
  cat("Componentes:", paste(names(grid_preds), collapse = ", "), "\n")

  # Nombres en mbg v1.2: cell_pred_mean, cell_pred_lower, cell_pred_upper
  mean_raster <- grid_preds$cell_pred_mean
  lower_raster <- grid_preds$cell_pred_lower
  upper_raster <- grid_preds$cell_pred_upper

  if (!is.null(mean_raster) && inherits(mean_raster, "SpatRaster")) {
    cat(sprintf("Rango prediccion media (log): %.2f - %.2f\n",
                min(terra::values(mean_raster), na.rm = TRUE),
                max(terra::values(mean_raster), na.rm = TRUE)))

    terra::writeRaster(mean_raster, "output/04_pred_mean.tif", overwrite = TRUE)
    cat("Raster de prediccion media guardado: output/04_pred_mean.tif\n")

    if (!is.null(upper_raster) && !is.null(lower_raster)) {
      unc_raster <- upper_raster - lower_raster
      terra::writeRaster(unc_raster, "output/04_pred_uncertainty.tif", overwrite = TRUE)
      cat("Raster de incertidumbre guardado: output/04_pred_uncertainty.tif\n")
    }
  }
}

# --- 5. Mapa de prediccion media ---------------------------------------------

if (!is.null(mean_raster) && inherits(mean_raster, "SpatRaster")) {
  # Convertir raster a df para ggplot
  mean_df <- as.data.frame(mean_raster, xy = TRUE, na.rm = TRUE)
  names(mean_df)[3] <- "log_co2"

  p_pred <- ggplot2::ggplot() +
    ggplot2::geom_raster(data = mean_df,
                         ggplot2::aes(x = x, y = y, fill = log_co2)) +
    ggplot2::geom_sf(data = nuts2_eu, fill = NA, color = col_borders,
                     linewidth = 0.15) +
    scale_fill_emissions(name = "log(CO2\nton/anio)") +
    ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
    theme_map() +
    ggplot2::labs(
      title = "Superficie de emisiones CO2 — Prediccion media (mbg)",
      subtitle = "Modelo geoestadistico Bayesiano (INLA + SPDE)",
      caption = "Fuente: E-PRTR | Modelo: mbg"
    )

  print(p_pred)
  save_plot(p_pred, "04_mapa_prediccion_media.png")
}

# --- 6. Mapa de incertidumbre ------------------------------------------------

if (exists("unc_raster")) {
  unc_df <- as.data.frame(unc_raster, xy = TRUE, na.rm = TRUE)
  names(unc_df)[3] <- "uncertainty"

  p_unc <- ggplot2::ggplot() +
    ggplot2::geom_raster(data = unc_df,
                         ggplot2::aes(x = x, y = y, fill = uncertainty)) +
    ggplot2::geom_sf(data = nuts2_eu, fill = NA, color = "grey50",
                     linewidth = 0.15) +
    ggplot2::scale_fill_gradientn(
      colours = c(palette_satellite$cyan_light, palette_satellite$cyan,
                  palette_satellite$blue_river, palette_satellite$navy),
      name = "Ancho\nIC 95%"
    ) +
    ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
    theme_map() +
    ggplot2::labs(
      title = "Incertidumbre espacial de emisiones CO2",
      subtitle = "Ancho del intervalo de credibilidad 95%",
      caption = "Fuente: E-PRTR | Modelo: mbg (INLA + SPDE)"
    )

  print(p_unc)
  save_plot(p_unc, "04_mapa_incertidumbre.png")
}

# --- 7. Guardar modelo -------------------------------------------------------

saveRDS(runner, "output/fitted_spatial_model.rds")
cat("\nModelo guardado en: output/fitted_spatial_model.rds\n")

cat("\nContinua con 05_prediction_validation.R\n")
