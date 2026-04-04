# =============================================================================
# utils.R — Funciones auxiliares para el caso de estudio E-PRTR
# =============================================================================

#' Cargar paquetes del proyecto
load_project_packages <- function() {
  pkgs <- c("mbg", "sf", "terra", "data.table", "caret", "ggplot2", "tmap")
  for (pkg in pkgs) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("Paquete '", pkg, "' no instalado. Ejecuta scripts/00_setup.R primero.")
    }
    library(pkg, character.only = TRUE)
  }
  message("Todos los paquetes cargados correctamente.")
}

#' Guardar un plot en la carpeta output/
save_plot <- function(plot, filename, width = 10, height = 8) {
  filepath <- file.path("output", filename)
  dir.create(dirname(filepath), recursive = TRUE, showWarnings = FALSE)
  if (inherits(plot, "ggplot")) {
    ggplot2::ggsave(filepath, plot, width = width, height = height, dpi = 300)
  } else if (inherits(plot, "tmap")) {
    tmap::tmap_save(plot, filepath, width = width, height = height, dpi = 300)
  } else {
    stop("Tipo de plot no soportado. Usa ggplot2 o tmap.")
  }
  message("Plot guardado en: ", filepath)
}

#' Verificar que un archivo existe antes de cargarlo
check_file <- function(path) {
  if (!file.exists(path)) {
    stop("Archivo no encontrado: ", path,
         "\nEjecuta scripts/00_download_data.R para descargar los datos.")
  }
  invisible(path)
}

#' Cargar datos E-PRTR filtrados para CO2
load_eprtr_co2 <- function(path = "data/eprtr_facilities.csv") {
  check_file(path)
  dt <- data.table::fread(path)

  # Filtrar solo emisiones de CO2 al aire con coordenadas validas
  co2 <- dt[
    pollutant == "Carbon dioxide (CO2 - excluding biomass)" &
    medium == "Air" &
    !is.na(longitude) & !is.na(latitude) &
    totalQuantity > 0
  ]

  cat(sprintf("E-PRTR CO2: %d instalaciones cargadas\n", nrow(co2)))
  co2
}

#' Convertir datos E-PRTR a objeto sf
eprtr_to_sf <- function(dt, crs = 4326) {
  sf::st_as_sf(dt, coords = c("longitude", "latitude"), crs = crs)
}

#' Cargar limites NUTS
load_nuts <- function(level = 2, path = NULL) {
  if (is.null(path)) {
    path <- sprintf("data/nuts/NUTS_RG_01M_2024_%s.geojson",
                    formatC(level, width = 0))
    # Fallback a otros formatos
    if (!file.exists(path)) {
      path <- sprintf("data/nuts/NUTS_RG_01M_2021_%d_4326.geojson", level)
    }
  }
  check_file(path)
  nuts <- sf::st_read(path, quiet = TRUE)
  cat(sprintf("NUTS nivel %d: %d regiones cargadas\n", level, nrow(nuts)))
  nuts
}

#' Tema de mapa limpio para ggplot2
theme_map <- function() {
  ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text = ggplot2::element_blank(),
      axis.title = ggplot2::element_blank(),
      panel.grid = ggplot2::element_line(color = "grey95"),
      legend.position = "right"
    )
}
