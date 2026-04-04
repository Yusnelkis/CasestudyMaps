# =============================================================================
# theme.R — Paleta de colores y estilos de visualizacion
# =============================================================================
# Inspirado en imagen satelital falso color (infrarrojo cercano)
# Fuente: https://es.pinterest.com/pin/42221315226561718/

# =============================================================================
# PALETA DE COLORES
# =============================================================================

# --- Colores principales (extraidos de la imagen satelital) ---

palette_satellite <- list(

  # Azules profundos (oceano, rios, agua)
  navy_deep    = "#0B1045",    # Oceano profundo
  navy         = "#0C1654",    # Agua oscura
  blue_river   = "#1E3FA0",    # Cauces principales
  blue_bright  = "#2B5CE6",    # Agua clara/rios


  # Cyan/turquesa (costas, agua somera, humedales)
  cyan_dark    = "#2ABFB3",    # Humedales costeros
  cyan         = "#4DE0D4",    # Agua somera
  cyan_light   = "#7AEEE6",    # Zonas intertidales

  # Verdes (vegetacion densa)
  green_lime   = "#6DE629",    # Vegetacion muy activa
  green_bright = "#4DC82A",    # Vegetacion vigorosa
  green_mid    = "#3DA040",    # Bosque/vegetacion media
  green_dark   = "#2D7A30",    # Vegetacion densa

  # Oliva/khaki (vegetacion seca, suelos)
  olive        = "#8A9A5A",    # Vegetacion seca
  khaki        = "#A8AA60",    # Cultivos/pastizales
  tan          = "#C0B080",    # Suelo expuesto

  # Magenta/fucsia (areas agricolas, suelo desnudo en IR)
  magenta      = "#E040A0",    # Agricultura activa
  pink         = "#E880B0",    # Suelo/cultivos
  fuchsia      = "#D93D8F",    # Parcelas agricolas
  pink_light   = "#F0A0C8"    # Areas claras
)

# --- Paletas funcionales para el proyecto ------------------------------------

# Secuencial: para mapas de emisiones (bajo -> alto)
pal_emissions <- c(
  "#0C1654",   # navy (emisiones muy bajas)
  "#1E3FA0",   # blue
  "#2ABFB3",   # cyan
  "#4DC82A",   # green
  "#A8AA60",   # khaki
  "#E040A0",   # magenta
  "#D93D8F"    # fuchsia (emisiones muy altas)
)

# Secuencial calida: para intensidad de emisiones
pal_emissions_warm <- c(
  "#0B1045",   # navy deep
  "#1E3FA0",   # blue
  "#3DA040",   # green
  "#E880B0",   # pink
  "#E040A0",   # magenta
  "#D93D8F"    # fuchsia
)

# Divergente: para comparar vs. media/umbral
pal_divergent <- c(
  "#1E3FA0",   # blue (bajo)
  "#2ABFB3",   # cyan
  "#4DE0D4",   # cyan light
  "#FFFFFF",   # blanco (neutro)
  "#E880B0",   # pink
  "#E040A0",   # magenta
  "#D93D8F"    # fuchsia (alto)
)

# Categorica: para sectores industriales
pal_sectors <- c(
  "#1E3FA0",   # blue — Energia
  "#2ABFB3",   # cyan — Quimica
  "#4DC82A",   # green — Manufactura
  "#6DE629",   # lime — Alimentacion
  "#A8AA60",   # khaki — Mineria
  "#E040A0",   # magenta — Residuos
  "#D93D8F",   # fuchsia — Metalurgia
  "#0C1654",   # navy — Cemento
  "#C0B080",   # tan — Papel
  "#E880B0"    # pink — Otros
)

# Fondo de mapa
col_ocean      <- "#0B1045"
col_land       <- "#F5F2ED"
col_borders    <- "#8A9A5A"
col_text       <- "#0C1654"
col_text_light <- "#6A7080"

# =============================================================================
# FUNCIONES DE COLOR
# =============================================================================

#' Generar paleta interpolada de n colores
#' @param n Numero de colores
#' @param palette Una de: "emissions", "warm", "divergent", "sectors"
pal_casestudy <- function(n, palette = "emissions") {
  pal <- switch(palette,
    "emissions" = pal_emissions,
    "warm"      = pal_emissions_warm,
    "divergent" = pal_divergent,
    "sectors"   = pal_sectors,
    pal_emissions
  )

  if (palette == "sectors") {
    return(rep_len(pal, n))
  }

  grDevices::colorRampPalette(pal)(n)
}

#' Scale color continua para ggplot2 (emisiones)
scale_color_emissions <- function(..., palette = "emissions") {
  pal <- switch(palette,
    "emissions" = pal_emissions,
    "warm"      = pal_emissions_warm,
    "divergent" = pal_divergent,
    pal_emissions
  )
  ggplot2::scale_color_gradientn(colours = pal, ...)
}

