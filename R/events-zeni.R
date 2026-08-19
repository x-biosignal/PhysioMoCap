# Coordinate-based gait-event detection (Zeni et al. 2008)
# Marker-position ("coordinate") method for heel-strike / toe-off detection
# across an entire multi-stride trial, for treadmill and overground walking.

#' Detect gait events with the Zeni coordinate method
#'
#' Implements the coordinate-based gait-event detector of Zeni, Richards &
#' Higginson (2008). Heel strike (initial contact, IC) occurs when a heel
#' marker reaches its most anterior position relative to a pelvis/COM reference;
#' toe off (TO) occurs when a toe marker reaches its most posterior position
#' relative to the same reference. Because events are keyed to the foot marker
#' *relative to* the pelvis, the method works on treadmill trials where the
#' body does not translate in the lab frame, and it returns per-stride IC/TO for
#' both sides across a full trial.
#'
#' The result is a `detected_events` data frame compatible with
#' [calculateGaitParameters()]; heel-strike/toe-off rows are named
#' `left_heel_strike`/`right_heel_strike`/`left_toe_off`/`right_toe_off` and
#' carry an explicit `side` column.
#'
#' @param pe A `PhysioExperiment` with marker `position_x`/`position_y`
#'   (and optionally `position_z`) assays (frames x markers).
#' @param markers A named list of marker names (columns of the position assays)
#'   with entries `heel_left`, `heel_right`, `toe_left`, `toe_right`. A side is
#'   skipped if both its heel and toe entries are `NULL`/missing.
#' @param reference Progression reference: a marker name (e.g. a sacral marker,
#'   the default `"sacrum"`), or `"com"` to use the whole-body centre of mass
#'   from [calculateCOM()] (requires `body_mass`).
#' @param ap_axis Anterior-posterior (progression) axis: `"x"`, `"y"`, `"z"`
#'   or `1`/`2`/`3`. `NULL` (default) auto-detects the axis with the largest
#'   heel-relative-to-reference excursion.
#' @param direction `+1` or `-1` to orient the AP axis so anterior is positive;
#'   `NULL` (default) auto-detects it (the fastest relative foot motion, i.e.
#'   swing, points anterior).
#' @param body_mass Body mass in kg, required only when `reference = "com"`.
#' @param min_separation Minimum number of frames between successive same-type
#'   events (refractory period). `NULL` (default) estimates it from the dominant
#'   stride period via autocorrelation.
#' @param sampling_rate Sampling rate in Hz; defaults to `samplingRate(pe)`.
#'
#' @return A `detected_events` data frame with one row per detected event
#'   (columns `event`, `label`, `index`, `time`, `percent`, `method`,
#'   `confidence`, `side`), sorted by frame index.
#'
#' @references
#' Zeni JA, Richards JG, Higginson JS (2008). "Two simple methods for
#' determining gait events during treadmill and overground walking."
#' Gait & Posture 27(4):710-714.
#'
#' @seealso [detectEvents()] (use `method = "zeni"`),
#'   [calculateGaitParameters()], [calculateCOM()].
#'
#' @export
detectEventsZeni <- function(pe,
                             markers,
                             reference = "sacrum",
                             ap_axis = NULL,
                             direction = NULL,
                             body_mass = NULL,
                             min_separation = NULL,
                             sampling_rate = NULL) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  if (missing(markers) || !is.list(markers)) {
    stop("'markers' must be a named list with heel_left/heel_right/",
         "toe_left/toe_right.", call. = FALSE)
  }
  sr <- if (!is.null(sampling_rate)) sampling_rate else PhysioCore::samplingRate(pe)
  if (!is.numeric(sr) || length(sr) != 1L || is.na(sr) || sr <= 0) {
    stop("sampling_rate must be a single positive number.", call. = FALSE)
  }

  anames <- SummarizedExperiment::assayNames(pe)
  axis_letters <- c("x", "y", "z")
  have_axis <- paste0("position_", axis_letters) %in% anames
  names(have_axis) <- axis_letters
  if (!all(have_axis[c("x", "y")])) {
    stop("detectEventsZeni requires at least 'position_x' and 'position_y' ",
         "assays.", call. = FALSE)
  }
  pos <- stats::setNames(lapply(axis_letters[have_axis], function(a) {
    SummarizedExperiment::assay(pe, paste0("position_", a))
  }), axis_letters[have_axis])
  n <- nrow(pos[[1]])
  if (n < 3L) {
    stop("Need at least 3 frames for Zeni event detection.", call. = FALSE)
  }

  # Resolve heel/toe markers per side
  sides <- list(
    left  = list(heel = markers$heel_left,  toe = markers$toe_left),
    right = list(heel = markers$heel_right, toe = markers$toe_right)
  )
  sides <- sides[vapply(sides, function(s) {
    !is.null(s$heel) || !is.null(s$toe)
  }, logical(1))]
  if (length(sides) == 0L) {
    stop("No sides supplied: provide heel_left/toe_left and/or ",
         "heel_right/toe_right in 'markers'.", call. = FALSE)
  }

  col_of <- function(m, axis) {
    mat <- pos[[axis]]
    if (is.numeric(m)) {
      idx <- as.integer(m)[1]
      if (is.na(idx) || idx < 1L || idx > ncol(mat)) {
        stop("marker index out of range: ", m, call. = FALSE)
      }
      return(mat[, idx])
    }
    if (!(m %in% colnames(mat))) {
      stop(sprintf("marker '%s' not found in position_%s assay.", m, axis),
           call. = FALSE)
    }
    mat[, m]
  }

  # Resolve the reference (pelvis / COM) AP series for each available axis
  ref_by_axis <- .zeni_reference(pe, pos, reference, body_mass,
                                 axis_letters[have_axis])

  # Auto-detect the AP axis from the largest foot-relative excursion. Pool
  # heel and toe markers so a toe-only marker set still resolves the axis.
  foot_names <- unique(unlist(lapply(sides, function(s) c(s$heel, s$toe))))
  ap <- .zeni_resolve_axis(ap_axis, pos, ref_by_axis, foot_names, col_of,
                           axis_letters[have_axis])

  # Auto-detect progression direction. The toe marker is anatomically anterior
  # to the heel, so sign(mean(toe - heel)) is the anterior direction for any
  # side that has both markers; fall back to the fastest relative foot motion
  # (swing) when only one foot marker is available.
  ref_ap <- ref_by_axis[[ap]]
  if (is.null(direction)) {
    probe_side <- NULL
    for (sd in names(sides)) {
      if (!is.null(sides[[sd]]$heel) && !is.null(sides[[sd]]$toe)) {
        probe_side <- sd
        break
      }
    }
    if (!is.null(probe_side)) {
      direction <- .zeni_direction_foot(col_of(sides[[probe_side]]$toe, ap),
                                        col_of(sides[[probe_side]]$heel, ap))
    } else {
      probe <- if (!is.null(sides[[1]]$heel)) sides[[1]]$heel else sides[[1]]$toe
      direction <- .zeni_direction(col_of(probe, ap) - ref_ap)
    }
  }
  if (!is.numeric(direction) || length(direction) != 1L ||
      !direction %in% c(-1, 1)) {
    stop("direction must be +1, -1, or NULL.", call. = FALSE)
  }

  # Estimate the refractory window from the dominant stride period
  if (is.null(min_separation)) {
    period <- .zeni_dominant_period(direction * (col_of(
      if (!is.null(sides[[1]]$heel)) sides[[1]]$heel else sides[[1]]$toe, ap) -
        ref_ap))
    # 0.6 (> 0.5) of the stride period so the exclusion zones of adjacent
    # true peaks overlap, rejecting spurious mid-stride bumps, while staying
    # comfortably below one stride so no true event is merged.
    min_separation <- if (is.finite(period)) max(1L, round(0.6 * period)) else 1L
  }
  min_separation <- as.integer(min_separation)
  if (is.na(min_separation) || min_separation < 1L) {
    stop("min_separation must be a positive integer or NULL.", call. = FALSE)
  }

  # Detect events per side
  event_meta <- list(
    left  = list(hs = "left_heel_strike",  hs_label = "Left Heel Strike",
                 to = "left_toe_off",      to_label = "Left Toe Off"),
    right = list(hs = "right_heel_strike", hs_label = "Right Heel Strike",
                 to = "right_toe_off",     to_label = "Right Toe Off")
  )
  rows <- list()
  for (sd in names(sides)) {
    s <- sides[[sd]]
    meta <- event_meta[[sd]]
    if (!is.null(s$heel)) {
      heel_rel <- direction * (col_of(s$heel, ap) - ref_ap)
      hs_idx <- .zeni_extrema(heel_rel, "max", min_separation)
      rows[[length(rows) + 1L]] <- .zeni_rows(hs_idx, meta$hs, meta$hs_label,
                                              sd, n, sr)
    }
    if (!is.null(s$toe)) {
      toe_rel <- direction * (col_of(s$toe, ap) - ref_ap)
      to_idx <- .zeni_extrema(toe_rel, "min", min_separation)
      rows[[length(rows) + 1L]] <- .zeni_rows(to_idx, meta$to, meta$to_label,
                                              sd, n, sr)
    }
  }

  out <- do.call(rbind, rows)
  if (is.null(out) || nrow(out) == 0L) {
    out <- .zeni_empty_events()
  } else {
    out <- out[order(out$index), , drop = FALSE]
    rownames(out) <- NULL
  }
  class(out) <- c("detected_events", "data.frame")
  attr(out, "schema") <- "gait"
  attr(out, "sampling_rate") <- sr
  attr(out, "n_samples") <- n
  attr(out, "ap_axis") <- ap
  attr(out, "direction") <- direction
  out
}


