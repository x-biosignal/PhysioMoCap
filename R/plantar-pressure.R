# Plantar-pressure analysis

#' Validate a pressure-movie scalar
#' @keywords internal
#' @noRd
.pressure_scalar <- function(x, name, lower = 0, inclusive = FALSE) {
  valid <- is.numeric(x) && length(x) == 1L && is.finite(x)
  if (valid) {
    valid <- if (inclusive) x >= lower else x > lower
  }
  if (!valid) {
    relation <- if (inclusive) "at least" else "greater than"
    stop(sprintf("%s must be a finite number %s %s.",
                 name, relation, format(lower)), call. = FALSE)
  }
  as.numeric(x)
}


#' Validate a pressure movie
#' @keywords internal
#' @noRd
.pressure_validate_movie <- function(pm) {
  if (!inherits(pm, "pressure_movie") ||
      !is.array(pm$pressure) ||
      length(dim(pm$pressure)) != 3L ||
      !is.numeric(pm$pressure)) {
    stop("pm must be a pressure_movie object.", call. = FALSE)
  }
  if (any(!is.finite(pm$pressure)) || any(pm$pressure < 0)) {
    stop("pm contains invalid pressure values.", call. = FALSE)
  }
  pm
}


#' Construct a plantar-pressure movie
#'
#' Creates a compact representation of a pressure-sensor grid sampled over
#' time. Pressure values are expected in kPa, and grid pitch is expressed in
#' mm. Negative sensor values are clamped to zero.
#'
#' @param pressure Numeric three-dimensional array with dimensions grid row by
#'   grid column by frame, or a list of equal-dimension numeric matrices.
#' @param sampling_rate Sampling frequency in Hz.
#' @param dx,dy Sensor-cell pitch in the mediolateral and anteroposterior
#'   directions, respectively, in mm.
#' @param side Optional foot side, `"left"`, `"right"`, or `NA`.
#' @param units Pressure units recorded in the source data. Calculations assume
#'   kPa.
#' @param heel_first Logical; whether grid row 1 is the posterior (heel) end.
#'
#' @return A `pressure_movie` object.
#'
#' @references
#' Pataky TC (2012). Spatial resolution in plantar pressure measurement
#' revisited. *Journal of Biomechanics*, 45:2116-2124.
#'
#' @export
#'
#' @examples
#' x <- array(0, dim = c(4, 3, 10))
#' x[2, 2, ] <- 100
#' pressureMovie(x, sampling_rate = 100, dx = 5, dy = 5)
pressureMovie <- function(pressure,
                          sampling_rate,
                          dx = 1,
                          dy = 1,
                          side = NA_character_,
                          units = "kPa",
                          heel_first = TRUE) {
  if (is.list(pressure) && !is.array(pressure)) {
    if (length(pressure) < 1L ||
        any(!vapply(pressure, is.matrix, logical(1))) ||
        any(!vapply(pressure, is.numeric, logical(1)))) {
      stop("pressure must be a numeric 3-D array or a non-empty list of numeric matrices.",
           call. = FALSE)
    }
    dimensions <- lapply(pressure, dim)
    if (!all(vapply(dimensions, identical, logical(1), dimensions[[1L]]))) {
      stop("All pressure-frame matrices must have equal dimensions.",
           call. = FALSE)
    }
    if (any(dimensions[[1L]] < 1L)) {
      stop("Pressure frames must have at least one row and one column.",
           call. = FALSE)
    }
    stacked <- array(
      NA_real_,
      dim = c(dimensions[[1L]], length(pressure))
    )
    for (i in seq_along(pressure)) {
      stacked[, , i] <- pressure[[i]]
    }
    pressure <- stacked
  }

  if (!is.array(pressure) || !is.numeric(pressure) ||
      length(dim(pressure)) != 3L || any(dim(pressure) < 1L)) {
    stop("pressure must be a numeric 3-D array or a non-empty list of numeric matrices.",
         call. = FALSE)
  }
  if (any(!is.finite(pressure))) {
    stop("pressure must contain only finite values.", call. = FALSE)
  }

  sampling_rate <- .pressure_scalar(sampling_rate, "sampling_rate")
  dx <- .pressure_scalar(dx, "dx")
  dy <- .pressure_scalar(dy, "dy")
  if (!is.character(side) || length(side) != 1L ||
      (!is.na(side) && !side %in% c("left", "right"))) {
    stop("side must be \"left\", \"right\", or NA.", call. = FALSE)
  }
  if (!is.character(units) || length(units) != 1L ||
      is.na(units) || !nzchar(units)) {
    stop("units must be a non-empty character scalar.", call. = FALSE)
  }
  if (!is.logical(heel_first) || length(heel_first) != 1L ||
      is.na(heel_first)) {
    stop("heel_first must be TRUE or FALSE.", call. = FALSE)
  }

  if (any(pressure < 0)) {
    warning("Negative pressure values were clamped to zero.", call. = FALSE)
    pressure[pressure < 0] <- 0
  }
  storage.mode(pressure) <- "double"
  dimensions <- dim(pressure)

  out <- list(
    pressure = pressure,
    sampling_rate = sampling_rate,
    dx = dx,
    dy = dy,
    cell_area = dx * dy,
    side = side,
    units = units,
    heel_first = heel_first,
    n_frames = as.integer(dimensions[3L]),
    nrow_grid = as.integer(dimensions[1L]),
    ncol_grid = as.integer(dimensions[2L]),
    duration = (dimensions[3L] - 1) / sampling_rate
  )
  class(out) <- "pressure_movie"
  out
}


