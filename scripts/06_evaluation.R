# =============================================================================
# 06_evaluation.R — Evaluacion rigurosa del modelo geoestadistico
# =============================================================================
# Tres niveles de evaluacion:
#   NIVEL 1 — Metricas Bayesianas sin re-fit (rapido)
#   NIVEL 2 — Spatial Block CV con 5 folds (~15 min)
#   NIVEL 3 — Comparacion contra baselines (mean-only, IDW, GLM)

source("R/utils.R")
load_project_packages()

# Paquetes adicionales de evaluacion
library(scoringRules)
library(spdep)
library(blockCV)
library(gstat)

cat("\n")
cat(strrep("=", 70), "\n")
cat("  EVALUACION RIGUROSA DEL MODELO mbg (INLA + SPDE)\n")
cat(strrep("=", 70), "\n\n")

# =============================================================================
# 0. Cargar modelo y datos
# =============================================================================

runner <- readRDS("output/fitted_spatial_model.rds")
mbg_input <- readRDS("data/prepared_emissions.rds")
nuts2_eu <- readRDS("data/nuts2_eu.rds")
id_raster_obj <- readRDS("data/id_raster.rds")
agg_table <- readRDS("data/aggregation_table.rds")

# El SpatRaster se corrompe al deserializar — recargar desde TIF
mean_raster <- terra::rast("output/04_pred_mean.tif")

cat(sprintf("Modelo cargado: %d observaciones\n", nrow(mbg_input)))

# =============================================================================
# NIVEL 1 — Metricas Bayesianas sin re-fit
# =============================================================================

cat("\n")
cat(strrep("-", 70), "\n")
cat("  NIVEL 1 — Diagnosticos Bayesianos (sin re-fit)\n")
cat(strrep("-", 70), "\n\n")

# --- 1.1 Metricas in-sample nativas mbg ---

cat("1.1 Metricas in-sample nativas mbg\n")
is_metrics <- tryCatch({
  runner$get_predictive_validity(in_sample = TRUE, na.rm = TRUE)
}, error = function(e) {
  cat("  Error:", e$message, "\n")
  NULL
})

if (!is.null(is_metrics)) {
  print(is_metrics)
}

# --- 1.2 CPO (Conditional Predictive Ordinate) ---

cat("\n1.2 CPO (LOO-CV aproximado gratis)\n")
cpo_obj <- runner$inla_fitted_model$cpo
cpo_values <- cpo_obj$cpo
cpo_failures <- sum(cpo_obj$failure > 0, na.rm = TRUE)
neg_log_cpo_mean <- mean(-log(cpo_values), na.rm = TRUE)

cat(sprintf("  Media -log(CPO):  %.4f  (menor = mejor)\n", neg_log_cpo_mean))
cat(sprintf("  Fallos CPO:       %d / %d\n", cpo_failures, length(cpo_values)))

# --- 1.3 CRPS + Coverage desde cell_draws ---

cat("\n1.3 CRPS y coverage desde cell_draws\n")
cell_draws <- runner$grid_cell_predictions$cell_draws

# Extraer draws en celdas observadas
obs_cells <- terra::cellFromXY(mean_raster, cbind(mbg_input$x, mbg_input$y))
# Mapear celdas del raster completo a las posiciones en cell_draws (solo celdas no-NA)
non_na_mask <- !is.na(terra::values(mean_raster))
non_na_cell_ids <- which(non_na_mask)
obs_idx <- match(obs_cells, non_na_cell_ids)

valid <- !is.na(obs_idx)
obs_draws <- cell_draws[obs_idx[valid], ]
obs_vals <- mbg_input$indicator[valid]

cat(sprintf("  Observaciones validas: %d / %d\n", sum(valid), nrow(mbg_input)))

# CRPS
crps_values <- scoringRules::crps_sample(y = obs_vals, dat = obs_draws)
mean_crps <- mean(crps_values, na.rm = TRUE)
cat(sprintf("  CRPS medio:       %.4f  (menor = mejor)\n", mean_crps))

# Coverage
lower_q <- apply(obs_draws, 1, quantile, 0.025, na.rm = TRUE)
upper_q <- apply(obs_draws, 1, quantile, 0.975, na.rm = TRUE)
coverage_95 <- mean(obs_vals >= lower_q & obs_vals <= upper_q, na.rm = TRUE)
cat(sprintf("  Coverage 95%%:     %.1f%%  (objetivo ~95%%)\n", 100 * coverage_95))

# --- 1.4 PIT Histogram ---

cat("\n1.4 PIT histogram (calibracion)\n")
pit_values <- sapply(seq_len(nrow(obs_draws)), function(i) {
  mean(obs_draws[i, ] <= obs_vals[i], na.rm = TRUE)
})

