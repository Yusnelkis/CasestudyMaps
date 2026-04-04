# =============================================================================
# 00_download_data.R — Descarga de datos publicos
# =============================================================================
# Este script descarga los datos necesarios para el caso de estudio:
#   1. E-PRTR: Emisiones industriales CO2 (EEA DiscoData API)
#   2. NUTS: Limites administrativos (Eurostat/GISCO)
#   3. Covariables: CORINE y poblacion (instrucciones de descarga manual)

cat("=== Descargando datos para el caso de estudio E-PRTR ===\n\n")

dir.create("data/nuts", recursive = TRUE, showWarnings = FALSE)
dir.create("data/covariates", recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# 1. E-PRTR — Emisiones industriales CO2 (via EEA DiscoData SQL API)
# =============================================================================
# Fuente: European Industrial Emissions Portal — DiscoData SQL endpoint
# API: https://discodata.eea.europa.eu/sql
# Base de datos: [IED].[latest]
# Tablas: ProductionFacility, ProductionFacilityReport, PollutantRelease

eprtr_file <- "data/eprtr_co2_emissions.csv"

if (!file.exists(eprtr_file)) {
  cat("[E-PRTR] Descargando emisiones CO2 desde DiscoData API...\n")
  cat("  Esto puede tardar unos minutos (descarga por pais).\n\n")

  # Obtener lista de paises
  countries_url <- URLencode(paste0(
    "https://discodata.eea.europa.eu/sql?query=",
    "SELECT DISTINCT f.countryCode as cc FROM [IED].[latest].[ProductionFacility] f"
  ))

  countries_json <- jsonlite::fromJSON(countries_url)
  countries <- sort(countries_json$results$cc)
  cat("  Paises encontrados:", length(countries), "\n")

  all_data <- data.table::data.table()

  for (cc in countries) {
    query <- sprintf(paste0(
      "SELECT TOP 50000 ",
      "f.facilityName as facilityName, ",
      "f.x_4326 as longitude, f.y_4326 as latitude, ",
      "f.countryCode as countryCode, f.reportingYear as reportingYear, ",
      "f.EPRTRAnnexIMainActivity as mainActivity, ",
      "f.NUTS1 as nuts1, f.NUTS2 as nuts2, f.NUTS3 as nuts3, ",
      "f.city as city, f.status as status, ",
      "p.totalPollutantQuantityKg as totalQuantityKg, ",
      "p.methodCode as methodCode ",
      "FROM [IED].[latest].[ProductionFacility] f ",
      "INNER JOIN [IED].[latest].[ProductionFacilityReport] r ",
      "ON f.localId = r.localId AND f.countryCode = r.countryCode ",
      "AND f.reportingYear = r.reportingYear ",
      "INNER JOIN [IED].[latest].[PollutantRelease] p ",
      "ON r.Id = p.facilityReportId AND r.controlFileId = p.controlFileId ",
      "WHERE p.pollutant = 'CO2' AND p.mediumCode = 'AIR' ",
      "AND f.countryCode = '%s'"
    ), cc)

    url <- URLencode(paste0("https://discodata.eea.europa.eu/sql?query=", query))

    tryCatch({
      result <- jsonlite::fromJSON(url)
      if (!is.null(result$results) && nrow(result$results) > 0) {
        dt <- data.table::as.data.table(result$results)
        all_data <- data.table::rbindlist(list(all_data, dt), fill = TRUE)
        cat(sprintf("  %s: %d registros\n", cc, nrow(dt)))
      }
    }, error = function(e) {
      cat(sprintf("  %s: ERROR - %s\n", cc, e$message))
    })

    Sys.sleep(0.3)  # Rate limiting
  }

  if (nrow(all_data) > 0) {
    data.table::fwrite(all_data, eprtr_file)
    cat(sprintf("\n[E-PRTR] OK: %d registros guardados en %s\n",
                nrow(all_data), eprtr_file))
    cat(sprintf("  Paises: %d | Anios: %d-%d\n",
                length(unique(all_data$countryCode)),
                min(all_data$reportingYear), max(all_data$reportingYear)))
  }

} else {
  n <- nrow(data.table::fread(eprtr_file, select = 1L))
  cat(sprintf("[E-PRTR] Ya existe: %s (%s registros)\n", eprtr_file,
              format(n, big.mark = ",")))
}

# =============================================================================
# 2. NUTS — Limites administrativos (Eurostat GISCO)
# =============================================================================
# Escala 1:1M, formato GeoJSON, CRS EPSG:4326.

nuts_base_url <- "https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson"

for (level in 0:2) {
  nuts_file <- sprintf("data/nuts/NUTS_RG_01M_2021_%d_4326.geojson", level)
  if (!file.exists(nuts_file)) {
    url <- sprintf("%s/NUTS_RG_01M_2021_4326_LEVL_%d.geojson",
                   nuts_base_url, level)
    cat(sprintf("[NUTS %d] Descargando desde Eurostat GISCO...\n", level))
    tryCatch({
      download.file(url, nuts_file, mode = "wb", quiet = TRUE)
      size_mb <- file.info(nuts_file)$size / 1024 / 1024
      cat(sprintf("[NUTS %d] OK: %s (%.1f MB)\n", level, nuts_file, size_mb))
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

corine_file <- "data/covariates/corine_2018.tif"
if (!file.exists(corine_file)) {
  cat("[CORINE] Descarga manual requerida (opcional):\n")
  cat("  1. Registrarse en https://land.copernicus.eu/ (gratis)\n")
  cat("  2. Descargar CLC 2018 GeoTIFF (100m)\n")
  cat("  3. Guardar como: data/covariates/corine_2018.tif\n\n")
} else {
  cat("[CORINE] Archivo encontrado:", corine_file, "\n\n")
}

# =============================================================================
# 4. Densidad de poblacion (JRC GHSL — descarga manual)
# =============================================================================

pop_file <- "data/covariates/ghsl_pop_2020.tif"
if (!file.exists(pop_file)) {
  cat("[GHSL-POP] Descarga manual requerida (opcional):\n")
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
  "E-PRTR CO2"  = eprtr_file,
  "NUTS 0"      = "data/nuts/NUTS_RG_01M_2021_0_4326.geojson",
  "NUTS 1"      = "data/nuts/NUTS_RG_01M_2021_1_4326.geojson",
  "NUTS 2"      = "data/nuts/NUTS_RG_01M_2021_2_4326.geojson",
  "CORINE"      = corine_file,
  "GHSL-POP"    = pop_file
)

for (nm in names(required_files)) {
  status <- if (file.exists(required_files[nm])) "OK" else "OPCIONAL"
  cat(sprintf("  [%-8s] %s\n", status, nm))
}

cat("\nDatos principales listos. Ejecuta 01_explore_data.R\n")