#' @export
print.pressure_movie <- function(x, ...) {
  side <- if (is.na(x$side)) "unspecified side" else x$side
  cat(sprintf(
    "<pressure_movie> %d x %d cells, %d frames at %.4g Hz (%s)\n",
    x$nrow_grid, x$ncol_grid, x$n_frames, x$sampling_rate, side
  ))
  cat(sprintf(
    "  pitch: %.4g x %.4g mm  duration: %.4g s  pressure: %s\n",
    x$dx, x$dy, x$duration, x$units
  ))
  invisible(x)
}


#' Read a plantar-pressure ASCII export
#'
#' Reads frame-delimited Novel/Tekscan-style text exports. Comment metadata
#' may define `sampling_rate` (or `fs`), `dx`, `dy`, `side`, and `units`.
#' Explicit function arguments take precedence over file metadata.
#'
#' @param file Path to an ASCII pressure export.
#' @param sampling_rate,dx,dy Optional overrides for file metadata.
#' @param side Optional side override.
#' @param units Pressure-unit override. When omitted, file metadata is used,
#'   falling back to `"kPa"`.
#' @param heel_first Logical; whether row 1 represents the heel.
#' @param frame_marker Regular expression identifying frame-header lines.
#' @param comment Literal prefix identifying metadata/comment lines.
#'
#' @return A `pressure_movie` object.
#'
#' @export
#'
#' @examples
#' f <- tempfile(fileext = ".txt")
#' writeLines(c("# sampling_rate 100", "Frame 0", "1 2", "3 4"), f)
#' readPressureFrame(f)
#' unlink(f)
readPressureFrame <- function(file,
                              sampling_rate = NULL,
                              dx = NULL,
                              dy = NULL,
                              side = NA_character_,
                              units = "kPa",
                              heel_first = TRUE,
                              frame_marker = "^\\s*(Frame|ASCII_DATA|Time)",
                              comment = "#") {
  units_missing <- missing(units)
  side_missing <- missing(side)
  if (!is.character(file) || length(file) != 1L || is.na(file)) {
    stop("file must be a single path.", call. = FALSE)
  }
  if (!is.character(frame_marker) || length(frame_marker) != 1L ||
      is.na(frame_marker) || !nzchar(frame_marker)) {
    stop("frame_marker must be a non-empty regular expression.",
         call. = FALSE)
  }
  if (!is.character(comment) || length(comment) != 1L ||
      is.na(comment) || !nzchar(comment)) {
    stop("comment must be a non-empty character scalar.", call. = FALSE)
  }

  lines <- readLines(file, warn = FALSE)
  metadata <- list()
  frames <- list()
  current <- list()

  flush_frame <- function() {
    if (length(current) == 0L) {
      return(invisible(NULL))
    }
    widths <- lengths(current)
    frame_number <- length(frames) + 1L
    if (length(unique(widths)) != 1L) {
      stop(sprintf("Pressure frame %d has ragged rows.", frame_number),
           call. = FALSE)
    }
    frame <- matrix(
      unlist(current, use.names = FALSE),
      nrow = length(current),
      byrow = TRUE
    )
    frames[[frame_number]] <<- frame
    current <<- list()
    invisible(NULL)
  }

  for (line in lines) {
    trimmed <- trimws(line)
    if (!nzchar(trimmed)) {
      next
    }
    if (startsWith(trimmed, comment)) {
      entry <- trimws(substring(trimmed, nchar(comment) + 1L))
      tokens <- strsplit(entry, "[[:space:]:=]+", perl = TRUE)[[1L]]
      tokens <- tokens[nzchar(tokens)]
      if (length(tokens) >= 2L) {
        key <- tolower(tokens[1L])
        if (key %in% c("sampling_rate", "fs", "dx", "dy", "side", "units")) {
          metadata[[key]] <- tokens[2L]
        }
      }
      next
    }
    if (grepl(frame_marker, line, perl = TRUE)) {
      flush_frame()
      next
    }

    tokens <- strsplit(trimmed, "[,;[:space:]]+", perl = TRUE)[[1L]]
    values <- suppressWarnings(as.numeric(tokens))
    if (length(values) > 0L && all(is.finite(values))) {
      current[[length(current) + 1L]] <- values
    }
  }
  flush_frame()

  if (length(frames) == 0L) {
    stop("No pressure frames found.", call. = FALSE)
  }
  frame_dims <- lapply(frames, dim)
  if (!all(vapply(frame_dims, identical, logical(1), frame_dims[[1L]]))) {
    bad <- which(!vapply(frame_dims, identical, logical(1), frame_dims[[1L]]))[1L]
    stop(sprintf("Pressure frame %d has dimensions inconsistent with frame 1.",
                 bad), call. = FALSE)
  }

  metadata_sampling_rate <- metadata$sampling_rate
  if (is.null(metadata_sampling_rate)) {
    metadata_sampling_rate <- metadata$fs
  }
  resolve_numeric <- function(argument, metadata_value, fallback = NULL) {
    if (!is.null(argument)) {
      return(argument)
    }
    if (!is.null(metadata_value)) {
      return(suppressWarnings(as.numeric(metadata_value)))
    }
    fallback
  }

  sampling_rate <- resolve_numeric(
    sampling_rate, metadata_sampling_rate, NULL
  )
  dx <- resolve_numeric(dx, metadata$dx, 1)
  dy <- resolve_numeric(dy, metadata$dy, 1)
  if (side_missing || (length(side) == 1L && is.na(side))) {
    side <- if (is.null(metadata$side)) NA_character_ else tolower(metadata$side)
  }
  if (units_missing) {
    units <- if (is.null(metadata$units)) "kPa" else metadata$units
  }

  pressureMovie(
    frames,
    sampling_rate = sampling_rate,
    dx = dx,
    dy = dy,
    side = side,
    units = units,
    heel_first = heel_first
  )
}