# Test de uniformidad (Kolmogorov-Smirnov)
ks_test <- suppressWarnings(ks.test(pit_values, "punif"))
cat(sprintf("  KS test vs uniforme: D=%.4f, p=%.4f\n",
            ks_test$statistic, ks_test$p.value))
cat(sprintf("  (p > 0.05 = PIT uniforme = bien calibrado)\n"))

p_pit <- ggplot2::ggplot(data.frame(pit = pit_values),
    ggplot2::aes(x = pit)) +
  ggplot2::geom_histogram(bins = 20, fill = palette_satellite$blue_river,
                          color = "#FFFFFF", linewidth = 0.2) +
  ggplot2::geom_hline(yintercept = length(pit_values) / 20,
                      color = palette_satellite$magenta,
                      linetype = "dashed", linewidth = 0.8) +
  ggplot2::labs(
    title = "PIT Histogram — Calibracion del modelo",
    subtitle = sprintf("KS test D=%.3f, p=%.3f | %d observaciones",
                       ks_test$statistic, ks_test$p.value, length(pit_values)),
    x = "PIT value",
    y = "Frecuencia",
    caption = "Uniforme = bien calibrado | linea roja = esperado si es uniforme"
  ) +
  theme_satellite()

save_plot(p_pit, "06_pit_histogram.png")

# --- 1.5 Moran's I sobre residuos ---

cat("\n1.5 Moran's I sobre residuos\n")
pred_at_obs <- terra::extract(mean_raster, cbind(mbg_input$x, mbg_input$y))[, 1]
residuals <- mbg_input$indicator - pred_at_obs
valid_res <- !is.na(residuals)

coords <- cbind(mbg_input$x[valid_res], mbg_input$y[valid_res])
res_vals <- residuals[valid_res]

nb <- spdep::knn2nb(spdep::knearneigh(coords, k = 6))
w_list <- spdep::nb2listw(nb, style = "W")
morans <- spdep::moran.test(res_vals, w_list)

cat(sprintf("  Moran's I:     %.4f\n", as.numeric(morans$estimate[1])))
cat(sprintf("  p-value:       %.4f\n", morans$p.value))
cat(sprintf("  (p > 0.05 = GP capturo la autocorrelacion espacial)\n"))

# Mapa de residuos
res_df <- data.frame(
  x = coords[, 1], y = coords[, 2], residual = res_vals
)

p_res <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = nuts2_eu, fill = col_land, color = col_borders,
                   linewidth = 0.15) +
  ggplot2::geom_point(data = res_df,
    ggplot2::aes(x = x, y = y, color = residual),
    alpha = 0.6, size = 1.2
  ) +
  ggplot2::scale_color_gradient2(
    low = palette_satellite$blue_river,
    mid = "#F5F2ED",
    high = palette_satellite$magenta,
    midpoint = 0,
    name = "Residuo"
  ) +
  ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
  theme_map() +
  ggplot2::labs(
    title = "Residuos del modelo geoestadistico",
    subtitle = sprintf("Moran's I = %.3f (p = %.3f)",
                       as.numeric(morans$estimate[1]), morans$p.value),
    caption = "Patron aleatorio = GP capturo la autocorrelacion"
  )

save_plot(p_res, "06_moran_residuos.png")

# =============================================================================
# NIVEL 2 — Spatial Block CV
# =============================================================================

cat("\n")
cat(strrep("-", 70), "\n")
cat("  NIVEL 2 — Spatial Block CV (5 folds, 300 km)\n")
cat(strrep("-", 70), "\n\n")

# --- 2.1 Crear bloques espaciales ---

cat("2.1 Creando bloques espaciales\n")
facilities_sf <- sf::st_as_sf(
  data.frame(mbg_input), coords = c("x", "y"), crs = 4326
)

set.seed(42)
blocks <- tryCatch({
  blockCV::cv_spatial(
    x = facilities_sf,
    size = 300000,  # 300 km en metros (se proyecta internamente)
    k = 5,
    selection = "random",
    progress = FALSE,
    plot = FALSE,
    report = FALSE
  )
}, error = function(e) {
  cat("  Error blockCV:", e$message, "\n")
  NULL
})

