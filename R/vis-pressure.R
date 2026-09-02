# Plantar-pressure visualization

#' Convert a pressure map to plotting data
#' @keywords internal
#' @noRd
.pressure_map_data <- function(map, pm, label = NULL) {
  grid <- expand.grid(
    row = seq_len(pm$nrow_grid),
    col = seq_len(pm$ncol_grid)
  )
  grid$value <- as.vector(map)
  if (!is.null(label)) {
    grid$stance_pct <- label
  }
  grid
}


#' Plot a plantar-pressure map
#'
#' Renders peak, mean, pressure-time-integral, or individual-frame pressure.
#' For `type = "frame"`, omitting `frame` selects the peak-total-pressure frame.
#' Supplying `n_facets` explicitly while omitting `frame` instead displays
#' peak-pressure maps over equal stance windows.
#'
#' @param pm A `pressure_movie`.
#' @param type Map aggregation: `"peak"`, `"mean"`, `"pti"`, or `"frame"`.
#' @param frame Frame index for `type = "frame"`.
#' @param n_facets Number of stance windows when explicitly supplied for a
#'   faceted frame plot.
#' @param contact_threshold Values at or below this pressure are not drawn.
#' @param palette Viridis palette name/option, a single high-end colour, or a
#'   vector of gradient colours.
#' @param flip_ap Logical; reverse the displayed anteroposterior axis.
#'
#' @return A `ggplot` object.
#'
#' @export
#'
#' @examples
#' x <- array(runif(4 * 3 * 10), c(4, 3, 10))
#' plotPressureMap(pressureMovie(x, 100, dx = 5, dy = 5))
plotPressureMap <- function(pm,
                            type = c("peak", "mean", "pti", "frame"),
                            frame = NULL,
                            n_facets = 6L,
                            contact_threshold = 0,
                            palette = "viridis",
                            flip_ap = FALSE) {
  pm <- .pressure_validate_movie(pm)
  type <- match.arg(type)
  contact_threshold <- .pressure_scalar(
    contact_threshold, "contact_threshold", 0, inclusive = TRUE
  )
  if (!is.logical(flip_ap) || length(flip_ap) != 1L || is.na(flip_ap)) {
    stop("flip_ap must be TRUE or FALSE.", call. = FALSE)
  }
  facet_stance <- identical(type, "frame") &&
    is.null(frame) && !missing(n_facets)

  fill_label <- switch(
    type,
    peak = paste0("Peak pressure\n(", pm$units, ")"),
    mean = paste0("Mean pressure\n(", pm$units, ")"),
    pti = paste0("PTI\n(", pm$units, "-s)"),
    frame = paste0("Pressure\n(", pm$units, ")")
  )
  title <- switch(
    type,
    peak = "Peak plantar pressure",
    mean = "Mean plantar pressure",
    pti = "Pressure-time integral",
    frame = "Plantar pressure"
  )

  if (facet_stance) {
    if (!is.numeric(n_facets) || length(n_facets) != 1L ||
        !is.finite(n_facets) || n_facets < 1 ||
        n_facets != as.integer(n_facets)) {
      stop("n_facets must be a positive integer.", call. = FALSE)
    }
    n_windows <- min(as.integer(n_facets), pm$n_frames)
    group <- cut(
      seq_len(pm$n_frames),
      breaks = seq(0, pm$n_frames, length.out = n_windows + 1L),
      include.lowest = TRUE,
      labels = FALSE
    )
    plot_data <- do.call(
      rbind,
      lapply(seq_len(n_windows), function(i) {
        indices <- which(group == i)
        map <- apply(
          pm$pressure[, , indices, drop = FALSE],
          c(1L, 2L),
          max
        )
        label <- sprintf(
          "%d-%d%%",
          round(100 * (min(indices) - 1L) / pm$n_frames),
          round(100 * max(indices) / pm$n_frames)
        )
        .pressure_map_data(map, pm, label)
      })
    )
    plot_data$stance_pct <- factor(
      plot_data$stance_pct,
      levels = unique(plot_data$stance_pct)
    )
    title <- "Plantar pressure over stance"
  } else {
    map <- switch(
      type,
      peak = peakPressure(pm, contact_threshold = contact_threshold),
      mean = apply(pm$pressure, c(1L, 2L), mean),
      pti = pressureTimeIntegral(pm),
      frame = {
        if (is.null(frame)) {
          frame <- which.max(apply(pm$pressure, 3L, sum))
        }
        if (!is.numeric(frame) || length(frame) != 1L ||
            !is.finite(frame) || frame != as.integer(frame) ||
            frame < 1L || frame > pm$n_frames) {
          stop("frame must be an integer index within the movie.",
               call. = FALSE)
        }
        pm$pressure[, , as.integer(frame)]
      }
    )
    plot_data <- .pressure_map_data(map, pm)
    if (identical(type, "frame")) {
      title <- sprintf("%s (frame %d)", title, as.integer(frame))
    }
  }
  if (type %in% c("mean", "pti")) {
    active <- peakPressure(
      pm, contact_threshold = contact_threshold
    ) > contact_threshold
    plot_data$value[!as.vector(active)] <- NA_real_
  } else {
    plot_data$value[plot_data$value <= contact_threshold] <- NA_real_
  }

  plot <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = .data$col, y = .data$row, fill = .data$value)
  ) +
    ggplot2::geom_raster() +
    ggplot2::labs(
      x = "Mediolateral position (mm)",
      y = "Anteroposterior position (mm)",
      fill = fill_label,
      title = title
    ) +
    ggplot2::scale_x_continuous(
      breaks = seq_len(pm$ncol_grid),
      labels = (seq_len(pm$ncol_grid) - 0.5) * pm$dx,
      expand = c(0, 0)
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(panel.grid = ggplot2::element_blank()) +
    ggplot2::coord_fixed(ratio = pm$dy / pm$dx)

  y_scale <- list(
    breaks = seq_len(pm$nrow_grid),
    labels = (seq_len(pm$nrow_grid) - 0.5) * pm$dy,
    expand = c(0, 0)
  )
  if (flip_ap) {
    plot <- plot + do.call(ggplot2::scale_y_reverse, y_scale)
  } else {
    plot <- plot + do.call(ggplot2::scale_y_continuous, y_scale)
  }

  viridis_options <- c(
    viridis = "D", magma = "A", inferno = "B", plasma = "C",
    cividis = "E", rocket = "F", mako = "G", turbo = "H"
  )
  if (is.character(palette) && length(palette) == 1L &&
      palette %in% names(viridis_options)) {
    plot <- plot + ggplot2::scale_fill_viridis_c(
      option = unname(viridis_options[palette]),
      na.value = "transparent"
    )
  } else if (is.character(palette) && length(palette) >= 2L) {
    plot <- plot + ggplot2::scale_fill_gradientn(
      colours = palette,
      na.value = "transparent"
    )
  } else if (is.character(palette) && length(palette) == 1L &&
             !is.na(palette)) {
    tryCatch(
      grDevices::col2rgb(palette),
      error = function(e) {
        stop("palette must contain valid colour specifications.",
             call. = FALSE)
      }
    )
    plot <- plot + ggplot2::scale_fill_gradient(
      low = "white", high = palette, na.value = "transparent"
    )
  } else {
    stop("palette must be a palette name or character colour vector.",
         call. = FALSE)
  }

  if (facet_stance) {
    plot <- plot + ggplot2::facet_wrap(
      ggplot2::vars(.data$stance_pct),
      ncol = min(3L, n_windows)
    )
  }
  plot
}