#' Scale fill continua para ggplot2 (emisiones)
scale_fill_emissions <- function(..., palette = "emissions") {
  pal <- switch(palette,
    "emissions" = pal_emissions,
    "warm"      = pal_emissions_warm,
    "divergent" = pal_divergent,
    pal_emissions
  )
  ggplot2::scale_fill_gradientn(colours = pal, ...)
}

#' Scale color discreta para ggplot2 (sectores)
scale_color_sectors <- function(...) {
  ggplot2::scale_color_manual(values = pal_sectors, ...)
}

#' Scale fill discreta para ggplot2 (sectores)
scale_fill_sectors <- function(...) {
  ggplot2::scale_fill_manual(values = pal_sectors, ...)
}

# =============================================================================
# TEMA GGPLOT2
# =============================================================================

#' Tema principal para mapas del proyecto
theme_satellite <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) %+replace%
    ggplot2::theme(
      # Fondo
      plot.background = ggplot2::element_rect(fill = "#FAFAF8", color = NA),
      panel.background = ggplot2::element_rect(fill = "#FAFAF8", color = NA),
      panel.grid = ggplot2::element_line(color = "#E8E6E0", linewidth = 0.3),

      # Texto
      plot.title = ggplot2::element_text(
        color = col_text, face = "bold", size = base_size * 1.3,
        margin = ggplot2::margin(b = 8)
      ),
      plot.subtitle = ggplot2::element_text(
        color = col_text_light, size = base_size * 0.9,
        margin = ggplot2::margin(b = 12)
      ),
      plot.caption = ggplot2::element_text(
        color = col_text_light, size = base_size * 0.7,
        hjust = 1, margin = ggplot2::margin(t = 10)
      ),

      # Ejes
      axis.text = ggplot2::element_text(color = col_text_light, size = base_size * 0.75),
      axis.title = ggplot2::element_text(color = col_text, size = base_size * 0.85),

      # Leyenda
      legend.title = ggplot2::element_text(color = col_text, face = "bold",
                                           size = base_size * 0.85),
      legend.text = ggplot2::element_text(color = col_text_light,
                                          size = base_size * 0.75),
      legend.key = ggplot2::element_rect(fill = "transparent", color = NA),

      # Margenes
      plot.margin = ggplot2::margin(15, 15, 15, 15)
    )
}

#' Tema para mapas (sin ejes, fondo oscuro)
theme_map_dark <- function(base_size = 12) {
  ggplot2::theme_void(base_size = base_size) %+replace%
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = col_ocean, color = NA),
      panel.background = ggplot2::element_rect(fill = col_ocean, color = NA),

      plot.title = ggplot2::element_text(
        color = "#FFFFFF", face = "bold", size = base_size * 1.3,
        margin = ggplot2::margin(b = 8)
      ),
      plot.subtitle = ggplot2::element_text(
        color = cyan_light_hex(), size = base_size * 0.9,
        margin = ggplot2::margin(b = 12)
      ),
      plot.caption = ggplot2::element_text(
        color = "#8A9AAA", size = base_size * 0.7,
        hjust = 1, margin = ggplot2::margin(t = 10)
      ),

      legend.title = ggplot2::element_text(color = "#FFFFFF", face = "bold",
                                           size = base_size * 0.85),
      legend.text = ggplot2::element_text(color = "#CCCCCC",
                                          size = base_size * 0.75),
      legend.key = ggplot2::element_rect(fill = "transparent", color = NA),
      legend.position = "right",

      plot.margin = ggplot2::margin(15, 15, 15, 15)
    )
}

# Helper para acceder al cyan claro (evitar problema de scope)
cyan_light_hex <- function() "#7AEEE6"

# =============================================================================
# PREVIEW DE LA PALETA
# =============================================================================

#' Mostrar las paletas disponibles
preview_palettes <- function() {
  cat("=== Paletas del proyecto CasestudyMaps ===\n\n")

  show_pal <- function(name, colors) {
    cat(sprintf("%-15s", name))
    for (col in colors) cat(sprintf(" %s", col))
    cat("\n")
  }

  show_pal("emissions:", pal_emissions)
  show_pal("warm:", pal_emissions_warm)
  show_pal("divergent:", pal_divergent)
  show_pal("sectors:", pal_sectors)

  # Plot visual si hay un dispositivo grafico
  if (interactive()) {
    old_par <- par(mfrow = c(4, 1), mar = c(1, 8, 2, 1))
    on.exit(par(old_par))

    plot_pal <- function(colors, name) {
      n <- length(colors)
      image(1:n, 1, as.matrix(1:n), col = colors,
            xlab = "", ylab = "", xaxt = "n", yaxt = "n", bty = "n")
      title(main = name, adj = 0, cex.main = 1)
    }

    plot_pal(pal_emissions, "Emissions (secuencial)")
    plot_pal(pal_emissions_warm, "Warm (intensidad)")
    plot_pal(pal_divergent, "Divergent (comparacion)")
    plot_pal(pal_sectors, "Sectors (categorica)")
  }
}
