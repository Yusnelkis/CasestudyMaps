# =============================================================================
# utils.R — Funciones auxiliares compartidas
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
#'
#' @param plot Objeto ggplot o tmap
#' @param filename Nombre del archivo (sin ruta)
#' @param width Ancho en pulgadas (default 10)
#' @param height Alto en pulgadas (default 8)
save_plot <- function(plot, filename, width = 10, height = 8) {
  filepath <- file.path("output", filename)
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
    stop("Archivo no encontrado: ", path)
  }
  invisible(path)
}
