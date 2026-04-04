# =============================================================================
# 01_explore_data.R — Fase exploratoria: Emisiones industriales CO2 en Europa
# =============================================================================
# Pregunta guia: Como se distribuyen espacialmente las emisiones industriales
#                de CO2 en Europa y que patrones revela?
#
# Tres bloques de analisis:
#   A. Snapshot actual — Mapa de emision, distribucion, top emisores
#   B. Tendencia temporal — Evolucion por region NUTS2 (2007-2024)
#   C. Perfil por sector — Composicion industrial por zona geografica

source("R/utils.R")
load_project_packages()

# =============================================================================
# CARGA DE DATOS
# =============================================================================

co2_data <- load_eprtr_co2()
co2_data[, totalQuantityTon := totalQuantityKg / 1000]

# NUTS boundaries
nuts0 <- load_nuts(level = 0, path = "data/nuts/NUTS_RG_01M_2021_0_4326.geojson")
nuts2 <- load_nuts(level = 2, path = "data/nuts/NUTS_RG_01M_2021_2_4326.geojson")

# Filtrar a Europa continental
centroids <- sf::st_coordinates(suppressWarnings(sf::st_centroid(nuts2)))
nuts2_eu <- nuts2[centroids[, 1] >= -12 & centroids[, 1] <= 45 &
                  centroids[, 2] >= 34 & centroids[, 2] <= 72, ]

# Ultimo anio disponible
latest_year <- max(co2_data$reportingYear)
latest <- co2_data[reportingYear == latest_year]
cat(sprintf("\nAnio mas reciente: %d | %d instalaciones | %s ton CO2\n",
            latest_year, nrow(latest),
            format(sum(latest$totalQuantityTon), big.mark = ",")))

# Primer anio con buena cobertura (usamos 2017+ por cambio de reporte)
first_year <- 2017

# =============================================================================
# A. SNAPSHOT ACTUAL — Distribucion espacial de emisiones
# =============================================================================

cat("\n")
cat("===================================================================\n")
cat(sprintf("  A. SNAPSHOT ACTUAL — Emisiones CO2 (%d)\n", latest_year))
cat("===================================================================\n\n")

# --- A1. Resumen estadistico ------------------------------------------------

cat("=== Resumen de emisiones CO2 (toneladas/anio) ===\n")
summary(latest$totalQuantityTon)

cat(sprintf("\nPercentiles clave:\n"))
cat(sprintf("  P10: %s ton\n", format(quantile(latest$totalQuantityTon, 0.10), big.mark = ",")))
cat(sprintf("  P50: %s ton\n", format(quantile(latest$totalQuantityTon, 0.50), big.mark = ",")))
cat(sprintf("  P90: %s ton\n", format(quantile(latest$totalQuantityTon, 0.90), big.mark = ",")))
cat(sprintf("  P99: %s ton\n", format(quantile(latest$totalQuantityTon, 0.99), big.mark = ",")))

# --- A2. Histograma en escala log --------------------------------------------

p_hist <- ggplot2::ggplot(latest, ggplot2::aes(x = log10(totalQuantityTon))) +
  ggplot2::geom_histogram(bins = 50, fill = palette_satellite$blue_river,
                          color = "#FFFFFF", linewidth = 0.2) +
  ggplot2::geom_vline(
    xintercept = log10(median(latest$totalQuantityTon)),
    color = palette_satellite$magenta, linetype = "dashed", linewidth = 0.8
  ) +
  ggplot2::annotate("text",
    x = log10(median(latest$totalQuantityTon)) + 0.15,
    y = Inf, vjust = 2, hjust = 0,
    label = sprintf("Mediana: %s ton",
                    format(round(median(latest$totalQuantityTon)), big.mark = ",")),
    color = palette_satellite$magenta, size = 3.5
  ) +
  ggplot2::labs(
    title = "Distribucion de emisiones industriales de CO2",
    subtitle = sprintf("Escala log10 — %d instalaciones en %d",
                       nrow(latest), latest_year),
    x = "log10(CO2 toneladas/anio)",
    y = "Numero de instalaciones",
    caption = "Fuente: EEA DiscoData API — E-PRTR"
  ) +
  theme_satellite()