#' Build the reference (pelvis/COM) AP series per axis
#' @keywords internal
#' @noRd
.zeni_reference <- function(pe, pos, reference, body_mass, axes) {
  if (is.character(reference) && length(reference) == 1L &&
      reference == "com") {
    if (is.null(body_mass)) {
      stop("reference = 'com' requires 'body_mass'.", call. = FALSE)
    }
    pe_com <- calculateCOM(pe, body_mass = body_mass)
    com_anames <- SummarizedExperiment::assayNames(pe_com)
    return(stats::setNames(lapply(axes, function(a) {
      nm <- paste0("com_", a)
      if (!(nm %in% com_anames)) {
        stop(sprintf("COM assay '%s' not available for the AP axis.", nm),
             call. = FALSE)
      }
      as.numeric(SummarizedExperiment::assay(pe_com, nm)[, 1])
    }), axes))
  }
  # Marker reference
  stats::setNames(lapply(axes, function(a) {
    mat <- pos[[a]]
    if (is.numeric(reference)) {
      idx <- as.integer(reference)[1]
      if (is.na(idx) || idx < 1L || idx > ncol(mat)) {
        stop("reference marker index out of range: ", reference, call. = FALSE)
      }
      return(mat[, idx])
    }
    if (!(reference %in% colnames(mat))) {
      stop(sprintf("reference marker '%s' not found in position_%s assay; ",
                   reference, a),
           "pass a valid marker name or reference = 'com'.", call. = FALSE)
    }
    mat[, reference]
  }), axes)
}