if (!is.null(blocks)) {
  mbg_input_cv <- data.table::copy(mbg_input)
  mbg_input_cv[, holdout_id := blocks$folds_ids]

  cat("  Distribucion de folds:\n")
  print(table(mbg_input_cv$holdout_id))

  # --- 2.2 Re-ajustar 5 modelos ---

  cat("\n2.2 Ajustando 5 modelos mbg (un fold a la vez)\n")
  cv_results <- list()

  for (h in seq_len(5)) {
    cat(sprintf("  Fold %d/5...", h))
    train <- mbg_input_cv[holdout_id != h]
    test  <- mbg_input_cv[holdout_id == h]

    cv_model <- tryCatch({
      r <- mbg::MbgModelRunner$new(
        input_data = train,
        id_raster = id_raster_obj,
        aggregation_table = agg_table,
        use_covariates = FALSE,
        use_gp = TRUE,
        use_nugget = TRUE,
        mesh_max_edge = c(1.5, 8.0),
        mesh_cutoff = 0.5,
        inla_family = "gaussian",
        inla_link = "identity",
        inverse_link = "identity",
        prior_spde_range = list(threshold = 5, prob_below = 0.05),
        prior_spde_sigma = list(threshold = 2, prob_above = 0.05),
        prior_nugget = list(threshold = 2, prob_above = 0.05),
        verbose = FALSE
      )
      r$run_mbg_pipeline(n_samples = 250)
      r
    }, error = function(e) {
      cat(" ERROR:", e$message, "\n")
      NULL
    })

    if (!is.null(cv_model)) {
      fold_metrics <- tryCatch({
        m <- cv_model$get_predictive_validity(
          in_sample = FALSE,
          validation_data = test,
          na.rm = TRUE
        )
        m[, fold := h]
        m
      }, error = function(e) {
        cat(" VALIDATION ERROR:", e$message, "\n")
        NULL
      })
      if (!is.null(fold_metrics)) {
        cv_results[[h]] <- fold_metrics
        cat(sprintf(" RMSE_oos=%.3f\n", fold_metrics$rmse_oos))
      }
    }
  }

  # --- 2.3 Agregacion ---

  if (length(cv_results) > 0) {
    cv_dt <- data.table::rbindlist(cv_results, fill = TRUE)
    cat("\n=== Resumen CV espacial ===\n")
    print(cv_dt)

    cv_summary <- data.table::data.table(
      rmse_oos_mean = mean(cv_dt$rmse_oos, na.rm = TRUE),
      rmse_oos_sd   = sd(cv_dt$rmse_oos, na.rm = TRUE),
      lpd_oos_sum   = sum(cv_dt$lpd_oos, na.rm = TRUE)
    )
    cat("\n=== Metricas agregadas ===\n")
    print(cv_summary)
  }
} else {
  cv_dt <- NULL
  cv_summary <- NULL
}

# =============================================================================
# NIVEL 3 — Baselines
# =============================================================================

cat("\n")
cat(strrep("-", 70), "\n")
cat("  NIVEL 3 — Comparacion contra baselines\n")
cat(strrep("-", 70), "\n\n")

if (!is.null(blocks)) {
  baseline_results <- list()

  for (h in seq_len(5)) {
    cat(sprintf("  Fold %d/5:\n", h))
    train <- mbg_input_cv[holdout_id != h]
    test  <- mbg_input_cv[holdout_id == h]

    # Baseline 1: Media constante
    pred_mean <- mean(train$indicator)
    rmse_mean <- sqrt(mean((test$indicator - pred_mean)^2))
    cat(sprintf("    Mean-only RMSE:  %.3f\n", rmse_mean))

    # Baseline 2: GLM (lineal en coordenadas)
    glm_fit <- stats::glm(indicator ~ x + y, data = train,
                          family = gaussian())
    pred_glm <- predict(glm_fit, newdata = test)
    rmse_glm <- sqrt(mean((test$indicator - pred_glm)^2))
    cat(sprintf("    GLM RMSE:        %.3f\n", rmse_glm))

    # Baseline 3: IDW (Inverse Distance Weighting)
    rmse_idw <- tryCatch({
      train_sf <- sf::st_as_sf(data.frame(train),
                               coords = c("x", "y"), crs = 4326)
      test_sf <- sf::st_as_sf(data.frame(test),
                              coords = c("x", "y"), crs = 4326)
      idw_pred <- suppressWarnings(
        gstat::idw(indicator ~ 1, train_sf, newdata = test_sf,
                   idp = 2, debug.level = 0)
      )
      sqrt(mean((test$indicator - idw_pred$var1.pred)^2, na.rm = TRUE))
    }, error = function(e) NA)
    cat(sprintf("    IDW RMSE:        %.3f\n", rmse_idw))

    baseline_results[[h]] <- data.table::data.table(
      fold = h,
      mean_only = rmse_mean,
      glm = rmse_glm,
      idw = rmse_idw
    )
  }

  baseline_dt <- data.table::rbindlist(baseline_results)

  # Agregado
  baseline_summary <- data.table::data.table(
    method = c("mean_only", "glm", "idw", "mbg_spde"),
    rmse_oos_mean = c(
      mean(baseline_dt$mean_only, na.rm = TRUE),
      mean(baseline_dt$glm, na.rm = TRUE),
      mean(baseline_dt$idw, na.rm = TRUE),
      if (!is.null(cv_summary)) cv_summary$rmse_oos_mean else NA_real_
    )
  )
  baseline_summary[, improvement_vs_mean :=
    (1 - rmse_oos_mean / baseline_summary$rmse_oos_mean[1]) * 100]

  cat("\n=== Comparacion de modelos ===\n")
  print(baseline_summary)

  # Barplot comparativo
  baseline_summary[, method := factor(method,
    levels = c("mean_only", "glm", "idw", "mbg_spde"))]

  p_compare <- ggplot2::ggplot(baseline_summary,
      ggplot2::aes(x = method, y = rmse_oos_mean, fill = method)) +
    ggplot2::geom_col(width = 0.65, show.legend = FALSE) +
    ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%.3f", rmse_oos_mean)),
      vjust = -0.5, size = 4, color = col_text
    ) +
    ggplot2::scale_fill_manual(values = c(
      "mean_only" = palette_satellite$khaki,
      "glm" = palette_satellite$cyan_dark,
      "idw" = palette_satellite$green_mid,
      "mbg_spde" = palette_satellite$magenta
    )) +
    ggplot2::labs(
      title = "Comparacion de modelos — Spatial Block CV",
      subtitle = "RMSE out-of-sample (5 folds, bloques de 300 km)",
      x = NULL,
      y = "RMSE out-of-sample",
      caption = "Menor = mejor | mbg+SPDE en magenta"
    ) +
    theme_satellite() +
    ggplot2::expand_limits(y = max(baseline_summary$rmse_oos_mean,
                                   na.rm = TRUE) * 1.15)

  save_plot(p_compare, "06_baselines_comparison.png")
} else {
  baseline_summary <- NULL
}