#' Calculate a peak plantar-pressure map
#'
#' @param pm A `pressure_movie`.
#' @param contact_threshold Pressure threshold in kPa. Cells must exceed this
#'   threshold to count toward contact area and mean pressure.
#'
#' @return A numeric peak-pressure matrix in kPa. Attributes contain the
#'   global peak, peak cell and frame, contact area, and mean active pressure.
#'
#' @references
#' Rosenbaum D, Becker H-P (1997). Plantar pressure distribution measurements.
#' *Foot and Ankle Surgery*, 3:1-14.
#'
#' @export
#'
#' @examples
#' pm <- pressureMovie(array(1:12, c(2, 2, 3)), 100)
#' peakPressure(pm)
peakPressure <- function(pm, contact_threshold = 0) {
  pm <- .pressure_validate_movie(pm)
  contact_threshold <- .pressure_scalar(
    contact_threshold, "contact_threshold", 0, inclusive = TRUE
  )

  peak_map <- apply(pm$pressure, c(1L, 2L), max)
  peak <- max(peak_map)
  peak_cell <- which(peak_map == peak, arr.ind = TRUE)[1L, ]
  peak_frame <- which.max(
    pm$pressure[peak_cell[1L], peak_cell[2L], ]
  )
  active <- peak_map > contact_threshold
  active_pressure <- pm$pressure[pm$pressure > contact_threshold]

  attr(peak_map, "peak") <- peak
  attr(peak_map, "peak_cell") <- peak_cell
  attr(peak_map, "peak_frame") <- as.integer(peak_frame)
  attr(peak_map, "contact_area") <- sum(active) * pm$cell_area
  attr(peak_map, "mean_pressure") <- if (length(active_pressure) > 0L) {
    mean(active_pressure)
  } else {
    NA_real_
  }
  peak_map
}


