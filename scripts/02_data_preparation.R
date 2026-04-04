# =============================================================================
# 02_data_preparation.R — Preparacion de datos para mbg
# =============================================================================
# Objetivo: Preparar todos los insumos del modelo geoestadistico:
#   - Datos de emisiones CO2 (puntos con coordenadas)
#   - Covariables raster (CORINE, poblacion)
#   - Limites NUTS para agregacion
#   - Raster de IDs para prediccion

source("R/utils.R")
load_project_packages()

# --- 1. Cargar y limpiar datos E-PRTR ----------------------------------------

co2_raw <- load_eprtr_co2()

# Filtrar anio de reporte mas reciente disponible
latest_year <- max(co2_raw$reportingYear)
cat("Usando datos del anio:", latest_year, "\n")
co2 <- co2_raw[reportingYear == latest_year]

# Convertir a toneladas y transformar a escala log (distribucion muy sesgada)
co2[, totalQuantityTon := totalQuantityKg / 1000]
co2[, log_co2 := log(totalQuantityTon)]

cat(sprintf("Instalaciones: %d\n", nrow(co2)))
cat(sprintf("Rango emisiones: %.0f - %.0f ton/anio\n",
            min(co2$totalQuantityTon), max(co2$totalQuantityTon)))
cat(sprintf("Rango log(CO2): %.2f - %.2f\n",
            min(co2$log_co2), max(co2$log_co2)))

# --- 2. Filtrar area de estudio (UE continental) ------------------------------

co2 <- co2[longitude >= -12 & longitude <= 45 &
           latitude >= 34 & latitude <= 72]

cat(sprintf("Instalaciones en area de estudio: %d\n", nrow(co2)))

# --- 3. Cargar limites administrativos NUTS -----------------------------------

nuts0 <- load_nuts(level = 0, path = "data/nuts/NUTS_RG_01M_2021_0_4326.geojson")
nuts1 <- load_nuts(level = 1, path = "data/nuts/NUTS_RG_01M_2021_1_4326.geojson")
nuts2 <- load_nuts(level = 2, path = "data/nuts/NUTS_RG_01M_2021_2_4326.geojson")

# Filtrar NUTS a UE continental (misma bounding box)
centroids <- sf::st_coordinates(suppressWarnings(sf::st_centroid(nuts2)))
nuts2_eu <- nuts2[centroids[, 1] >= -12 & centroids[, 1] <= 45 &
                  centroids[, 2] >= 34 & centroids[, 2] <= 72, ]

cat(sprintf("Regiones NUTS 2 en area de estudio: %d\n", nrow(nuts2_eu)))

# --- 4. Cargar covariables raster (opcionales) --------------------------------

cat("\n=== Cargando covariables raster ===\n")

corine_file <- "data/covariates/corine_2018.tif"
if (file.exists(corine_file)) {
  corine <- terra::rast(corine_file)
  cat("CORINE cargado:", terra::ncell(corine), "celdas\n")
} else {
  cat("CORINE no disponible — se omitira como covariable.\n")
  corine <- NULL
}

pop_file <- "data/covariates/ghsl_pop_2020.tif"
if (file.exists(pop_file)) {
  population <- terra::rast(pop_file)
  cat("Poblacion cargado:", terra::ncell(population), "celdas\n")
} else {
  cat("GHSL-POP no disponible — se omitira como covariable.\n")
  population <- NULL
}

if (is.null(corine) && is.null(population)) {
  cat("\nSin covariables raster externas. El modelo usara solo la estructura\n")
  cat("espacial (proceso Gaussiano). Las coordenadas serviran como proxy.\n")
}

# --- 5. Construir raster de IDs para prediccion -------------------------------

cat("\n=== Construyendo raster de IDs ===\n")

# Raster template: resolucion ~10km (0.1 grados) para escala europea
eu_extent <- terra::ext(-12, 45, 34, 72)
template_raster <- terra::rast(eu_extent, res = 0.1, crs = "EPSG:4326")
template_raster[] <- 1

# id_raster <- mbg::build_id_raster(
#   raster_template = template_raster,
#   shapefile = nuts2_eu
# )

cat("Template raster creado:", terra::ncell(template_raster), "celdas\n")
cat("Resolucion: 0.1 grados (~10 km)\n")

# --- 6. Preparar datos en formato mbg ----------------------------------------

mbg_input <- data.table::data.table(
  facilityName = co2$facilityName,
  longitude = co2$longitude,
  latitude = co2$latitude,
  log_co2 = co2$log_co2,
  totalQuantityTon = co2$totalQuantityTon,
  mainActivity = co2$mainActivity,
  countryCode = co2$countryCode,
  nuts2 = co2$nuts2
)

cat(sprintf("\nDatos preparados para mbg: %d observaciones\n", nrow(mbg_input)))
cat("Columnas:", paste(names(mbg_input), collapse = ", "), "\n")

# --- 7. Guardar objetos preparados -------------------------------------------

saveRDS(mbg_input, "data/prepared_emissions.rds")
saveRDS(nuts2_eu, "data/nuts2_eu.rds")
cat("\nObjetos guardados en data/\n")

cat("\nContinua con 03_covariate_modeling.R\n")
