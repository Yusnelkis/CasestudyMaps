# =============================================================================
# 00_setup.R — Instalacion de dependencias
# =============================================================================
# Ejecutar este script una vez para configurar el entorno del proyecto.

cat("=== Configurando entorno del proyecto CasestudyMaps (E-PRTR) ===\n\n")

# --- 1. Instalar paquetes de CRAN -------------------------------------------

cran_pkgs <- c(
  "mbg",          # Model-Based Geostatistics
  "sf",           # Datos vectoriales espaciales
  "terra",        # Datos raster
  "data.table",   # Manipulacion rapida de datos
  "caret",        # Machine Learning
  "ggplot2",      # Visualizacion
  "tmap",         # Mapas tematicos
  "Matrix",       # Operaciones con matrices dispersas
  "R6",           # Clases R6 (usado por mbg internamente)
  "scales",       # Escalas para graficos
  "viridis",      # Paletas de color
  "countrycode"   # Codigos de pais ISO/NUTS
)

installed <- installed.packages()[, "Package"]
to_install <- setdiff(cran_pkgs, installed)

if (length(to_install) > 0) {
  cat("Instalando paquetes de CRAN:", paste(to_install, collapse = ", "), "\n")
  install.packages(to_install)
} else {
  cat("Todos los paquetes de CRAN ya estan instalados.\n")
}

# --- 2. Instalar R-INLA (no esta en CRAN) -----------------------------------

if (!requireNamespace("INLA", quietly = TRUE)) {
  cat("\nInstalando R-INLA desde r-inla.org...\n")
  install.packages(
    "INLA",
    repos = c(getOption("repos"), INLA = "https://inla.r-inla-download.org/R/stable"),
    dep = TRUE
  )
} else {
  cat("R-INLA ya esta instalado.\n")
}

# --- 3. Verificar instalacion ------------------------------------------------

cat("\n=== Verificando instalacion ===\n")
all_pkgs <- c(cran_pkgs, "INLA")
success <- TRUE

for (pkg in all_pkgs) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    ver <- packageVersion(pkg)
    cat(sprintf("  [OK] %-15s v%s\n", pkg, ver))
  } else {
    cat(sprintf("  [!!] %-15s NO INSTALADO\n", pkg))
    success <- FALSE
  }
}

# --- 4. Verificar librerias del sistema (GDAL, GEOS, PROJ) ------------------

cat("\n=== Librerias espaciales del sistema ===\n")
if (requireNamespace("sf", quietly = TRUE)) {
  ext_soft <- sf::sf_extSoftVersion()
  for (nm in names(ext_soft)) {
    cat(sprintf("  %-10s %s\n", nm, ext_soft[nm]))
  }
}

# --- 5. Crear directorios de trabajo -----------------------------------------

dirs <- c("data", "data/nuts", "data/covariates", "output")
for (d in dirs) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

if (success) {
  cat("\nEntorno configurado. Ejecuta 00_download_data.R para descargar datos.\n")
} else {
  cat("\nAlgunos paquetes no se instalaron. Revisa los errores arriba.\n")
}