#' Calculate the plantar pressure-time integral
#'
#' Uses trapezoidal integration over the sampled duration. The force-time
#' integral converts kPa times mm-squared to N using `force_factor`.
#'
#' @param pm A `pressure_movie`.
#' @param force_factor Conversion from pressure times cell area to force.
#'   The default `1e-3` converts kPa times mm-squared to N; use `0.1` for
#'   kPa times cm-squared.
#'
#' @return A numeric matrix of pressure-time integrals in kPa-s. Attribute
#'   `"fti"` is the total force-time integral in N-s.
#'
#' @export
#'
#' @examples
#' pm <- pressureMovie(array(100, c(2, 2, 11)), 100, dx = 5, dy = 5)
#' pressureTimeIntegral(pm)
pressureTimeIntegral <- function(pm, force_factor = 1e-3) {
  pm <- .pressure_validate_movie(pm)
  force_factor <- .pressure_scalar(force_factor, "force_factor")
  dt <- 1 / pm$sampling_rate
  pti <- apply(
    pm$pressure,
    c(1L, 2L),
    function(values) .trapz(values, dt)
  )
  total_force <- apply(pm$pressure, 3L, sum) *
    pm$cell_area * force_factor
  attr(pti, "fti") <- .trapz(total_force, dt)
  pti
}


