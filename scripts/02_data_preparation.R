# =============================================================================
# 02_data_preparation.R — Preparacion de datos para mbg
# =============================================================================
# Objetivo: Preparar todos los insumos del modelo geoestadistico:
#   - Datos de emisiones CO2 en formato mbg (x, y, indicator, samplesize)
#   - Raster de IDs para prediccion
#   - Limites NUTS para agregacion

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

# Eliminar filas con valores invalidos (log de 0 o negativos)
co2 <- co2[is.finite(log_co2)]

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
nuts2 <- load_nuts(level = 2, path = "data/nuts/NUTS_RG_01M_2021_2_4326.geojson")

# Filtrar NUTS a UE continental
centroids <- sf::st_coordinates(suppressWarnings(sf::st_centroid(nuts2)))
nuts2_eu <- nuts2[centroids[, 1] >= -12 & centroids[, 1] <= 45 &
                  centroids[, 2] >= 34 & centroids[, 2] <= 72, ]

cat(sprintf("Regiones NUTS 2 en area de estudio: %d\n", nrow(nuts2_eu)))

# --- 4. Construir raster de IDs para prediccion -------------------------------

cat("\n=== Construyendo raster de IDs ===\n")

# Raster template: resolucion ~10km (0.1 grados) para escala europea
eu_extent <- terra::ext(-12, 45, 34, 72)
template_raster <- terra::rast(eu_extent, res = 0.1, crs = "EPSG:4326")
template_raster[] <- 1

# Construir ID raster usando limites NUTS 2
id_raster <- mbg::build_id_raster(
  polygons = nuts2_eu,
  template_raster = template_raster
)

cat("ID raster creado:", terra::ncell(id_raster), "celdas\n")
cat("Celdas con valor:", sum(!is.na(terra::values(id_raster))), "\n")

# --- 5. Construir tabla de agregacion ----------------------------------------

cat("\n=== Construyendo tabla de agregacion ===\n")

aggregation_table <- mbg::build_aggregation_table(
  polygons = nuts2_eu,
  id_raster = id_raster,
  polygon_id_field = "NUTS_ID"
)

cat(sprintf("Tabla de agregacion: %d filas\n", nrow(aggregation_table)))

# --- 6. Preparar datos en formato mbg ----------------------------------------
# mbg espera: x, y, indicator, samplesize, cluster_id
# Para familia gaussiana: indicator = valor continuo, samplesize = 1

cat("\n=== Preparando datos en formato mbg ===\n")

mbg_input <- data.table::data.table(
  cluster_id = seq_len(nrow(co2)),
  x = co2$longitude,
  y = co2$latitude,
  indicator = co2$log_co2,
  samplesize = rep(1L, nrow(co2)),
  sd = rep(1, nrow(co2)),  # Precision uniforme para familia gaussiana
  # Columnas adicionales para referencia
  facilityName = co2$facilityName,
  totalQuantityTon = co2$totalQuantityTon,
  mainActivity = co2$mainActivity,
  countryCode = co2$countryCode,
  nuts2 = co2$nuts2
)

cat(sprintf("Datos preparados para mbg: %d observaciones\n", nrow(mbg_input)))
cat(sprintf("Variable respuesta (indicator): log(CO2 ton), rango [%.2f, %.2f]\n",
            min(mbg_input$indicator), max(mbg_input$indicator)))

# --- 7. Guardar objetos preparados -------------------------------------------

saveRDS(mbg_input, "data/prepared_emissions.rds")
saveRDS(nuts2_eu, "data/nuts2_eu.rds")
saveRDS(id_raster, "data/id_raster.rds")
saveRDS(aggregation_table, "data/aggregation_table.rds")
cat("\nObjetos guardados:\n")
cat("  data/prepared_emissions.rds\n")
cat("  data/nuts2_eu.rds\n")
cat("  data/id_raster.rds\n")
cat("  data/aggregation_table.rds\n")

cat("\nContinua con 04_spatial_model.R\n")
