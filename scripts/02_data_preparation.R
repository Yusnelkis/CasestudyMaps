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

co2_raw <- load_eprtr_co2("data/eprtr_facilities.csv")

# Filtrar anio de reporte mas reciente disponible
latest_year <- max(co2_raw$reportingYear)
cat("Usando datos del anio:", latest_year, "\n")
co2 <- co2_raw[reportingYear == latest_year]

# Transformar emisiones a escala log (distribucion muy sesgada)
co2[, log_co2 := log(totalQuantity)]

cat(sprintf("Instalaciones: %d\n", nrow(co2)))
cat(sprintf("Rango emisiones: %.0f - %.0f ton/anio\n",
            min(co2$totalQuantity), max(co2$totalQuantity)))
cat(sprintf("Rango log(CO2): %.2f - %.2f\n",
            min(co2$log_co2), max(co2$log_co2)))

# --- 2. Filtrar area de estudio (UE continental) ------------------------------

# Excluir puntos fuera del area continental europea
co2 <- co2[longitude >= -12 & longitude <= 45 &
           latitude >= 34 & latitude <= 72]

cat(sprintf("Instalaciones en area de estudio: %d\n", nrow(co2)))

# --- 3. Cargar limites administrativos NUTS -----------------------------------

nuts0 <- load_nuts(level = 0, path = "data/nuts/NUTS_RG_01M_2021_0_4326.geojson")
nuts1 <- load_nuts(level = 1, path = "data/nuts/NUTS_RG_01M_2021_1_4326.geojson")
nuts2 <- load_nuts(level = 2, path = "data/nuts/NUTS_RG_01M_2021_2_4326.geojson")

# Filtrar NUTS a UE continental (misma bounding box)
nuts2_eu <- nuts2[sf::st_coordinates(sf::st_centroid(nuts2))[, 1] >= -12 &
                  sf::st_coordinates(sf::st_centroid(nuts2))[, 1] <= 45 &
                  sf::st_coordinates(sf::st_centroid(nuts2))[, 2] >= 34 &
                  sf::st_coordinates(sf::st_centroid(nuts2))[, 2] <= 72, ]

cat(sprintf("Regiones NUTS 2 en area de estudio: %d\n", nrow(nuts2_eu)))

# --- 4. Cargar covariables raster ---------------------------------------------

cat("\n=== Cargando covariables raster ===\n")

# CORINE Land Cover
corine_file <- "data/covariates/corine_2018.tif"
if (file.exists(corine_file)) {
  corine <- terra::rast(corine_file)
  cat("CORINE cargado:", terra::ncell(corine), "celdas\n")
} else {
  cat("CORINE no disponible — se omitira como covariable.\n")
  cat("Descarga desde: https://land.copernicus.eu/en/products/corine-land-cover\n")
  corine <- NULL
}

# Densidad de poblacion (GHSL)
pop_file <- "data/covariates/ghsl_pop_2020.tif"
if (file.exists(pop_file)) {
  population <- terra::rast(pop_file)
  cat("Poblacion cargado:", terra::ncell(population), "celdas\n")
} else {
  cat("GHSL-POP no disponible — se omitira como covariable.\n")
  cat("Descarga desde: https://ghsl.jrc.ec.europa.eu/download.php?ds=pop\n")
  population <- NULL
}

# --- 5. Preparar stack de covariables -----------------------------------------
# Crear un raster template para el area de estudio
# Si no hay rasters externos, creamos uno sintetico basado en coordenadas

if (!is.null(corine) || !is.null(population)) {
  # Alinear y apilar covariables disponibles
  cov_list <- list()
  if (!is.null(corine)) cov_list$corine <- corine
  if (!is.null(population)) cov_list$population <- population

  # Resamplear al raster de menor resolucion para alinear
  cat("\nAlineando covariables...\n")
  # covariates_stack <- terra::rast(cov_list)  # Ajustar segun resolucion
} else {
  cat("\nSin covariables raster externas disponibles.\n")
  cat("El modelo usara solo la estructura espacial (proceso Gaussiano).\n")
  cat("Para mejores resultados, descarga CORINE y/o GHSL-POP.\n")
}

# --- 6. Construir raster de IDs para prediccion -------------------------------

cat("\n=== Construyendo raster de IDs ===\n")

# Crear un raster template basado en el extent de NUTS2
# Resolucion ~10km (0.1 grados) para escala europea
eu_extent <- terra::ext(-12, 45, 34, 72)
template_raster <- terra::rast(eu_extent, res = 0.1, crs = "EPSG:4326")
template_raster[] <- 1  # Rellenar con valores

# Construir ID raster usando limites NUTS 2
# id_raster <- mbg::build_id_raster(
#   raster_template = template_raster,
#   shapefile = nuts2_eu
# )

cat("Template raster creado:", terra::ncell(template_raster), "celdas\n")
cat("Resolucion: 0.1 grados (~10 km)\n")

# --- 7. Preparar datos en formato mbg ----------------------------------------

# mbg espera un data.frame/data.table con columnas especificas
mbg_input <- data.table::data.table(
  facility_id = co2$facilityId,
  longitude = co2$longitude,
  latitude = co2$latitude,
  log_co2 = co2$log_co2,
  sector = co2$mainActivityName,
  country = co2$countryCode
)

cat(sprintf("\nDatos preparados para mbg: %d observaciones\n", nrow(mbg_input)))
cat("Columnas:", paste(names(mbg_input), collapse = ", "), "\n")

# --- 8. Guardar objetos preparados -------------------------------------------

saveRDS(mbg_input, "data/prepared_emissions.rds")
saveRDS(nuts2_eu, "data/nuts2_eu.rds")
cat("\nObjetos guardados en data/\n")

cat("\nContinua con 03_covariate_modeling.R\n")
