# =============================================================================
# 01_explore_mbg.R — Exploracion del paquete mbg
# =============================================================================
# Objetivo: Familiarizarse con el paquete, sus funciones y datos de ejemplo.

source("R/utils.R")
load_project_packages()

# --- 1. Funciones disponibles en mbg ----------------------------------------

cat("=== Funciones exportadas por mbg ===\n")
print(ls("package:mbg"))

# --- 2. Cargar datos de ejemplo (Benin stunting) -----------------------------
# El paquete incluye datos de ejemplo de desnutricion infantil en Benin.
# Consultar la vignette para detalles:
# vignette("mbg", package = "mbg")

cat("\n=== Datos de ejemplo ===\n")

# Datos de puntos observados (encuestas de salud)
data("benin_stunting_data", package = "mbg")
cat("Dimensiones de benin_stunting_data:", nrow(benin_stunting_data), "x",
    ncol(benin_stunting_data), "\n")
str(benin_stunting_data)

# --- 3. Explorar la estructura de los datos ----------------------------------

cat("\n=== Variables disponibles ===\n")
print(names(benin_stunting_data))

cat("\n=== Resumen estadistico ===\n")
summary(benin_stunting_data)

# --- 4. Visualizacion basica -------------------------------------------------

# Convertir a objeto sf para visualizacion
if ("longitude" %in% names(benin_stunting_data) && "latitude" %in% names(benin_stunting_data)) {
  points_sf <- sf::st_as_sf(
    benin_stunting_data,
    coords = c("longitude", "latitude"),
    crs = 4326
  )

  # Mapa simple de los puntos de observacion
  p <- ggplot2::ggplot(points_sf) +
    ggplot2::geom_sf(ggplot2::aes(color = stunting_rate), size = 2) +
    ggplot2::scale_color_viridis_c(name = "Tasa de\ndesnutricion") +
    ggplot2::theme_minimal() +
    ggplot2::labs(
      title = "Datos de desnutricion infantil - Benin",
      subtitle = "Datos de ejemplo del paquete mbg"
    )

  print(p)
  # save_plot(p, "01_puntos_observacion.png")
}

# --- 5. Explorar la clase MbgModelRunner -------------------------------------

cat("\n=== MbgModelRunner ===\n")
cat("MbgModelRunner es una clase R6 que orquesta todo el pipeline de mbg.\n")
cat("Metodos principales:\n")
cat("  - $new()           : Crear instancia con datos y configuracion\n")
cat("  - $fit()           : Ajustar el modelo geoestadistico\n")
cat("  - $predict()       : Generar predicciones espaciales\n")
cat("  - $cross_validate(): Validacion cruzada espacial\n")

cat("\nExploracion completada. Continua con 02_data_preparation.R\n")