#' Summarize plantar loading by anatomical region
#'
#' Partitions the active footprint along its anteroposterior extent using
#' cumulative Cavanagh-style region bounds.
#'
#' @param pm A `pressure_movie`.
#' @param statistic Regional statistic: force-time integral, peak force, or
#'   mean force.
#' @param regions Named, strictly increasing cumulative upper bounds ending at
#'   1. Defaults to rearfoot, midfoot, forefoot, and toes.
#' @param contact_threshold Pressure threshold in kPa defining loaded cells.
#' @param force_factor Conversion from pressure times cell area to force.
#'
#' @return A `regional_loading` data frame with one row per region. Attributes
#'   contain the regional total and selected statistic.
#'
#' @references
#' Cavanagh PR, Rodgers MM, Iiboshi A (1987). Pressure distribution under
#' symptom-free feet during barefoot standing. *Foot and Ankle*, 7:262-276.
#'
#' @export
#'
#' @examples
#' pm <- pressureMovie(array(100, c(10, 4, 11)), 100, dx = 5, dy = 5)
#' regionalLoading(pm)
regionalLoading <- function(
    pm,
    statistic = c("fti", "peak_force", "mean_force"),
    regions = c(rearfoot = 0.30, midfoot = 0.60,
                forefoot = 0.80, toes = 1.00),
    contact_threshold = 0,
    force_factor = 1e-3) {
  pm <- .pressure_validate_movie(pm)
  statistic <- match.arg(statistic)
  contact_threshold <- .pressure_scalar(
    contact_threshold, "contact_threshold", 0, inclusive = TRUE
  )
  force_factor <- .pressure_scalar(force_factor, "force_factor")
  if (!is.numeric(regions) || length(regions) < 1L ||
      is.null(names(regions)) ||
      any(is.na(names(regions)) | !nzchar(names(regions))) ||
      anyDuplicated(names(regions)) ||
      any(!is.finite(regions)) ||
      regions[1L] <= 0 || any(diff(regions) <= 0) ||
      abs(regions[length(regions)] - 1) > sqrt(.Machine$double.eps)) {
    stop("regions must be named, strictly increasing bounds ending at 1.",
         call. = FALSE)
  }

  peak_map <- peakPressure(pm, contact_threshold = contact_threshold)
  active <- which(peak_map > contact_threshold, arr.ind = TRUE)
  cell_values <- switch(
    statistic,
    fti = pressureTimeIntegral(pm, force_factor = force_factor) *
      pm$cell_area * force_factor,
    peak_force = peak_map * pm$cell_area * force_factor,
    mean_force = apply(pm$pressure, c(1L, 2L), mean) *
      pm$cell_area * force_factor
  )
  grand_total <- sum(cell_values)

  region_names <- names(regions)
  values <- setNames(numeric(length(regions)), region_names)
  region_peak <- setNames(numeric(length(regions)), region_names)
  contact_area <- setNames(numeric(length(regions)), region_names)
  n_cells <- setNames(integer(length(regions)), region_names)

  if (nrow(active) > 0L) {
    ap_row <- active[, "row"]
    lo <- min(ap_row)
    hi <- max(ap_row)
    fraction <- if (hi > lo) {
      (ap_row - lo) / (hi - lo)
    } else {
      rep(0, length(ap_row))
    }
    if (!pm$heel_first) {
      fraction <- 1 - fraction
    }
    region_id <- cut(
      fraction,
      breaks = c(0, unname(regions)),
      labels = region_names,
      include.lowest = TRUE,
      right = FALSE
    )
    if (anyNA(region_id)) {
      stop("Internal error while assigning plantar-pressure regions.",
           call. = FALSE)
    }

    for (region in region_names) {
      positions <- which(region_id == region)
      if (length(positions) == 0L) {
        next
      }
      cells <- active[positions, , drop = FALSE]
      linear <- cbind(cells[, "row"], cells[, "col"])
      values[region] <- sum(cell_values[linear])
      region_peak[region] <- max(peak_map[linear])
      n_cells[region] <- length(positions)
      contact_area[region] <- length(positions) * pm$cell_area
    }
  }

  pct_total <- if (is.na(grand_total)) {
    rep(NA_real_, length(values))
  } else if (grand_total == 0) {
    numeric(length(values))
  } else {
    100 * values / grand_total
  }
  out <- data.frame(
    region = region_names,
    value = unname(values),
    pct_total = unname(pct_total),
    peak_pressure = unname(region_peak),
    contact_area = unname(contact_area),
    n_cells = unname(n_cells),
    stringsAsFactors = FALSE
  )
  attr(out, "total") <- sum(values)
  attr(out, "statistic") <- statistic
  class(out) <- c("regional_loading", "data.frame")
  out
}


#' @export
print.regional_loading <- function(x, ...) {
  cat(sprintf(
    "<regional_loading> statistic=%s, total=%.4g\n",
    attr(x, "statistic"), attr(x, "total")
  ))
  print.data.frame(x, row.names = FALSE, ...)
  invisible(x)
}


#' Derive center of pressure from a pressure movie
#'
#' Computes the pressure-weighted centroid at each frame. Grid columns define
#' the mediolateral (`cop_x`) direction and rows define the anteroposterior
#' (`cop_y`) direction, matching [calculateCOP()] and [swayMetrics()].
#'
#' @param pm A `pressure_movie`.
#' @param contact_threshold Pressure threshold in kPa. Values at or below the
#'   threshold do not contribute to force or center of pressure.
#'
#' @return A data frame with `time`, `cop_x`, `cop_y`, `total_force`, and
#'   `contact_area`. CoP coordinates are in mm and force is in N.
#'
#' @references
#' Pataky TC (2012). Spatial resolution in plantar pressure measurement
#' revisited. *Journal of Biomechanics*, 45:2116-2124.
#'
#' @seealso [swayMetrics()], [calculateCOP()]
#'
#' @export
#'
#' @examples
#' x <- array(0, c(3, 3, 2))
#' x[2, 3, ] <- 100
#' copFromPressure(pressureMovie(x, 100, dx = 5, dy = 5))
copFromPressure <- function(pm, contact_threshold = 0) {
  pm <- .pressure_validate_movie(pm)
  contact_threshold <- .pressure_scalar(
    contact_threshold, "contact_threshold", 0, inclusive = TRUE
  )
  pressure <- pm$pressure
  pressure[pressure <= contact_threshold] <- 0

  x <- (seq_len(pm$ncol_grid) - 0.5) * pm$dx
  y <- (seq_len(pm$nrow_grid) - 0.5) * pm$dy
  x_grid <- matrix(
    rep(x, each = pm$nrow_grid),
    nrow = pm$nrow_grid,
    ncol = pm$ncol_grid
  )
  y_grid <- matrix(
    rep(y, pm$ncol_grid),
    nrow = pm$nrow_grid,
    ncol = pm$ncol_grid
  )

  total_pressure <- apply(pressure, 3L, sum)
  cop_x <- rep(NA_real_, pm$n_frames)
  cop_y <- rep(NA_real_, pm$n_frames)
  valid <- total_pressure > 0
  if (any(valid)) {
    frame_x <- vapply(
      seq_len(pm$n_frames),
      function(i) sum(pressure[, , i] * x_grid),
      numeric(1)
    )
    frame_y <- vapply(
      seq_len(pm$n_frames),
      function(i) sum(pressure[, , i] * y_grid),
      numeric(1)
    )
    cop_x[valid] <- frame_x[valid] / total_pressure[valid]
    cop_y[valid] <- frame_y[valid] / total_pressure[valid]
  }
  contact_area <- vapply(
    seq_len(pm$n_frames),
    function(i) sum(pressure[, , i] > 0) * pm$cell_area,
    numeric(1)
  )

  data.frame(
    time = (seq_len(pm$n_frames) - 1) / pm$sampling_rate,
    cop_x = cop_x,
    cop_y = cop_y,
    total_force = total_pressure * pm$cell_area * 1e-3,
    contact_area = contact_area
  )
}


