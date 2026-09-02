# Force Plate Kinetics Functions
# Utilities for GRF filtering, center-of-pressure estimation, loading rate,
# and impulse metrics.

#' Low-pass filter ground reaction force data
#'
#' Applies low-pass filtering to force-plate signals. By default this uses a
#' zero-phase Butterworth filter (requires the `signal` package). If `signal`
#' is not available, the function falls back to a moving-average filter.
#'
#' @param x Numeric vector or matrix (time x channels).
#' @param sampling_rate Sampling rate in Hz.
#' @param cutoff Low-pass cutoff frequency in Hz.
#' @param order Butterworth filter order.
#' @param method Filtering method: `"butterworth"` or `"moving_average"`.
#'
#' @return Filtered data with the same dimensions as `x`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [butterworthFilter()] for general Butterworth filtering,
#'   [analyzeForcePlate()] for comprehensive force plate analysis.
#'
#' @export
#'
#' @examples
#' sr <- 1000
#' t <- seq(0, 1, length.out = sr)
#' x <- sin(2 * pi * 10 * t) + 0.2 * sin(2 * pi * 150 * t)
#' y <- filterGRF(x, sampling_rate = sr, cutoff = 25)
filterGRF <- function(x,
                      sampling_rate,
                      cutoff = 20,
                      order = 4,
                      method = c("butterworth", "moving_average")) {

  method <- match.arg(method)
  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1, sampling_rate > 0)
  stopifnot(is.numeric(cutoff), length(cutoff) == 1, cutoff > 0)
  stopifnot(is.numeric(order), length(order) == 1, order >= 1)

  if (!is.numeric(x)) {
    stop("x must be numeric.", call. = FALSE)
  }

  if (method == "butterworth") {
    if (requireNamespace("signal", quietly = TRUE)) {
      return(butterworthFilter(
        x,
        cutoff = cutoff,
        sampling_rate = sampling_rate,
        type = "lowpass",
        order = as.integer(order)
      ))
    }

    warning(
      "The 'signal' package is not installed; falling back to moving_average.",
      call. = FALSE
    )
  }

  window <- as.integer(round(sampling_rate / cutoff))
  window <- max(window, 3L)
  if (window %% 2 == 0) {
    window <- window + 1L
  }

  movingAverage(x, window = window)
}


#' Calculate center of pressure (COP) from force-plate data
#'
#' Computes COP coordinates from force and moment components using standard
#' force-plate equations (assuming a vertical Z axis).
#'
#' @param forces Matrix/data.frame with at least three columns for force
#'   components (X, Y, Z).
#' @param moments Matrix/data.frame with at least three columns for moment
#'   components (X, Y, Z).
#' @param origin Numeric length-3 vector with force-plate origin `(x, y, z)`.
#' @param min_vertical_force Minimum absolute vertical force required to compute
#'   COP (samples below this threshold are set to `NA`).
#'
#' @return A data.frame with columns `cop_x`, `cop_y`, `cop_z`,
#'   `free_moment`, and `vertical_force`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [analyzeForcePlate()] for comprehensive force plate analysis,
#'   [calculateCOM()] for whole-body center of mass computation.
#'
#' @export
#'
#' @examples
#' f <- cbind(Fx = rep(0, 10), Fy = rep(0, 10), Fz = rep(1000, 10))
#' m <- cbind(Mx = rep(100, 10), My = rep(-200, 10), Mz = rep(0, 10))
#' cop <- calculateCOP(f, m)
calculateCOP <- function(forces,
                         moments,
                         origin = c(0, 0, 0),
                         min_vertical_force = 20) {

  stopifnot(is.numeric(origin), length(origin) == 3)
  stopifnot(is.numeric(min_vertical_force), length(min_vertical_force) == 1,
            min_vertical_force >= 0)

  f_xyz <- .coerce_xyz_matrix(forces, kind = "force")
  m_xyz <- .coerce_xyz_matrix(moments, kind = "moment")

  if (nrow(f_xyz) != nrow(m_xyz)) {
    stop("forces and moments must have the same number of rows.", call. = FALSE)
  }

  fx <- f_xyz[, 1]
  fy <- f_xyz[, 2]
  fz <- f_xyz[, 3]
  mx <- m_xyz[, 1]
  my <- m_xyz[, 2]
  mz <- m_xyz[, 3]

  n <- nrow(f_xyz)
  cop_x <- rep(NA_real_, n)
  cop_y <- rep(NA_real_, n)
  cop_z <- rep(NA_real_, n)
  free_moment <- rep(NA_real_, n)

  valid <- is.finite(fz) & abs(fz) >= min_vertical_force

  # Standard plate-surface COP equations for vertical force Fz.
  cop_x[valid] <- origin[1] + (-my[valid] - fx[valid] * origin[3]) / fz[valid]
  cop_y[valid] <- origin[2] + ( mx[valid] - fy[valid] * origin[3]) / fz[valid]
  cop_z[valid] <- origin[3]

  # Free vertical moment around COP.
  free_moment[valid] <- mz[valid] -
    (cop_x[valid] - origin[1]) * fy[valid] +
    (cop_y[valid] - origin[2]) * fx[valid]

  data.frame(
    cop_x = cop_x,
    cop_y = cop_y,
    cop_z = cop_z,
    free_moment = free_moment,
    vertical_force = fz,
    stringsAsFactors = FALSE
  )
}


