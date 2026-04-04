# =============================================================================
# 00_download_data.R — Descarga de datos publicos
# =============================================================================
# Este script descarga los datos necesarios para el caso de estudio:
#   1. E-PRTR: Emisiones industriales (EEA)
#   2. NUTS: Limites administrativos (Eurostat/GISCO)
#   3. Poblacion: Densidad de poblacion (Eurostat)
#
# NOTA: Algunos datasets (CORINE, CAMS) requieren descarga manual
# desde Copernicus con registro gratuito.

cat("=== Descargando datos para el caso de estudio E-PRTR ===\n\n")

dir.create("data/nuts", recursive = TRUE, showWarnings = FALSE)
dir.create("data/covariates", recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# 1. E-PRTR — Emisiones industriales
# =============================================================================
# Fuente: European Industrial Emissions Portal (EEA)
# URL: https://industry.eea.europa.eu/download
#
# INSTRUCCIONES DE DESCARGA MANUAL:
# 1. Ir a https://industry.eea.europa.eu/download
# 2. Seleccionar "Facility level data" y descargar el CSV
# 3. Guardar como: data/eprtr_facilities.csv
#
# El archivo contiene ~33,000 instalaciones con:
#   - facilityName, longitude, latitude
#   - pollutant, totalQuantity, unit
#   - mainActivityName (sector industrial)
#   - countryCode, NUTS region codes
#   - reportingYear

eprtr_file <- "data/eprtr_facilities.csv"
if (!file.exists(eprtr_file)) {
  cat("[E-PRTR] Descarga manual requerida:\n")
  cat("  1. Visita: https://industry.eea.europa.eu/download\n")
  cat("  2. Descarga 'Facility level data' (CSV)\n")
  cat("  3. Guarda como: data/eprtr_facilities.csv\n\n")
} else {
  cat("[E-PRTR] Archivo encontrado:", eprtr_file, "\n")
  cat("  Filas:", format(nrow(data.table::fread(eprtr_file, nrows = 0)),
                         big.mark = ","), "\n\n")
}

# =============================================================================
# 2. NUTS — Limites administrativos (Eurostat GISCO)
# =============================================================================
# Los limites NUTS se descargan automaticamente desde Eurostat GISCO.
# Escala 1:1M, formato GeoJSON, CRS EPSG:4326.

nuts_base_url <- "https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson"

for (level in 0:2) {
  nuts_file <- sprintf("data/nuts/NUTS_RG_01M_2021_%d_4326.geojson", level)
  if (!file.exists(nuts_file)) {
    url <- sprintf("%s/NUTS_RG_01M_2021_%d_4326.geojson", nuts_base_url, level)
    cat(sprintf("[NUTS %d] Descargando desde Eurostat GISCO...\n", level))
    tryCatch({
      download.file(url, nuts_file, mode = "wb", quiet = TRUE)
      cat(sprintf("[NUTS %d] OK: %s\n", level, nuts_file))
    }, error = function(e) {
      cat(sprintf("[NUTS %d] Error: %s\n", level, e$message))
      cat(sprintf("  Descarga manual: %s\n", url))
    })
  } else {
    cat(sprintf("[NUTS %d] Ya existe: %s\n", level, nuts_file))
  }
}

cat("\n")

# =============================================================================
# 3. CORINE Land Cover (descarga manual desde Copernicus)
# =============================================================================
# CORINE 2018, raster 100m, clasificacion de uso del suelo.
#
# INSTRUCCIONES:
# 1. Registrarse (gratis) en https://land.copernicus.eu/
# 2. Ir a: https://land.copernicus.eu/en/products/corine-land-cover
# 3. Descargar "CLC 2018" en formato GeoTIFF (100m)
# 4. Guardar como: data/covariates/corine_2018.tif

corine_file <- "data/covariates/corine_2018.tif"
if (!file.exists(corine_file)) {
  cat("[CORINE] Descarga manual requerida:\n")
  cat("  1. Registrarse en https://land.copernicus.eu/ (gratis)\n")
  cat("  2. Descargar CLC 2018 GeoTIFF (100m)\n")
  cat("  3. Guardar como: data/covariates/corine_2018.tif\n\n")
} else {
  cat("[CORINE] Archivo encontrado:", corine_file, "\n\n")
}

# =============================================================================
# 4. Densidad de poblacion (JRC GHSL)
# =============================================================================
# GHS-POP: Global Human Settlement Layer - Population Grid
# Resolucion: ~1km (30 arc-seconds)
#
# INSTRUCCIONES:
# 1. Ir a: https://ghsl.jrc.ec.europa.eu/download.php?ds=pop
# 2. Seleccionar epoch 2020, resolucion 30 arc-sec, CRS WGS84
# 3. Descargar tile(s) para Europa
# 4. Guardar como: data/covariates/ghsl_pop_2020.tif

pop_file <- "data/covariates/ghsl_pop_2020.tif"
if (!file.exists(pop_file)) {
  cat("[GHSL-POP] Descarga manual requerida:\n")
  cat("  1. Visita: https://ghsl.jrc.ec.europa.eu/download.php?ds=pop\n")
  cat("  2. Selecciona epoch 2020, 30 arc-sec, WGS84\n")
  cat("  3. Descarga tile(s) de Europa\n")
  cat("  4. Guardar como: data/covariates/ghsl_pop_2020.tif\n\n")
} else {
  cat("[GHSL-POP] Archivo encontrado:", pop_file, "\n\n")
}

# =============================================================================
# Resumen
# =============================================================================

cat("=== Resumen de datos ===\n")
required_files <- c(
  "E-PRTR" = eprtr_file,
  "NUTS 0" = "data/nuts/NUTS_RG_01M_2021_0_4326.geojson",
  "NUTS 1" = "data/nuts/NUTS_RG_01M_2021_1_4326.geojson",
  "NUTS 2" = "data/nuts/NUTS_RG_01M_2021_2_4326.geojson",
  "CORINE" = corine_file,
  "GHSL-POP" = pop_file
)

for (nm in names(required_files)) {
  status <- if (file.exists(required_files[nm])) "OK" else "FALTA"
  cat(sprintf("  [%s] %s\n", status, nm))
}

cat("\nCuando todos los archivos esten disponibles, ejecuta 01_explore_data.R\n")