print(p_hist)
save_plot(p_hist, "01_histograma_emisiones.png")

# --- A3. Mapa de emisiones (version clara) -----------------------------------

co2_sf <- eprtr_to_sf(latest)

p_map <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = nuts0, fill = col_land, color = col_borders,
                   linewidth = 0.3) +
  ggplot2::geom_sf(
    data = co2_sf,
    ggplot2::aes(color = log10(totalQuantityTon),
                 size = log10(totalQuantityTon)),
    alpha = 0.6
  ) +
  scale_color_emissions(name = "log10(CO2\nton/anio)") +
  ggplot2::scale_size_continuous(range = c(0.3, 3), guide = "none") +
  ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
  theme_map() +
  ggplot2::labs(
    title = sprintf("Emisiones industriales de CO2 en Europa (%d)", latest_year),
    subtitle = sprintf("%d instalaciones — Fuente: E-PRTR",  nrow(latest)),
    caption = "Paleta inspirada en imagen satelital falso color (IR cercano)"
  )

print(p_map)
save_plot(p_map, "01_mapa_emisiones_claro.png")

# --- A4. Mapa de emisiones (version oscura — estilo satelital) ----------------

p_map_dark <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = nuts0, fill = "#142040",
                   color = palette_satellite$cyan_dark, linewidth = 0.2) +
  ggplot2::geom_sf(
    data = co2_sf,
    ggplot2::aes(color = log10(totalQuantityTon),
                 size = log10(totalQuantityTon)),
    alpha = 0.7
  ) +
  scale_color_emissions(name = "log10(CO2\nton/anio)", palette = "warm") +
  ggplot2::scale_size_continuous(range = c(0.3, 3), guide = "none") +
  ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
  theme_map_dark() +
  ggplot2::labs(
    title = sprintf("Emisiones industriales de CO2 en Europa (%d)", latest_year),
    subtitle = "Fuente: E-PRTR — European Industrial Emissions Portal"
  )

print(p_map_dark)
save_plot(p_map_dark, "01_mapa_emisiones_dark.png")

# --- A5. Mapa coropletico NUTS2 — emisiones agregadas por region -------------

nuts2_emissions <- latest[!is.na(nuts2), .(
  total_co2_ton = sum(totalQuantityTon),
  n_facilities = .N,
  mean_co2_ton = mean(totalQuantityTon)
), by = nuts2]

nuts2_map <- merge(nuts2_eu, nuts2_emissions,
                   by.x = "NUTS_ID", by.y = "nuts2", all.x = TRUE)

p_choropleth <- ggplot2::ggplot(nuts2_map) +
  ggplot2::geom_sf(
    ggplot2::aes(fill = log10(total_co2_ton)),
    color = "grey60", linewidth = 0.15
  ) +
  scale_fill_emissions(
    name = "log10(CO2\ntotal ton)",
    na.value = "#E8E6E0"
  ) +
  ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
  theme_map() +
  ggplot2::labs(
    title = sprintf("Emisiones CO2 por region NUTS 2 (%d)", latest_year),
    subtitle = "Total de emisiones industriales agregadas por region",
    caption = "Fuente: E-PRTR | Regiones sin datos en gris"
  )

print(p_choropleth)
save_plot(p_choropleth, "01_mapa_nuts2_emisiones.png")

# --- A6. Top emisores --------------------------------------------------------

cat("\n=== Top 20 instalaciones por emision de CO2 ===\n")
top_emitters <- latest[order(-totalQuantityTon), .(
  facilityName, countryCode, mainActivity,
  co2_kton = round(totalQuantityTon / 1000, 1)
)][1:20]
print(top_emitters)

