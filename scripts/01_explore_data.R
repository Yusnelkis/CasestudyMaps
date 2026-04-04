# =============================================================================
# 01_explore_data.R — Exploracion de datos E-PRTR y covariables
# =============================================================================
# Objetivo: Familiarizarse con los datos de emisiones industriales,
#           su distribucion espacial, sectores y patrones.

source("R/utils.R")
load_project_packages()

# --- 1. Cargar datos E-PRTR -------------------------------------------------

co2_data <- load_eprtr_co2()

cat("\n=== Estructura de los datos ===\n")
str(co2_data)

# Convertir kg a toneladas para legibilidad
co2_data[, totalQuantityTon := totalQuantityKg / 1000]

cat("\n=== Resumen de emisiones CO2 (toneladas/anio) ===\n")
summary(co2_data$totalQuantityTon)

cat("\nEmisiones totales (ultimo anio disponible):\n")
latest_year <- max(co2_data$reportingYear)
latest <- co2_data[reportingYear == latest_year]
cat(sprintf("  Anio: %d | Instalaciones: %d | Total: %s toneladas\n",
            latest_year, nrow(latest),
            format(sum(latest$totalQuantityTon), big.mark = ",")))

# --- 2. Distribucion por sector industrial -----------------------------------

cat("\n=== Emisiones por sector (ultimo anio) ===\n")
sector_summary <- latest[, .(
  n_facilities = .N,
  total_co2_ton = sum(totalQuantityTon),
  mean_co2_ton = mean(totalQuantityTon),
  median_co2_ton = median(totalQuantityTon)
), by = mainActivity][order(-total_co2_ton)]

print(head(sector_summary, 15))

# --- 3. Distribucion por pais ------------------------------------------------

cat("\n=== Emisiones por pais (ultimo anio) ===\n")
country_summary <- latest[, .(
  n_facilities = .N,
  total_co2_ton = sum(totalQuantityTon)
), by = countryCode][order(-total_co2_ton)]

print(head(country_summary, 20))

# --- 4. Distribucion estadistica de emisiones --------------------------------

# Las emisiones tienen distribucion muy sesgada -> transformacion log
p_hist <- ggplot2::ggplot(latest, ggplot2::aes(x = log10(totalQuantityTon))) +
  ggplot2::geom_histogram(bins = 50, fill = palette_satellite$blue_river,
                          color = "#FFFFFF", linewidth = 0.2) +
  ggplot2::labs(
    title = "Distribucion de emisiones industriales de CO2",
    subtitle = sprintf("Escala log10 — E-PRTR %d", latest_year),
    x = "log10(CO2 toneladas/anio)",
    y = "Numero de instalaciones",
    caption = "Fuente: EEA DiscoData API — Industrial Emissions Portal"
  ) +
  theme_satellite()

print(p_hist)
# save_plot(p_hist, "01_histograma_emisiones.png")

# --- 5. Mapa de instalaciones ------------------------------------------------

# Cargar limites NUTS 0 (paises)
nuts0 <- load_nuts(level = 0, path = "data/nuts/NUTS_RG_01M_2021_0_4326.geojson")

# Convertir emisiones a sf (solo ultimo anio)
co2_sf <- eprtr_to_sf(latest)

# Version clara (fondo claro)
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
  ggplot2::coord_sf(xlim = c(-12, 45), ylim = c(34, 72)) +
  theme_map() +
  ggplot2::labs(
    title = sprintf("Emisiones industriales de CO2 en Europa (%d)", latest_year),
    subtitle = "Fuente: E-PRTR — European Industrial Emissions Portal",
    caption = "Paleta inspirada en imagen satelital falso color (IR cercano)"
  )

# Version oscura (fondo oceano — estilo satelital)
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
  ggplot2::coord_sf(xlim = c(-12, 45), ylim = c(34, 72)) +
  theme_map_dark() +
  ggplot2::labs(
    title = sprintf("Emisiones industriales de CO2 en Europa (%d)", latest_year),
    subtitle = "Fuente: E-PRTR — European Industrial Emissions Portal"
  )

print(p_map)
print(p_map_dark)
# save_plot(p_map, "01_mapa_emisiones_europa.png")
# save_plot(p_map_dark, "01_mapa_emisiones_dark.png")

# --- 6. Top emisores ---------------------------------------------------------

cat("\n=== Top 20 instalaciones por emision de CO2 ===\n")
top_emitters <- latest[order(-totalQuantityTon), .(
  facilityName, countryCode, mainActivity,
  co2_kton = round(totalQuantityTon / 1000, 1)
)][1:20]

print(top_emitters)

# --- 7. Explorar mbg ---------------------------------------------------------

cat("\n=== Funciones exportadas por mbg ===\n")
print(ls("package:mbg"))

cat("\nExploracion completada. Continua con 02_data_preparation.R\n")