#' Compute vertical loading rate from GRF
#'
#' Detects stance phases from a vertical GRF signal and computes loading rate
#' from initial contact to peak force for each stance.
#'
#' @param vgrf Numeric vector or matrix of vertical GRF values.
#' @param sampling_rate Sampling rate in Hz.
#' @param threshold Contact threshold in force units.
#' @param method Loading-rate method: `"instantaneous"` (max slope) or
#'   `"average"` (peak rise over time-to-peak).
#'
#' @return For vector input: a data.frame with one row per stance.
#'   For matrix input: same data.frame with an added `channel` column.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [analyzeForcePlate()] for comprehensive force plate analysis,
#'   [computeImpulse()] for impulse computation.
#'
#' @export
#'
#' @examples
#' grf <- c(rep(0, 100), seq(0, 800, length.out = 150),
#'          seq(800, 0, length.out = 150), rep(0, 100))
#' computeLoadingRate(grf, sampling_rate = 1000)
computeLoadingRate <- function(vgrf,
                               sampling_rate,
                               threshold = 20,
                               method = c("instantaneous", "average")) {

  method <- match.arg(method)
  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1, sampling_rate > 0)
  stopifnot(is.numeric(threshold), length(threshold) == 1, threshold >= 0)

  if (is.matrix(vgrf)) {
    ch_names <- colnames(vgrf)
    if (is.null(ch_names)) {
      ch_names <- paste0("ch", seq_len(ncol(vgrf)))
    }

    out <- lapply(seq_len(ncol(vgrf)), function(j) {
      df <- .compute_loading_rate_vector(vgrf[, j], sampling_rate, threshold, method)
      if (nrow(df) > 0) {
        df$channel <- ch_names[j]
      }
      df
    })

    out <- out[vapply(out, nrow, integer(1)) > 0]
    if (length(out) == 0) {
      return(.empty_loading_rate())
    }

    res <- do.call(rbind, out)
    rownames(res) <- NULL
    return(res)
  }

  if (!is.numeric(vgrf)) {
    stop("vgrf must be a numeric vector or matrix.", call. = FALSE)
  }

  .compute_loading_rate_vector(vgrf, sampling_rate, threshold, method)
}


#' Compute vertical impulse from GRF
#'
#' Integrates vertical force over detected stance phases using trapezoidal
#' integration.
#'
#' @param force Numeric vector or matrix of vertical force values.
#' @param sampling_rate Sampling rate in Hz.
#' @param threshold Contact threshold in force units.
#' @param subtract_threshold Logical; if `TRUE`, subtracts `threshold` before
#'   integrating each stance (negative values clipped to zero).
#'
#' @return For vector input: data.frame with one row per stance and columns
#'   including `impulse` (force*time units).
#'   For matrix input: same structure plus `channel`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [analyzeForcePlate()] for comprehensive force plate analysis,
#'   [computeLoadingRate()] for loading rate computation.
#'
#' @export
#'
#' @examples
#' grf <- c(rep(0, 50), rep(600, 100), rep(0, 50))
#' computeImpulse(grf, sampling_rate = 1000)
computeImpulse <- function(force,
                           sampling_rate,
                           threshold = 20,
                           subtract_threshold = FALSE) {

  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1, sampling_rate > 0)
  stopifnot(is.numeric(threshold), length(threshold) == 1, threshold >= 0)
  stopifnot(is.logical(subtract_threshold), length(subtract_threshold) == 1)

  if (is.matrix(force)) {
    ch_names <- colnames(force)
    if (is.null(ch_names)) {
      ch_names <- paste0("ch", seq_len(ncol(force)))
    }

    out <- lapply(seq_len(ncol(force)), function(j) {
      df <- .compute_impulse_vector(force[, j], sampling_rate, threshold,
                                    subtract_threshold)
      if (nrow(df) > 0) {
        df$channel <- ch_names[j]
      }
      df
    })

    out <- out[vapply(out, nrow, integer(1)) > 0]
    if (length(out) == 0) {
      return(.empty_impulse())
    }

    res <- do.call(rbind, out)
    rownames(res) <- NULL
    return(res)
  }

  if (!is.numeric(force)) {
    stop("force must be a numeric vector or matrix.", call. = FALSE)
  }

  .compute_impulse_vector(force, sampling_rate, threshold, subtract_threshold)
}