# Top emisores — barplot
top20 <- latest[order(-totalQuantityTon)][1:20]
top20[, label := paste0(substr(facilityName, 1, 25), " (", countryCode, ")")]
# Hacer labels unicos (puede haber duplicados por truncar nombres)
top20[, label := make.unique(label, sep = " #")]
top20[, label := factor(label, levels = rev(label))]

p_top <- ggplot2::ggplot(top20,
    ggplot2::aes(x = label, y = totalQuantityTon / 1e6)) +
  ggplot2::geom_col(fill = palette_satellite$magenta, width = 0.7) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = sprintf("Top 20 instalaciones emisoras de CO2 (%d)", latest_year),
    x = NULL,
    y = "Millones de toneladas CO2/anio",
    caption = "Fuente: E-PRTR"
  ) +
  theme_satellite() +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 8))

print(p_top)
save_plot(p_top, "01_top20_emisores.png")

# --- A7. Emisiones por pais (barplot) ----------------------------------------

country_summary <- latest[, .(
  total_co2_Mton = sum(totalQuantityTon) / 1e6,
  n_facilities = .N
), by = countryCode][order(-total_co2_Mton)]

country_summary[, countryCode := factor(countryCode,
                                        levels = rev(countryCode))]

p_country <- ggplot2::ggplot(
    country_summary[1:min(20, .N)],
    ggplot2::aes(x = countryCode, y = total_co2_Mton)) +
  ggplot2::geom_col(fill = palette_satellite$blue_river, width = 0.7) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = sprintf("Emisiones industriales CO2 por pais (%d)", latest_year),
    x = NULL,
    y = "Millones de toneladas CO2/anio",
    caption = "Fuente: E-PRTR"
  ) +
  theme_satellite()

print(p_country)
save_plot(p_country, "01_emisiones_por_pais.png")


# =============================================================================
# B. TENDENCIA TEMPORAL — Evolucion de emisiones por region (2017-2024)
# =============================================================================

cat("\n")
cat("===================================================================\n")
cat(sprintf("  B. TENDENCIA TEMPORAL — Evolucion %d-%d\n", first_year, latest_year))
cat("===================================================================\n\n")

# Filtrar periodo con reporte homogeneo
co2_temporal <- co2_data[reportingYear >= first_year]

# --- B1. Tendencia agregada europea -----------------------------------------

trend_eu <- co2_temporal[, .(
  total_co2_Mton = sum(totalQuantityTon) / 1e6,
  n_facilities = .N
), by = reportingYear][order(reportingYear)]

cat("=== Tendencia europea ===\n")
print(trend_eu)

# Calcular cambio porcentual respecto al primer anio
base_value <- trend_eu[reportingYear == first_year, total_co2_Mton]
trend_eu[, change_pct := (total_co2_Mton / base_value - 1) * 100]

p_trend_eu <- ggplot2::ggplot(trend_eu,
    ggplot2::aes(x = reportingYear, y = total_co2_Mton)) +
  ggplot2::geom_line(color = palette_satellite$blue_river, linewidth = 1.2) +
  ggplot2::geom_point(color = palette_satellite$navy, size = 3) +
  ggplot2::geom_text(
    ggplot2::aes(label = sprintf("%.0f Mt", total_co2_Mton)),
    vjust = -1.2, size = 3, color = col_text_light
  ) +
  ggplot2::labs(
    title = "Tendencia de emisiones industriales CO2 en Europa",
    subtitle = sprintf("Total agregado %d-%d — Cambio: %+.1f%%",
                       first_year, latest_year,
                       trend_eu[reportingYear == latest_year, change_pct]),
    x = "Anio de reporte",
    y = "Millones de toneladas CO2/anio",
    caption = "Fuente: E-PRTR"
  ) +
  theme_satellite()

print(p_trend_eu)
save_plot(p_trend_eu, "01_tendencia_europea.png")

# --- B2. Tendencia por pais (top 10 emisores) --------------------------------

