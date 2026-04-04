# =============================================================================
# 01_explore_data.R — Exploracion de datos E-PRTR y covariables
# =============================================================================
# Objetivo: Familiarizarse con los datos de emisiones industriales,
#           su distribucion espacial, sectores y patrones.

source("R/utils.R")
load_project_packages()

# --- 1. Cargar datos E-PRTR -------------------------------------------------

co2_data <- load_eprtr_co2("data/eprtr_facilities.csv")

cat("\n=== Estructura de los datos ===\n")
str(co2_data)

cat("\n=== Resumen de emisiones CO2 (toneladas/anio) ===\n")
summary(co2_data$totalQuantity)

cat("\nEmisiones totales:", format(sum(co2_data$totalQuantity), big.mark = ","),
    "toneladas\n")

# --- 2. Distribucion por sector industrial -----------------------------------

cat("\n=== Emisiones por sector ===\n")
sector_summary <- co2_data[, .(
  n_facilities = .N,
  total_co2 = sum(totalQuantity),
  mean_co2 = mean(totalQuantity),
  median_co2 = median(totalQuantity)
), by = mainActivityName][order(-total_co2)]

print(head(sector_summary, 15))

# --- 3. Distribucion por pais ------------------------------------------------

cat("\n=== Emisiones por pais ===\n")
country_summary <- co2_data[, .(
  n_facilities = .N,
  total_co2 = sum(totalQuantity)
), by = countryCode][order(-total_co2)]

print(head(country_summary, 20))

# --- 4. Distribucion estadistica de emisiones --------------------------------

# Las emisiones tienen distribucion muy sesgada -> transformacion log
p_hist <- ggplot2::ggplot(co2_data, ggplot2::aes(x = log10(totalQuantity))) +
  ggplot2::geom_histogram(bins = 50, fill = palette_satellite$blue_river,
                          color = "#FFFFFF", linewidth = 0.2) +
  ggplot2::labs(
    title = "Distribucion de emisiones industriales de CO2",
    subtitle = "Escala log10 — Datos E-PRTR",
    x = "log10(CO2 toneladas/anio)",
    y = "Numero de instalaciones",
    caption = "Fuente: European Industrial Emissions Portal (EEA)"
  ) +
  theme_satellite()

print(p_hist)
# save_plot(p_hist, "01_histograma_emisiones.png")

# --- 5. Mapa de instalaciones ------------------------------------------------

# Cargar limites NUTS 0 (paises)
nuts0 <- load_nuts(level = 0, path = "data/nuts/NUTS_RG_01M_2021_0_4326.geojson")

# Filtrar solo UE (excluir territorios ultramarinos)
eu_bbox <- sf::st_bbox(c(xmin = -12, ymin = 34, xmax = 45, ymax = 72),
                       crs = 4326)

# Convertir emisiones a sf
co2_sf <- eprtr_to_sf(co2_data)

# Version clara (fondo claro)
p_map <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = nuts0, fill = col_land, color = col_borders,
                   linewidth = 0.3) +
  ggplot2::geom_sf(
    data = co2_sf,
    ggplot2::aes(color = log10(totalQuantity), size = log10(totalQuantity)),
    alpha = 0.6
  ) +
  scale_color_emissions(name = "log10(CO2\nton/anio)") +
  ggplot2::scale_size_continuous(range = c(0.3, 3), guide = "none") +
  ggplot2::coord_sf(xlim = c(-12, 45), ylim = c(34, 72)) +
  theme_map() +
  ggplot2::labs(
    title = "Emisiones industriales de CO2 en Europa",
    subtitle = "Fuente: E-PRTR — European Industrial Emissions Portal",
    caption = "Paleta inspirada en imagen satelital falso color (IR cercano)"
  )

# Version oscura (fondo oceano — estilo satelital)
p_map_dark <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = nuts0, fill = "#142040", color = palette_satellite$cyan_dark,
                   linewidth = 0.2) +
  ggplot2::geom_sf(
    data = co2_sf,
    ggplot2::aes(color = log10(totalQuantity), size = log10(totalQuantity)),
    alpha = 0.7
  ) +
  scale_color_emissions(name = "log10(CO2\nton/anio)", palette = "warm") +
  ggplot2::scale_size_continuous(range = c(0.3, 3), guide = "none") +
  ggplot2::coord_sf(xlim = c(-12, 45), ylim = c(34, 72)) +
  theme_map_dark() +
  ggplot2::labs(
    title = "Emisiones industriales de CO2 en Europa",
    subtitle = "Fuente: E-PRTR — European Industrial Emissions Portal"
  )

print(p_map)
print(p_map_dark)
# save_plot(p_map, "01_mapa_emisiones_europa.png")
# save_plot(p_map_dark, "01_mapa_emisiones_dark.png")

# --- 6. Top emisores ---------------------------------------------------------

cat("\n=== Top 20 instalaciones por emision de CO2 ===\n")
top_emitters <- co2_data[order(-totalQuantity), .(
  facilityName, countryCode, mainActivityName,
  co2_Mt = round(totalQuantity / 1e6, 2)
)][1:20]

print(top_emitters)

# --- 7. Explorar mbg ---------------------------------------------------------

cat("\n=== Funciones exportadas por mbg ===\n")
print(ls("package:mbg"))

cat("\nExploracion completada. Continua con 02_data_preparation.R\n")