#' Run complete force-plate analysis
#'
#' Convenience wrapper that filters GRF components and computes COP,
#' loading rate, and impulse summaries.
#'
#' @param forces Matrix/data.frame with force components (X, Y, Z).
#' @param moments Optional matrix/data.frame with moment components (X, Y, Z).
#' @param sampling_rate Sampling rate in Hz.
#' @param cutoff Low-pass cutoff for force filtering.
#' @param threshold Contact threshold for stance detection.
#' @param order Butterworth filter order.
#' @param filter_method Filtering method passed to `filterGRF()`.
#' @param origin Force-plate origin used in COP computation.
#'
#' @return A list with elements: `filtered_forces`, `cop`, `loading_rate`,
#'   `impulse`, and `summary`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [filterGRF()] for ground reaction force filtering,
#'   [calculateCOP()] for center of pressure computation,
#'   [computeLoadingRate()] for loading rate analysis,
#'   [analyzeForcePlatePE()] for PhysioExperiment-based analysis.
#'
#' @export
#'
#' @examples
#' f <- cbind(Fx = rep(0, 1000), Fy = rep(0, 1000),
#'            Fz = c(rep(0, 200), abs(sin(seq(0, pi, length.out = 600))) * 800,
#'                   rep(0, 200)))
#' out <- analyzeForcePlate(f, sampling_rate = 1000)
analyzeForcePlate <- function(forces,
                              moments = NULL,
                              sampling_rate,
                              cutoff = 20,
                              threshold = 20,
                              order = 4,
                              filter_method = c("butterworth", "moving_average"),
                              origin = c(0, 0, 0)) {

  filter_method <- match.arg(filter_method)
  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1, sampling_rate > 0)

  f_xyz <- .coerce_xyz_matrix(forces, kind = "force")
  f_filt <- filterGRF(
    f_xyz,
    sampling_rate = sampling_rate,
    cutoff = cutoff,
    order = order,
    method = filter_method
  )

  colnames(f_filt) <- c("force_x", "force_y", "force_z")

  cop <- NULL
  if (!is.null(moments)) {
    m_xyz <- .coerce_xyz_matrix(moments, kind = "moment")
    cop <- calculateCOP(f_filt, m_xyz, origin = origin,
                        min_vertical_force = threshold)
  }

  loading <- computeLoadingRate(f_filt[, 3], sampling_rate = sampling_rate,
                                threshold = threshold, method = "instantaneous")
  impulse <- computeImpulse(f_filt[, 3], sampling_rate = sampling_rate,
                            threshold = threshold, subtract_threshold = FALSE)

  peak_vgrf <- suppressWarnings(max(f_filt[, 3], na.rm = TRUE))
  if (!is.finite(peak_vgrf)) {
    peak_vgrf <- NA_real_
  }

  max_loading <- if (nrow(loading) > 0) {
    suppressWarnings(max(loading$loading_rate, na.rm = TRUE))
  } else {
    NA_real_
  }

  total_impulse <- if (nrow(impulse) > 0) {
    sum(impulse$impulse, na.rm = TRUE)
  } else {
    0
  }

  summary <- data.frame(
    peak_vertical_force = peak_vgrf,
    max_loading_rate = max_loading,
    total_impulse = total_impulse,
    n_stances = nrow(loading),
    stringsAsFactors = FALSE
  )

  structure(
    list(
      filtered_forces = as.data.frame(f_filt),
      cop = cop,
      loading_rate = loading,
      impulse = impulse,
      summary = summary
    ),
    class = "forceplate_analysis"
  )
}