top_countries <- latest[, .(total = sum(totalQuantityTon)),
                        by = countryCode][order(-total)][1:10, countryCode]

trend_country <- co2_temporal[countryCode %in% top_countries, .(
  total_co2_Mton = sum(totalQuantityTon) / 1e6
), by = .(reportingYear, countryCode)]

p_trend_country <- ggplot2::ggplot(trend_country,
    ggplot2::aes(x = reportingYear, y = total_co2_Mton,
                 color = countryCode)) +
  ggplot2::geom_line(linewidth = 0.9, alpha = 0.8) +
  ggplot2::geom_point(size = 1.5) +
  ggplot2::scale_color_manual(values = pal_sectors, name = "Pais") +
  ggplot2::labs(
    title = "Tendencia de emisiones CO2 por pais (top 10)",
    subtitle = sprintf("%d-%d", first_year, latest_year),
    x = "Anio de reporte",
    y = "Millones de toneladas CO2/anio",
    caption = "Fuente: E-PRTR"
  ) +
  theme_satellite()

print(p_trend_country)
save_plot(p_trend_country, "01_tendencia_por_pais.png")

# --- B3. Mapa de cambio porcentual NUTS2 (primero vs ultimo anio) ------------

# Emisiones por NUTS2 en el primer y ultimo anio del periodo
nuts2_first <- co2_temporal[reportingYear == first_year & !is.na(nuts2), .(
  co2_first = sum(totalQuantityTon)
), by = nuts2]

nuts2_last <- co2_temporal[reportingYear == latest_year & !is.na(nuts2), .(
  co2_last = sum(totalQuantityTon)
), by = nuts2]

nuts2_change <- merge(nuts2_first, nuts2_last, by = "nuts2", all = TRUE)
nuts2_change[, change_pct := (co2_last / co2_first - 1) * 100]

# Limitar valores extremos para visualizacion
nuts2_change[, change_pct_capped := pmin(pmax(change_pct, -80), 80)]

cat("\n=== Cambio % emisiones NUTS2 ===\n")
cat(sprintf("  Regiones con reduccion: %d\n",
            sum(nuts2_change$change_pct < 0, na.rm = TRUE)))
cat(sprintf("  Regiones con aumento:   %d\n",
            sum(nuts2_change$change_pct > 0, na.rm = TRUE)))
cat(sprintf("  Cambio mediano:         %+.1f%%\n",
            median(nuts2_change$change_pct, na.rm = TRUE)))

# Merge con geometria
nuts2_change_map <- merge(nuts2_eu, nuts2_change,
                          by.x = "NUTS_ID", by.y = "nuts2", all.x = TRUE)

p_change <- ggplot2::ggplot(nuts2_change_map) +
  ggplot2::geom_sf(
    ggplot2::aes(fill = change_pct_capped),
    color = "grey60", linewidth = 0.15
  ) +
  ggplot2::scale_fill_gradientn(
    colours = pal_divergent,
    name = "Cambio %",
    limits = c(-80, 80),
    na.value = "#E8E6E0",
    labels = function(x) paste0(ifelse(x > 0, "+", ""), x, "%")
  ) +
  ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
  theme_map() +
  ggplot2::labs(
    title = sprintf("Cambio en emisiones CO2 por region NUTS 2 (%d vs %d)",
                    first_year, latest_year),
    subtitle = "Azul = reduccion | Magenta = aumento",
    caption = "Fuente: E-PRTR | Regiones sin datos comparables en gris"
  )

print(p_change)
save_plot(p_change, "01_mapa_cambio_nuts2.png")


# =============================================================================
# C. PERFIL POR SECTOR — Composicion industrial por zona
# =============================================================================

cat("\n")
cat("===================================================================\n")
cat("  C. PERFIL POR SECTOR — Composicion industrial\n")
cat("===================================================================\n\n")

