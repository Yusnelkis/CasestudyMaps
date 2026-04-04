# =============================================================================
# 00_setup.R — Instalacion de dependencias
# =============================================================================
# Ejecutar este script una vez para configurar el entorno del proyecto.

cat("=== Configurando entorno del proyecto CasestudyMaps ===\n\n")

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
"R6"            # Clases R6 (usado por mbg internamente)
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

if (success) {
  cat("\nEntorno configurado correctamente. Puedes continuar con 01_explore_mbg.R\n")
} else {
  cat("\nAlgunos paquetes no se instalaron. Revisa los errores arriba.\n")
}