#' Resolve / auto-detect the AP axis
#' @keywords internal
#' @noRd
.zeni_resolve_axis <- function(ap_axis, pos, ref_by_axis, foot_names, col_of,
                               axes) {
  if (!is.null(ap_axis)) {
    if (is.numeric(ap_axis)) {
      i <- as.integer(ap_axis)[1]
      if (is.na(i) || i < 1L || i > 3L) {
        stop("ap_axis must be 'x'/'y'/'z' or 1/2/3.", call. = FALSE)
      }
      ap_axis <- c("x", "y", "z")[i]
    }
    if (!ap_axis %in% axes) {
      stop(sprintf("ap_axis '%s' is not an available position axis.", ap_axis),
           call. = FALSE)
    }
    return(ap_axis)
  }
  if (length(foot_names) == 0L) {
    stop("Cannot auto-detect ap_axis without a heel or toe marker; pass ",
         "ap_axis explicitly.", call. = FALSE)
  }
  # largest pooled foot-relative-to-reference range
  ranges <- vapply(axes, function(a) {
    rel <- vapply(foot_names, function(m) {
      col_of(m, a) - ref_by_axis[[a]]
    }, numeric(nrow(pos[[a]])))
    diff(range(rel, na.rm = TRUE))
  }, numeric(1))
  if (!any(is.finite(ranges))) {
    stop("Cannot auto-detect ap_axis (no finite marker excursions); pass ",
         "ap_axis explicitly.", call. = FALSE)
  }
  axes[which.max(ranges)]
}