# --- C1. Mapa de actividades E-PRTR (Annex I) --------------------------------
# Los codigos de actividad E-PRTR corresponden a:
# 1 = Energia, 2 = Metales, 3 = Minerales, 4 = Quimica, 5 = Residuos,
# 6 = Papel, 7 = Ganaderia, 8 = Alimentacion, 9 = Otros

latest[, sector_group := data.table::fcase(
  grepl("^1", mainActivity), "Energia",
  grepl("^2", mainActivity), "Metales",
  grepl("^3", mainActivity), "Minerales",
  grepl("^4", mainActivity), "Quimica",
  grepl("^5", mainActivity), "Residuos",
  grepl("^6", mainActivity), "Papel/Madera",
  grepl("^7", mainActivity), "Ganaderia",
  grepl("^8", mainActivity), "Alimentacion",
  grepl("^9", mainActivity), "Otros",
  default = "Otros"
)]

cat("=== Emisiones por grupo de sector ===\n")
sector_group_summary <- latest[, .(
  n_facilities = .N,
  total_co2_Mton = sum(totalQuantityTon) / 1e6,
  share_pct = sum(totalQuantityTon) / sum(latest$totalQuantityTon) * 100
), by = sector_group][order(-total_co2_Mton)]

print(sector_group_summary)

# --- C2. Barplot de sectores -------------------------------------------------

sector_group_summary[, sector_group := factor(sector_group,
  levels = rev(sector_group_summary$sector_group))]

p_sectors <- ggplot2::ggplot(sector_group_summary,
    ggplot2::aes(x = sector_group, y = total_co2_Mton,
                 fill = sector_group)) +
  ggplot2::geom_col(width = 0.7, show.legend = FALSE) +
  scale_fill_sectors() +
  ggplot2::geom_text(
    ggplot2::aes(label = sprintf("%.0f%%", share_pct)),
    hjust = -0.2, size = 3.5, color = col_text
  ) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = sprintf("Emisiones CO2 por sector industrial (%d)", latest_year),
    subtitle = "Clasificacion E-PRTR Annex I",
    x = NULL,
    y = "Millones de toneladas CO2/anio",
    caption = "Fuente: E-PRTR"
  ) +
  theme_satellite() +
  ggplot2::expand_limits(y = max(sector_group_summary$total_co2_Mton) * 1.15)

print(p_sectors)
save_plot(p_sectors, "01_emisiones_por_sector.png")

# --- C3. Tendencia temporal por sector ---------------------------------------

sector_trend <- co2_temporal[reportingYear >= first_year]
sector_trend[, sector_group := data.table::fcase(
  grepl("^1", mainActivity), "Energia",
  grepl("^2", mainActivity), "Metales",
  grepl("^3", mainActivity), "Minerales",
  grepl("^4", mainActivity), "Quimica",
  grepl("^5", mainActivity), "Residuos",
  default = "Otros"
)]

sector_trend_agg <- sector_trend[, .(
  total_co2_Mton = sum(totalQuantityTon) / 1e6
), by = .(reportingYear, sector_group)]

p_sector_trend <- ggplot2::ggplot(sector_trend_agg,
    ggplot2::aes(x = reportingYear, y = total_co2_Mton,
                 fill = sector_group)) +
  ggplot2::geom_area(alpha = 0.85, color = "white", linewidth = 0.3) +
  ggplot2::scale_fill_manual(
    values = c("Energia" = palette_satellite$blue_river,
               "Metales" = palette_satellite$cyan_dark,
               "Minerales" = palette_satellite$green_mid,
               "Quimica" = palette_satellite$magenta,
               "Residuos" = palette_satellite$fuchsia,
               "Otros" = palette_satellite$khaki),
    name = "Sector"
  ) +
  ggplot2::labs(
    title = "Evolucion de emisiones CO2 por sector industrial",
    subtitle = sprintf("%d-%d — Area apilada", first_year, latest_year),
    x = "Anio de reporte",
    y = "Millones de toneladas CO2/anio",
    caption = "Fuente: E-PRTR"
  ) +
  theme_satellite()