#' Compare left and right plantar pressure
#'
#' Calculates the signed Robinson symmetry index:
#' \deqn{100 (L-R) / ((L+R)/2).}
#'
#' @param left,right Left and right `pressure_movie` objects.
#' @param metric Scalar metric to compare.
#' @param force_factor Conversion from pressure times cell area to force.
#'
#' @return A `pressure_asymmetry` object containing side values, signed and
#'   absolute symmetry indices, and the left/right ratio.
#'
#' @references
#' Robinson RO, Herzog W, Nigg BM (1987). Use of force platform variables to
#' quantify the effects of chiropractic manipulation on gait symmetry.
#' *Journal of Manipulative and Physiological Therapeutics*, 10:172-176.
#'
#' @export
#'
#' @examples
#' left <- pressureMovie(array(100, c(3, 3, 5)), 100, side = "left")
#' right <- pressureMovie(array(80, c(3, 3, 5)), 100, side = "right")
#' pressureAsymmetry(left, right)
pressureAsymmetry <- function(
    left,
    right,
    metric = c("peak_pressure", "pti", "contact_area", "total_force"),
    force_factor = 1e-3) {
  left <- .pressure_validate_movie(left)
  right <- .pressure_validate_movie(right)
  metric <- match.arg(metric)
  force_factor <- .pressure_scalar(force_factor, "force_factor")

  extract_metric <- function(pm) {
    switch(
      metric,
      peak_pressure = attr(peakPressure(pm), "peak"),
      pti = attr(
        pressureTimeIntegral(pm, force_factor = force_factor),
        "fti"
      ),
      contact_area = attr(peakPressure(pm), "contact_area"),
      total_force = max(
        apply(pm$pressure, 3L, sum) * pm$cell_area * force_factor
      )
    )
  }
  left_value <- extract_metric(left)
  right_value <- extract_metric(right)
  denominator <- 0.5 * (left_value + right_value)
  symmetry_index <- if (is.na(denominator) || denominator == 0) {
    NA_real_
  } else {
    100 * (left_value - right_value) / denominator
  }

  out <- list(
    metric = metric,
    left = left_value,
    right = right_value,
    symmetry_index = symmetry_index,
    abs_symmetry_index = abs(symmetry_index),
    ratio = left_value / right_value
  )
  class(out) <- "pressure_asymmetry"
  out
}


#' @export
print.pressure_asymmetry <- function(x, ...) {
  cat(sprintf("<pressure_asymmetry> metric=%s\n", x$metric))
  cat(sprintf(
    "  left: %.4g  right: %.4g  SI: %.4g%%  |SI|: %.4g%%\n",
    x$left, x$right, x$symmetry_index, x$abs_symmetry_index
  ))
  invisible(x)
}