#' Auto-detect progression direction: the toe is anterior to the heel
#' @keywords internal
#' @noRd
.zeni_direction_foot <- function(toe_ap, heel_ap) {
  d <- mean(toe_ap - heel_ap, na.rm = TRUE)
  s <- sign(d)
  if (is.na(s) || s == 0) 1 else s
}


#' Fallback progression direction: fastest relative foot motion is anterior
#' @keywords internal
#' @noRd
.zeni_direction <- function(heel_rel_raw) {
  v <- diff(heel_rel_raw)
  v <- v[is.finite(v)]
  if (length(v) == 0L) {
    return(1)
  }
  s <- sign(v[which.max(abs(v))])
  if (s == 0) 1 else s
}


#' Dominant period (samples) from the first autocorrelation peak
#' @keywords internal
#' @noRd
.zeni_dominant_period <- function(x) {
  x <- x[is.finite(x)]
  m <- length(x)
  if (m < 4L) {
    return(NA_real_)
  }
  x <- x - mean(x)
  ac <- tryCatch(
    stats::acf(x, lag.max = m - 1L, plot = FALSE, demean = FALSE)$acf[, 1, 1],
    error = function(e) NULL
  )
  if (is.null(ac) || length(ac) < 3L) {
    return(NA_real_)
  }
  peaks <- .zeni_extrema(ac, "max", 1L)
  peaks <- peaks[peaks > 1L]
  if (length(peaks) == 0L) {
    return(NA_real_)
  }
  peaks[1] - 1  # lag in samples
}


#' Local extrema with a minimum inter-event distance (greedy by prominence)
#' @keywords internal
#' @noRd
.zeni_extrema <- function(x, type = c("max", "min"), min_dist = 1L) {
  type <- match.arg(type)
  n <- length(x)
  if (n < 3L) {
    return(integer(0))
  }
  y <- if (type == "min") -x else x
  # interior points strictly above the left neighbour and >= the right one
  # (the >= guards against dropping the leading edge of a flat peak)
  cand <- which(y[2:(n - 1L)] > y[1:(n - 2L)] &
                  y[2:(n - 1L)] >= y[3:n]) + 1L
  if (length(cand) == 0L) {
    return(integer(0))
  }
  ord <- cand[order(y[cand], decreasing = TRUE)]
  kept <- integer(0)
  for (p in ord) {
    if (length(kept) == 0L || all(abs(p - kept) >= min_dist)) {
      kept <- c(kept, p)
    }
  }
  sort(kept)
}


#' Assemble detected_events rows for a set of event indices
#' @keywords internal
#' @noRd
.zeni_rows <- function(idx, event, label, side, n, sr) {
  if (length(idx) == 0L) {
    return(NULL)
  }
  data.frame(
    event = event,
    label = label,
    index = idx,
    time = (idx - 1) / sr,
    percent = (idx - 1) / (n - 1) * 100,
    method = "zeni",
    confidence = 1,
    side = side,
    stringsAsFactors = FALSE
  )
}


#' Empty detected_events frame with the Zeni columns
#' @keywords internal
#' @noRd
.zeni_empty_events <- function() {
  data.frame(
    event = character(0), label = character(0), index = integer(0),
    time = numeric(0), percent = numeric(0), method = character(0),
    confidence = numeric(0), side = character(0),
    stringsAsFactors = FALSE
  )
}