#' Detect contact windows for one or more force plates
#'
#' Identifies threshold-based contact windows from vertical GRF signals.
#'
#' @param vgrf Numeric vector or matrix of vertical GRF (rows = time,
#'   columns = plates/channels).
#' @param threshold Contact threshold in force units.
#' @param sampling_rate Optional sampling rate in Hz. If provided, durations
#'   are returned in seconds.
#'
#' @return A data.frame with one row per detected contact and columns:
#'   `plate`, `stance`, `onset`, `offset`, `duration_samples`, `duration_s`,
#'   and `peak_force`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [analyzeForcePlate()] for comprehensive force plate analysis,
#'   [analyzeForcePlatePE()] for PhysioExperiment-based analysis.
#'
#' @export
#'
#' @examples
#' v <- cbind(
#'   fp1 = c(rep(0, 100), rep(500, 200), rep(0, 100)),
#'   fp2 = c(rep(0, 200), rep(700, 100), rep(0, 100))
#' )
#' detectForcePlateContacts(v, threshold = 20, sampling_rate = 1000)
detectForcePlateContacts <- function(vgrf,
                                     threshold = 20,
                                     sampling_rate = NULL) {
  stopifnot(is.numeric(threshold), length(threshold) == 1, threshold >= 0)
  if (!is.null(sampling_rate)) {
    stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1, sampling_rate > 0)
  }

  if (is.null(dim(vgrf))) {
    vgrf <- matrix(as.numeric(vgrf), ncol = 1)
    colnames(vgrf) <- "fp1"
  }

  if (!is.matrix(vgrf) || !is.numeric(vgrf)) {
    stop("vgrf must be a numeric vector or matrix.", call. = FALSE)
  }

  plate_names <- colnames(vgrf)
  if (is.null(plate_names)) {
    plate_names <- paste0("fp", seq_len(ncol(vgrf)))
  }

  out <- vector("list", ncol(vgrf))
  for (j in seq_len(ncol(vgrf))) {
    windows <- .detect_contact_windows(vgrf[, j], threshold = threshold)
    if (nrow(windows) == 0) {
      next
    }

    d <- data.frame(
      plate = plate_names[j],
      stance = seq_len(nrow(windows)),
      onset = windows$onset,
      offset = windows$offset,
      duration_samples = windows$offset - windows$onset + 1L,
      duration_s = NA_real_,
      peak_force = NA_real_,
      stringsAsFactors = FALSE
    )

    if (!is.null(sampling_rate)) {
      d$duration_s <- d$duration_samples / sampling_rate
    }

    for (i in seq_len(nrow(d))) {
      seg <- vgrf[d$onset[i]:d$offset[i], j]
      d$peak_force[i] <- suppressWarnings(max(seg, na.rm = TRUE))
    }

    out[[j]] <- d
  }

  out <- out[!vapply(out, is.null, logical(1))]
  if (length(out) == 0) {
    return(data.frame(
      plate = character(0),
      stance = integer(0),
      onset = integer(0),
      offset = integer(0),
      duration_samples = integer(0),
      duration_s = numeric(0),
      peak_force = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}


#' Analyze force-plate signals from a PhysioExperiment object
#'
#' Convenience wrapper for `analyzeForcePlate()` when force and moment
#' components are stored in PhysioExperiment assays.
#'
#' @param pe A PhysioExperiment object.
#' @param force_assay Assay name containing force data with 3 columns
#'   (X, Y, Z). If not present, the function tries `force_x`, `force_y`,
#'   and `force_z` assays.
#' @param moment_assay Optional assay name containing moments with 3 columns.
#'   If not present, the function tries `moment_x`, `moment_y`, and `moment_z`.
#' @param plate_index Which plate to analyze when components are provided as
#'   separate assays with multiple force plates. Accepts:
#'   - numeric scalar (specific plate),
#'   - `"auto"` (select plate with largest vertical-force impulse),
#'   - `"all"` (analyze all plates and return a multi-plate result).
#' @param sampling_rate Optional sampling rate in Hz. If `NULL`, uses
#'   `samplingRate(pe)`.
#' @param ... Additional arguments passed to `analyzeForcePlate()`.
#'
#' @return A `forceplate_analysis` object (single plate) or
#'   `forceplate_analysis_multi` (when `plate_index = "all"`).
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [analyzeForcePlate()] for matrix-based force plate analysis,
#'   [print.forceplate_analysis()] for displaying results.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' pe <- readC3D("trial.c3d", include_analog = TRUE)
#' out <- analyzeForcePlatePE(pe)
#' }
analyzeForcePlatePE <- function(pe,
                                force_assay = "grf",
                                moment_assay = NULL,
                                plate_index = 1L,
                                sampling_rate = NULL,
                                ...) {

  stopifnot(inherits(pe, "PhysioExperiment"))

  if (is.character(plate_index)) {
    if (!(length(plate_index) == 1 && plate_index %in% c("auto", "all"))) {
      stop("'plate_index' character mode must be 'auto' or 'all'.", call. = FALSE)
    }
  } else if (!(is.numeric(plate_index) && length(plate_index) == 1 && plate_index >= 1)) {
    stop("'plate_index' must be numeric >= 1, 'auto', or 'all'.", call. = FALSE)
  }

  anames <- SummarizedExperiment::assayNames(pe)
  sr <- sampling_rate
  if (is.null(sr)) {
    sr <- samplingRate(pe)
  }

  if (!is.numeric(sr) || length(sr) != 1 || !is.finite(sr) || sr <= 0) {
    stop("sampling_rate must be supplied or available in samplingRate(pe).",
         call. = FALSE)
  }

  forces <- NULL
  forces_by_plate <- NULL
  if (force_assay %in% anames) {
    forces <- SummarizedExperiment::assay(pe, force_assay)
  } else if (all(c("force_x", "force_y", "force_z") %in% anames)) {
    fx <- SummarizedExperiment::assay(pe, "force_x")
    fy <- SummarizedExperiment::assay(pe, "force_y")
    fz <- SummarizedExperiment::assay(pe, "force_z")

    n_plates <- min(ncol(fx), ncol(fy), ncol(fz))
    if (n_plates < 1) {
      stop("No force-plate columns available in force_x/y/z assays.", call. = FALSE)
    }

    forces_by_plate <- lapply(seq_len(n_plates), function(i) {
      cbind(
        force_x = fx[, i],
        force_y = fy[, i],
        force_z = fz[, i]
      )
    })

    if (is.character(plate_index) && plate_index == "auto") {
      plate_index <- .select_forceplate_by_impulse(fz, sampling_rate = sr,
                                                   threshold = 20)
    } else if (is.character(plate_index) && plate_index == "all") {
      # handled after moment parsing
    } else {
      plate_index <- as.integer(plate_index)
      if (plate_index > n_plates) {
        stop("plate_index exceeds available force columns.", call. = FALSE)
      }
      forces <- forces_by_plate[[plate_index]]
    }
  }

  if (is.null(forces) && is.null(forces_by_plate)) {
    stop("Force components not found. Provide a valid force_assay or force_x/y/z assays.",
         call. = FALSE)
  }

  moments <- NULL
  moments_by_plate <- NULL
  if (!is.null(moment_assay) && moment_assay %in% anames) {
    moments <- SummarizedExperiment::assay(pe, moment_assay)
  } else if (all(c("moment_x", "moment_y", "moment_z") %in% anames)) {
    mx <- SummarizedExperiment::assay(pe, "moment_x")
    my <- SummarizedExperiment::assay(pe, "moment_y")
    mz <- SummarizedExperiment::assay(pe, "moment_z")

    n_plates_m <- min(ncol(mx), ncol(my), ncol(mz))
    if (!is.null(forces_by_plate) && n_plates_m != length(forces_by_plate)) {
      n_plates_m <- min(n_plates_m, length(forces_by_plate))
      forces_by_plate <- forces_by_plate[seq_len(n_plates_m)]
    }

    moments_by_plate <- lapply(seq_len(n_plates_m), function(i) {
      cbind(
        moment_x = mx[, i],
        moment_y = my[, i],
        moment_z = mz[, i]
      )
    })

    if (is.numeric(plate_index)) {
      plate_index <- as.integer(plate_index)
      if (plate_index > n_plates_m) {
        stop("plate_index exceeds available moment columns.", call. = FALSE)
      }
      moments <- moments_by_plate[[plate_index]]
    }
  }

  if (!is.null(forces) && is.character(plate_index)) {
    if (plate_index == "auto") {
      plate_index <- 1L
    } else if (plate_index == "all") {
      out_one <- analyzeForcePlate(
        forces = forces,
        moments = moments,
        sampling_rate = sr,
        ...
      )
      return(structure(
        list(
          analyses = list(plate1 = out_one),
          summary = transform(out_one$summary, plate = "plate1")[, c(
            "plate", setdiff(names(out_one$summary), "plate")
          ), drop = FALSE],
          sampling_rate = sr
        ),
        class = "forceplate_analysis_multi"
      ))
    }
  }

  if (is.character(plate_index) && plate_index == "all") {
    if (is.null(forces_by_plate)) {
      stop(
        "plate_index = 'all' requires force_x/y/z assays with one column per plate.",
        call. = FALSE
      )
    }

    analyses <- lapply(seq_along(forces_by_plate), function(i) {
      analyzeForcePlate(
        forces = forces_by_plate[[i]],
        moments = if (!is.null(moments_by_plate)) moments_by_plate[[i]] else NULL,
        sampling_rate = sr,
        ...
      )
    })
    names(analyses) <- paste0("plate", seq_along(analyses))

    summary <- do.call(rbind, lapply(seq_along(analyses), function(i) {
      s <- analyses[[i]]$summary
      s$plate <- names(analyses)[i]
      s
    }))
    summary <- summary[, c("plate", setdiff(names(summary), "plate")), drop = FALSE]
    rownames(summary) <- NULL

    return(structure(
      list(
        analyses = analyses,
        summary = summary,
        sampling_rate = sr
      ),
      class = "forceplate_analysis_multi"
    ))
  }

  if (is.character(plate_index)) {
    stop("Could not resolve plate_index mode: ", plate_index, call. = FALSE)
  }

  if (is.null(forces) && !is.null(forces_by_plate)) {
    forces <- forces_by_plate[[as.integer(plate_index)]]
  }
  if (is.null(moments) && !is.null(moments_by_plate)) {
    moments <- moments_by_plate[[as.integer(plate_index)]]
  }

  out <- analyzeForcePlate(
    forces = forces,
    moments = moments,
    sampling_rate = sr,
    ...
  )

  out$selected_plate <- as.integer(plate_index)
  out
}


#' Print a forceplate analysis summary
#' @param x A `forceplate_analysis` object.
#' @param ... Additional arguments (ignored).
#' @return Invisibly returns `x`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [analyzeForcePlate()] for performing force plate analysis,
#'   [analyzeForcePlatePE()] for PhysioExperiment-based analysis.
#'
#' @export
print.forceplate_analysis <- function(x, ...) {
  cat("Forceplate analysis\n")
  cat("  Stances:", x$summary$n_stances, "\n")
  cat("  Peak vertical force:", round(x$summary$peak_vertical_force, 3), "\n")
  cat("  Max loading rate:", round(x$summary$max_loading_rate, 3), "\n")
  cat("  Total impulse:", round(x$summary$total_impulse, 3), "\n")
  if (!is.null(x$selected_plate)) {
    cat("  Selected plate:", x$selected_plate, "\n")
  }
  invisible(x)
}


#' Print a multi-plate forceplate analysis summary
#' @param x A `forceplate_analysis_multi` object.
#' @param ... Additional arguments (ignored).
#' @return Invisibly returns `x`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [analyzeForcePlatePE()] for multi-plate force plate analysis,
#'   [print.forceplate_analysis()] for single-plate result display.
#'
#' @export
print.forceplate_analysis_multi <- function(x, ...) {
  cat("Forceplate analysis (multi-plate)\n")
  cat("  Plates:", length(x$analyses), "\n")
  cat("  Sampling rate:", round(x$sampling_rate, 3), "Hz\n")
  cat("\nSummary by plate:\n")
  print(x$summary, row.names = FALSE)
  invisible(x)
}


#' Coerce input to XYZ matrix
#' @keywords internal
#' @noRd
.coerce_xyz_matrix <- function(x, kind = c("force", "moment")) {
  kind <- match.arg(kind)

  if (!is.matrix(x) && !is.data.frame(x)) {
    stop(kind, " input must be a matrix or data.frame with XYZ columns.", call. = FALSE)
  }

  m <- as.matrix(x)
  if (!is.numeric(m)) {
    stop(kind, " input must be numeric.", call. = FALSE)
  }
  if (ncol(m) < 3) {
    stop(kind, " input must have at least three columns (X, Y, Z).", call. = FALSE)
  }

  nm <- tolower(colnames(m) %||% rep("", ncol(m)))

  idx_x <- .find_axis_index(nm, "x", kind)
  idx_y <- .find_axis_index(nm, "y", kind)
  idx_z <- .find_axis_index(nm, "z", kind)

  idx <- c(idx_x, idx_y, idx_z)

  # Fallback to first three columns if names are not informative or duplicated.
  if (any(is.na(idx)) || length(unique(idx)) < 3) {
    idx <- c(1L, 2L, 3L)
  }

  out <- m[, idx, drop = FALSE]
  colnames(out) <- c("x", "y", "z")
  out
}


#' Find axis column index
#' @keywords internal
#' @noRd
.find_axis_index <- function(names_lower, axis = c("x", "y", "z"),
                             kind = c("force", "moment")) {
  axis <- match.arg(axis)
  kind <- match.arg(kind)

  prefix <- if (kind == "force") "f" else "m"

  exact <- c(
    axis,
    paste0(prefix, axis),
    paste0(kind, "_", axis),
    paste0("grf_", axis),
    paste0("ground_force_", axis),
    paste0("groundreactionforce_", axis)
  )

  idx <- which(names_lower %in% exact)
  if (length(idx) > 0) {
    return(idx[1])
  }

  loose <- grep(paste0("(^|[_.])", axis, "($|[_.])"), names_lower)
  if (length(loose) > 0) {
    return(loose[1])
  }

  NA_integer_
}


#' Empty loading-rate output
#' @keywords internal
#' @noRd
.empty_loading_rate <- function() {
  data.frame(
    stance = integer(0),
    onset = integer(0),
    peak = integer(0),
    time_to_peak = numeric(0),
    peak_force = numeric(0),
    loading_rate = numeric(0),
    channel = character(0),
    stringsAsFactors = FALSE
  )
}


#' Empty impulse output
#' @keywords internal
#' @noRd
.empty_impulse <- function() {
  data.frame(
    stance = integer(0),
    onset = integer(0),
    offset = integer(0),
    duration_s = numeric(0),
    impulse = numeric(0),
    channel = character(0),
    stringsAsFactors = FALSE
  )
}


#' Select a force plate index by vertical-force impulse
#' @keywords internal
#' @noRd
.select_forceplate_by_impulse <- function(fz_matrix, sampling_rate, threshold = 20) {
  if (!is.matrix(fz_matrix) || !is.numeric(fz_matrix) || ncol(fz_matrix) < 1) {
    stop("fz_matrix must be a numeric matrix with at least one column.", call. = FALSE)
  }
  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1, sampling_rate > 0)

  scores <- vapply(seq_len(ncol(fz_matrix)), function(i) {
    sig <- fz_matrix[, i]
    sum(pmax(sig - threshold, 0), na.rm = TRUE) / sampling_rate
  }, numeric(1))

  if (all(!is.finite(scores))) {
    return(1L)
  }

  which.max(scores)
}


#' Compute loading rate for one vector
#' @keywords internal
#' @noRd
.compute_loading_rate_vector <- function(vgrf, sampling_rate, threshold, method) {
  windows <- .detect_contact_windows(vgrf, threshold)
  if (nrow(windows) == 0) {
    return(.empty_loading_rate()[, setdiff(names(.empty_loading_rate()), "channel"), drop = FALSE])
  }

  out <- vector("list", nrow(windows))

  for (i in seq_len(nrow(windows))) {
    onset <- windows$onset[i]
    offset <- windows$offset[i]

    if (offset <= onset) {
      next
    }

    segment_idx <- onset:offset
    segment <- vgrf[segment_idx]
    if (all(!is.finite(segment))) {
      next
    }

    peak_rel <- which.max(segment)
    peak <- segment_idx[peak_rel]

    if (!is.finite(vgrf[onset]) || !is.finite(vgrf[peak]) || peak <= onset) {
      next
    }

    ttp <- (peak - onset) / sampling_rate
    if (ttp <= 0) {
      next
    }

    if (method == "average") {
      lr <- (vgrf[peak] - vgrf[onset]) / ttp
    } else {
      ramp <- vgrf[onset:peak]
      if (length(ramp) < 2) {
        next
      }
      lr <- suppressWarnings(max(diff(ramp) * sampling_rate, na.rm = TRUE))
    }

    out[[i]] <- data.frame(
      stance = i,
      onset = onset,
      peak = peak,
      time_to_peak = ttp,
      peak_force = vgrf[peak],
      loading_rate = lr,
      stringsAsFactors = FALSE
    )
  }

  out <- out[!vapply(out, is.null, logical(1))]
  if (length(out) == 0) {
    return(.empty_loading_rate()[, setdiff(names(.empty_loading_rate()), "channel"), drop = FALSE])
  }

  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}


#' Compute impulse for one vector
#' @keywords internal
#' @noRd
.compute_impulse_vector <- function(force, sampling_rate, threshold, subtract_threshold) {
  windows <- .detect_contact_windows(force, threshold)
  if (nrow(windows) == 0) {
    return(.empty_impulse()[, setdiff(names(.empty_impulse()), "channel"), drop = FALSE])
  }

  out <- vector("list", nrow(windows))

  for (i in seq_len(nrow(windows))) {
    onset <- windows$onset[i]
    offset <- windows$offset[i]

    if (offset <= onset) {
      next
    }

    seg <- force[onset:offset]
    if (!any(is.finite(seg))) {
      next
    }

    if (subtract_threshold) {
      seg <- pmax(seg - threshold, 0)
    }

    imp <- .trapz(seg, dt = 1 / sampling_rate)

    out[[i]] <- data.frame(
      stance = i,
      onset = onset,
      offset = offset,
      duration_s = (offset - onset) / sampling_rate,
      impulse = imp,
      stringsAsFactors = FALSE
    )
  }

  out <- out[!vapply(out, is.null, logical(1))]
  if (length(out) == 0) {
    return(.empty_impulse()[, setdiff(names(.empty_impulse()), "channel"), drop = FALSE])
  }

  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}


#' Detect contact windows using a threshold crossing
#' @keywords internal
#' @noRd
.detect_contact_windows <- function(force, threshold) {
  if (!is.numeric(force)) {
    return(data.frame(onset = integer(0), offset = integer(0)))
  }

  contact <- is.finite(force) & (force >= threshold)
  onset <- which(diff(c(FALSE, contact)) == 1L)
  offset <- which(diff(c(contact, FALSE)) == -1L)

  if (length(onset) == 0 || length(offset) == 0) {
    return(data.frame(onset = integer(0), offset = integer(0)))
  }

  n <- min(length(onset), length(offset))
  data.frame(onset = onset[seq_len(n)], offset = offset[seq_len(n)])
}


#' Trapezoidal integration
#' @keywords internal
#' @noRd
.trapz <- function(y, dt) {
  if (!is.numeric(y) || length(y) < 2) {
    return(NA_real_)
  }

  y1 <- y[-length(y)]
  y2 <- y[-1]
  val <- (y1 + y2) * 0.5 * dt
  sum(val, na.rm = TRUE)
}


#' Extract stance-phase landmarks from a time-normalised vertical GRF curve
#'
#' From a vertical ground-reaction-force curve time-normalised to the stance
#' phase (0-100 %), reads the three classic landmarks of the double-humped
#' stance profile: the loading (weight-acceptance) peak, the mid-stance trough,
#' and the push-off peak. Applied to a body-weight-normalised curve, the
#' landmarks are directly comparable across subjects of different mass, and the
#' peak-trough-peak pattern is the mechanical signature clinical gait analyses
#' contrast between cohorts (e.g. reduced weight-acceptance modulation in
#' pathological gait: lower peaks, a raised trough).
#'
#' @param grf Numeric vector: a vertical GRF curve time-normalised to the stance
#'   phase (e.g. 101 points spanning 0-100 %). Usually in body-weight units so
#'   the landmarks are subject-mass independent. A matrix (curves x time) is also
#'   accepted, in which case the landmarks are read from the ensemble-mean curve
#'   (`colMeans`) — the group-mean landmarks of a cohort of stance curves.
#' @param loading_window,midstance_window,pushoff_window Integer index ranges
#'   (into `grf`) in which to read the loading peak (a maximum), the mid-stance
#'   trough (a minimum) and the push-off peak (a maximum). Defaults target a
#'   101-point stance curve; widen them for populations with atypical timing.
#'
#' @return A named numeric vector `c(peak1, trough, peak2)` — the loading peak,
#'   the mid-stance trough and the push-off peak, in the units of `grf`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' Horsak B, Slijepcevic D, Raberger AM, Schwab C, Worisch M, Zeppelzauer M
#' (2020). "GaitRec, a large-scale ground reaction force dataset of healthy and
#' impaired gait." Scientific Data 7:143.
#'
#' @seealso [filterGRF()] to band-limit the force trace, [computeImpulse()] and
#'   [computeLoadingRate()] for other GRF-derived measures.
#'
#' @export
#'
#' @examples
#' # a synthetic double-humped stance curve (101 pts, body-weight units)
#' g <- 1.1 * sin(seq(0, pi, length.out = 101))^0.5
#' g[46:56] <- g[46:56] * 0.68
#' grfLandmarks(g)
grfLandmarks <- function(grf,
                         loading_window   = 5:40,
                         midstance_window = 30:60,
                         pushoff_window   = 45:80) {

  if (is.matrix(grf)) {
    if (!is.numeric(grf) || ncol(grf) < 2L) {
      stop("grf matrix must be numeric with >= 2 columns (curves x time).",
           call. = FALSE)
    }
    grf <- colMeans(grf)                 # ensemble-mean (group-mean) stance curve
  }
  if (!is.numeric(grf) || length(grf) < 2L) {
    stop("grf must be a numeric vector (a time-normalised stance GRF curve).",
         call. = FALSE)
  }
  n <- length(grf)
  windows <- list(loading   = loading_window,
                  midstance = midstance_window,
                  pushoff   = pushoff_window)
  for (nm in names(windows)) {
    w <- windows[[nm]]
    if (!is.numeric(w) || length(w) < 1L || any(w < 1L) || any(w > n)) {
      stop(sprintf("%s_window must index within grf (1..%d).", nm, n),
           call. = FALSE)
    }
  }

  c(peak1  = max(grf[loading_window]),
    trough = min(grf[midstance_window]),
    peak2  = max(grf[pushoff_window]))
}