print(p_sector_trend)
save_plot(p_sector_trend, "01_tendencia_por_sector.png")

# --- C4. Mapa: sector dominante por region NUTS2 -----------------------------

# Determinar el sector que mas emite en cada region
latest_with_sector <- latest[!is.na(nuts2)]
latest_with_sector[, sector_group := data.table::fcase(
  grepl("^1", mainActivity), "Energia",
  grepl("^2", mainActivity), "Metales",
  grepl("^3", mainActivity), "Minerales",
  grepl("^4", mainActivity), "Quimica",
  grepl("^5", mainActivity), "Residuos",
  default = "Otros"
)]

dominant_sector <- latest_with_sector[, .(
  total_co2 = sum(totalQuantityTon)
), by = .(nuts2, sector_group)]

dominant_sector <- dominant_sector[
  dominant_sector[, .I[which.max(total_co2)], by = nuts2]$V1
]

nuts2_sector_map <- merge(nuts2_eu, dominant_sector,
                          by.x = "NUTS_ID", by.y = "nuts2", all.x = TRUE)

p_dominant <- ggplot2::ggplot(nuts2_sector_map) +
  ggplot2::geom_sf(
    ggplot2::aes(fill = sector_group),
    color = "grey60", linewidth = 0.15
  ) +
  ggplot2::scale_fill_manual(
    values = c("Energia" = palette_satellite$blue_river,
               "Metales" = palette_satellite$cyan_dark,
               "Minerales" = palette_satellite$green_mid,
               "Quimica" = palette_satellite$magenta,
               "Residuos" = palette_satellite$fuchsia,
               "Otros" = palette_satellite$khaki),
    name = "Sector\ndominante",
    na.value = "#E8E6E0"
  ) +
  ggplot2::coord_sf(xlim = c(-12, 35), ylim = c(34, 72)) +
  theme_map() +
  ggplot2::labs(
    title = sprintf("Sector industrial dominante por region NUTS 2 (%d)",
                    latest_year),
    subtitle = "Sector con mayor emision total de CO2 en cada region",
    caption = "Fuente: E-PRTR | Regiones sin datos en gris"
  )

print(p_dominant)
save_plot(p_dominant, "01_mapa_sector_dominante.png")

# =============================================================================
# RESUMEN FINAL
# =============================================================================

cat("\n")
cat("===================================================================\n")
cat("  FASE EXPLORATORIA COMPLETADA\n")
cat("===================================================================\n\n")

cat("Graficos generados en output/:\n")
cat("  01_histograma_emisiones.png    — Distribucion estadistica\n")
cat("  01_mapa_emisiones_claro.png    — Mapa de puntos (fondo claro)\n")
cat("  01_mapa_emisiones_dark.png     — Mapa de puntos (estilo satelital)\n")
cat("  01_mapa_nuts2_emisiones.png    — Coropletico por NUTS2\n")
cat("  01_top20_emisores.png          — Top 20 instalaciones\n")
cat("  01_emisiones_por_pais.png      — Ranking de paises\n")
cat("  01_tendencia_europea.png       — Tendencia agregada EU\n")
cat("  01_tendencia_por_pais.png      — Tendencia por pais (top 10)\n")
cat("  01_mapa_cambio_nuts2.png       — Mapa de cambio % por NUTS2\n")
cat("  01_emisiones_por_sector.png    — Barplot por sector\n")
cat("  01_tendencia_por_sector.png    — Area apilada temporal\n")
cat("  01_mapa_sector_dominante.png   — Sector dominante por NUTS2\n")

cat("\nHallazgos clave a revisar:\n")
cat("  - Existen clusters espaciales de emision? (justifica mbg)\n")
cat("  - Que regiones reducen vs. aumentan emisiones?\n")
cat("  - El sector energetico domina o hay diversidad sectorial?\n")

cat("\nContinua con 02_data_preparation.R\n")