# =============================================================================
# REPORTE FINAL
# =============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("  RESUMEN DE EVALUACION\n")
cat(strrep("=", 70), "\n\n")

if (!is.null(is_metrics)) {
  cat(sprintf("In-sample (nativo mbg):\n"))
  cat(sprintf("  RMSE_is:         %.4f\n", is_metrics$rmse_is))
  cat(sprintf("  LPD_is:          %.2f\n", is_metrics$lpd_is))
  cat(sprintf("  WAIC_is:         %.2f\n", is_metrics$waic_is))
}

cat(sprintf("\nDiagnosticos Bayesianos:\n"))
cat(sprintf("  -log(CPO) medio: %.4f\n", neg_log_cpo_mean))
cat(sprintf("  CRPS medio:      %.4f\n", mean_crps))
cat(sprintf("  Coverage 95%%:    %.1f%% (objetivo ~95%%)\n", 100 * coverage_95))
cat(sprintf("  Moran's I:       %.4f (p=%.4f)\n",
            as.numeric(morans$estimate[1]), morans$p.value))

if (!is.null(cv_summary)) {
  cat(sprintf("\nSpatial Block CV:\n"))
  cat(sprintf("  RMSE_oos:        %.4f (sd=%.4f)\n",
              cv_summary$rmse_oos_mean, cv_summary$rmse_oos_sd))
  cat(sprintf("  LPD_oos total:   %.2f\n", cv_summary$lpd_oos_sum))
}

if (!is.null(baseline_summary)) {
  cat(sprintf("\nComparacion vs baselines (RMSE_oos):\n"))
  for (i in seq_len(nrow(baseline_summary))) {
    cat(sprintf("  %-10s %.4f  (%+.1f%% vs mean-only)\n",
                baseline_summary$method[i],
                baseline_summary$rmse_oos_mean[i],
                baseline_summary$improvement_vs_mean[i]))
  }
}

# --- Guardar reporte ---

report <- list(
  in_sample = is_metrics,
  cv_spatial = cv_summary,
  cv_detail = if (exists("cv_dt")) cv_dt else NULL,
  baselines = baseline_summary,
  diagnostics = list(
    cpo_neg_log_mean = neg_log_cpo_mean,
    cpo_failures = cpo_failures,
    crps_mean = mean_crps,
    coverage_95 = coverage_95,
    morans_i = as.numeric(morans$estimate[1]),
    morans_p = morans$p.value,
    pit_ks_stat = as.numeric(ks_test$statistic),
    pit_ks_p = ks_test$p.value
  )
)

saveRDS(report, "output/06_evaluation_report.rds")
cat("\nReporte guardado: output/06_evaluation_report.rds\n")

cat("\nGraficos generados:\n")
cat("  output/06_pit_histogram.png\n")
cat("  output/06_moran_residuos.png\n")
cat("  output/06_baselines_comparison.png\n")

cat("\nEvaluacion completada.\n")
