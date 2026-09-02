# Upper-limb reaching kinematics

#' Validate a reaching speed profile
#' @keywords internal
#' @noRd
.reach_speed <- function(speed, name = "speed") {
  if (!is.numeric(speed) || !is.null(dim(speed)) || length(speed) < 1L) {
    stop(sprintf("%s must be a non-empty numeric vector.", name),
         call. = FALSE)
  }
  if (any(is.infinite(speed))) {
    stop(sprintf("%s must not contain infinite values.", name),
         call. = FALSE)
  }
  if (any(speed < 0, na.rm = TRUE)) {
    stop(sprintf("%s must contain non-negative values.", name),
         call. = FALSE)
  }
  as.numeric(speed)
}


#' Validate a finite reaching scalar
#' @keywords internal
#' @noRd
.reach_scalar <- function(x, name, lower = 0, inclusive = TRUE) {
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


#' Validate sampling frequency for reaching metrics
#' @keywords internal
#' @noRd
.reach_fs <- function(fs) {
  .check_fs(fs)
  if (!is.finite(fs)) {
    stop("fs (sampling frequency in Hz) must be finite.", call. = FALSE)
  }
  as.numeric(fs)
}


#' Detect movement bounds in a speed profile
#' @keywords internal
#' @noRd
.reach_bounds <- function(speed,
                          onset_threshold,
                          threshold_type = c("relative", "absolute")) {
  threshold_type <- match.arg(threshold_type)
  onset_threshold <- .reach_scalar(
    onset_threshold, "onset_threshold", 0, inclusive = TRUE
  )
  finite <- is.finite(speed)
  if (!any(finite)) {
    return(c(onset = NA_integer_, offset = NA_integer_))
  }

  peak <- max(speed[finite])
  threshold <- if (threshold_type == "relative") {
    onset_threshold * peak
  } else {
    onset_threshold
  }
  active <- which(finite & speed > threshold)
  if (length(active) == 0L) {
    return(c(onset = NA_integer_, offset = NA_integer_))
  }
  c(onset = as.integer(active[1L]), offset = as.integer(active[length(active)]))
}


#' Reaching endpoint accuracy and precision
#'
#' Computes constant, variable, absolute, and root-mean-square endpoint error.
#' Variable error uses the population RMS distance about the endpoint centroid,
#' preserving the identity `RMSE^2 = constant_error^2 + variable_error^2`.
#'
#' @param endpoints Numeric endpoint vector for a one-dimensional task, or an
#'   `n` by 2/3 numeric matrix with one endpoint per row.
#' @param target Numeric target scalar or vector matching the endpoint
#'   dimension.
#'
#' @return A `reaching_endpoint_error` object with constant, variable,
#'   absolute, RMS, and Fitts effective-width errors.
#'
#' @references
#' Hancock GR, Butler MS, Fischman MG (1995). On the problem of two-dimensional
#' error scores: measures and analyses of accuracy, bias, and consistency.
#' *Journal of Motor Behavior*, 27:241-250.
#'
#' Fitts PM (1954). The information capacity of the human motor system in
#' controlling the amplitude of movement. *Journal of Experimental
#' Psychology*, 47:381-391. \doi{10.1037/h0055392}
#'
#' @export
#'
#' @examples
#' endpointError(c(11, 12, 13, 12), target = 10)
endpointError <- function(endpoints, target) {
  if (is.numeric(endpoints) && is.null(dim(endpoints))) {
    endpoint_matrix <- matrix(as.numeric(endpoints), ncol = 1L)
  } else if (is.matrix(endpoints) && is.numeric(endpoints)) {
    endpoint_matrix <- endpoints
    storage.mode(endpoint_matrix) <- "double"
  } else {
    stop("endpoints must be a numeric vector or matrix.", call. = FALSE)
  }
  if (nrow(endpoint_matrix) < 1L ||
      !ncol(endpoint_matrix) %in% c(1L, 2L, 3L)) {
    stop("endpoints must contain at least one row and 1, 2, or 3 columns.",
         call. = FALSE)
  }
  if (any(!is.finite(endpoint_matrix))) {
    stop("endpoints must contain only finite values.", call. = FALSE)
  }
  if (!is.numeric(target) || !is.null(dim(target)) ||
      length(target) != ncol(endpoint_matrix) ||
      any(!is.finite(target))) {
    stop("target must be a finite numeric vector matching endpoint dimension.",
         call. = FALSE)
  }
  target <- as.numeric(target)

  centroid <- colMeans(endpoint_matrix)
  constant_axis <- centroid - target
  constant_error <- if (ncol(endpoint_matrix) == 1L) {
    constant_axis[1L]
  } else {
    sqrt(sum(constant_axis^2))
  }
  centered <- sweep(endpoint_matrix, 2L, centroid, "-")
  target_error <- sweep(endpoint_matrix, 2L, target, "-")
  centroid_distance_sq <- rowSums(centered^2)
  target_distance_sq <- rowSums(target_error^2)
  variable_error <- sqrt(mean(centroid_distance_sq))

  out <- list(
    constant_error = unname(constant_error),
    constant_error_axiswise = unname(constant_axis),
    variable_error = variable_error,
    absolute_error = mean(sqrt(target_distance_sq)),
    rmse = sqrt(mean(target_distance_sq)),
    effective_width = 4.133 * variable_error,
    n = as.integer(nrow(endpoint_matrix)),
    dimension = as.integer(ncol(endpoint_matrix))
  )
  class(out) <- "reaching_endpoint_error"
  out
}


#' @export
print.reaching_endpoint_error <- function(x, ...) {
  cat(sprintf("<reaching_endpoint_error> n=%d, dimension=%d\n",
              x$n, x$dimension))
  cat(sprintf("  constant: %.4g  variable: %.4g  absolute: %.4g\n",
              x$constant_error, x$variable_error, x$absolute_error))
  cat(sprintf("  RMSE: %.4g  effective width: %.4g\n",
              x$rmse, x$effective_width))
  invisible(x)
}


#' Count reaching movement units
#'
#' Counts accepted speed peaks as movement units (submovements). A peak must
#' exceed both a relative height threshold and a relative prominence threshold.
#'
#' @param speed Numeric non-negative tangential-speed profile.
#' @param fs Optional sampling frequency in Hz. Required only when
#'   `min_peak_distance` is supplied.
#' @param height_frac Peak-height threshold as a fraction of maximum speed.
#' @param prominence_frac Minimum peak prominence as a fraction of maximum
#'   speed.
#' @param min_peak_distance Optional minimum inter-peak interval in seconds.
#'
#' @return Integer movement-unit count. Accepted 1-based peak indices are
#'   stored in the `"peaks"` attribute.
#'
#' @references
#' Rohrer B, Fasoli S, Krebs HI, et al. (2002). Movement smoothness changes
#' during stroke recovery. *Journal of Neuroscience*, 22:8297-8304.
#'
#' @export
#'
#' @examples
#' t <- seq(0, 1, length.out = 500)
#' speed <- exp(-((t - 0.3) / 0.04)^2) + exp(-((t - 0.7) / 0.04)^2)
#' movementUnits(speed)
movementUnits <- function(speed,
                          fs = NULL,
                          height_frac = 0.05,
                          prominence_frac = 0.10,
                          min_peak_distance = NULL) {
  speed <- .reach_speed(speed)
  height_frac <- .reach_scalar(
    height_frac, "height_frac", 0, inclusive = TRUE
  )
  prominence_frac <- .reach_scalar(
    prominence_frac, "prominence_frac", 0, inclusive = TRUE
  )
  if (height_frac > 1 || prominence_frac > 1) {
    stop("height_frac and prominence_frac must not exceed 1.",
         call. = FALSE)
  }

  empty <- function() structure(0L, peaks = integer(0))
  n <- length(speed)
  finite <- is.finite(speed)
  if (n < 3L || !any(finite)) {
    return(empty())
  }
  maximum <- max(speed[finite])
  if (maximum <= 0) {
    return(empty())
  }

  is_maximum <- speed[2:(n - 1L)] > speed[1:(n - 2L)] &
    speed[2:(n - 1L)] >= speed[3:n]
  is_maximum[is.na(is_maximum)] <- FALSE
  candidates <- which(is_maximum) + 1L
  candidates <- candidates[
    is.finite(speed[candidates]) &
      speed[candidates] >= height_frac * maximum
  ]
  if (length(candidates) == 0L) {
    return(empty())
  }

  prominence <- vapply(seq_along(candidates), function(i) {
    peak <- candidates[i]
    left <- if (i == 1L) 1L else candidates[i - 1L]
    right <- if (i == length(candidates)) n else candidates[i + 1L]
    left_min <- min(speed[left:peak], na.rm = TRUE)
    right_min <- min(speed[peak:right], na.rm = TRUE)
    min(speed[peak] - left_min, speed[peak] - right_min)
  }, numeric(1))
  peaks <- candidates[prominence >= prominence_frac * maximum]

  if (!is.null(min_peak_distance)) {
    fs <- .reach_fs(fs)
    min_peak_distance <- .reach_scalar(
      min_peak_distance, "min_peak_distance", 0
    )
    min_samples <- max(1L, as.integer(round(min_peak_distance * fs)))
    while (length(peaks) > 1L) {
      conflict <- which(diff(peaks) < min_samples)[1L]
      if (is.na(conflict)) {
        break
      }
      pair <- peaks[conflict + 0:1]
      drop <- if (speed[pair[1L]] >= speed[pair[2L]]) {
        conflict + 1L
      } else {
        conflict
      }
      peaks <- peaks[-drop]
    }
  }

  structure(as.integer(length(peaks)), peaks = as.integer(peaks))
}


#' Reaching movement time
#'
#' @param speed Numeric non-negative tangential-speed profile.
#' @param fs Sampling frequency in Hz.
#' @param onset_threshold Non-negative threshold, interpreted according to
#'   `threshold_type`.
#' @param threshold_type `"relative"` for a fraction of peak speed or
#'   `"absolute"` for speed units.
#'
#' @return Movement duration in seconds. The 1-based onset and offset samples
#'   are stored as attributes. Returns `NA` when no sample exceeds threshold.
#'
#' @export
#'
#' @examples
#' speed <- c(rep(0, 20), seq(0, 1, length.out = 30),
#'            seq(1, 0, length.out = 30), rep(0, 20))
#' movementTime(speed, fs = 100)
movementTime <- function(speed,
                         fs,
                         onset_threshold = 0.05,
                         threshold_type = c("relative", "absolute")) {
  speed <- .reach_speed(speed)
  fs <- .reach_fs(fs)
  bounds <- .reach_bounds(speed, onset_threshold, threshold_type)
  value <- if (anyNA(bounds)) {
    NA_real_
  } else {
    unname((bounds["offset"] - bounds["onset"]) / fs)
  }
  attr(value, "onset") <- unname(as.integer(bounds["onset"]))
  attr(value, "offset") <- unname(as.integer(bounds["offset"]))
  value
}


#' Peak reaching velocity
#'
#' @param speed Numeric non-negative tangential-speed profile.
#'
#' @return Peak speed. Its first 1-based sample index is stored in the
#'   `"index"` attribute. Returns `NA` when all samples are missing.
#'
#' @export
#'
#' @examples
#' peakVelocity(c(0, 1, 3, 2, 0))
peakVelocity <- function(speed) {
  speed <- .reach_speed(speed)
  finite <- which(is.finite(speed))
  if (length(finite) == 0L) {
    value <- NA_real_
    attr(value, "index") <- NA_integer_
    return(value)
  }
  winner <- finite[which.max(speed[finite])]
  value <- speed[winner]
  attr(value, "index") <- as.integer(winner)
  value
}


#' Time to peak reaching velocity
#'
#' @inheritParams movementTime
#' @param normalize Logical; return time-to-peak divided by movement time
#'   instead of seconds.
#'
#' @return Time from detected onset to peak speed in seconds, or a unitless
#'   fraction of movement time when `normalize = TRUE`.
#'
#' @export
#'
#' @examples
#' speed <- c(rep(0, 20), seq(0, 1, length.out = 30),
#'            seq(1, 0, length.out = 30), rep(0, 20))
#' timeToPeakVelocity(speed, fs = 100)
timeToPeakVelocity <- function(speed,
                               fs,
                               onset_threshold = 0.05,
                               threshold_type = c("relative", "absolute"),
                               normalize = FALSE) {
  speed <- .reach_speed(speed)
  fs <- .reach_fs(fs)
  if (!is.logical(normalize) || length(normalize) != 1L || is.na(normalize)) {
    stop("normalize must be TRUE or FALSE.", call. = FALSE)
  }
  bounds <- .reach_bounds(speed, onset_threshold, threshold_type)
  peak <- peakVelocity(speed)
  peak_index <- attr(peak, "index")
  if (anyNA(bounds) || is.na(peak_index)) {
    return(NA_real_)
  }

  time_to_peak <- (peak_index - bounds["onset"]) / fs
  if (!normalize) {
    return(unname(time_to_peak))
  }
  movement_time <- (bounds["offset"] - bounds["onset"]) / fs
  if (movement_time <= 0) {
    return(NA_real_)
  }
  unname(time_to_peak / movement_time)
}


#' Validate a three-dimensional marker trajectory
#' @keywords internal
#' @noRd
.reach_xyz <- function(x, name, n = NULL) {
  if (!is.matrix(x) || !is.numeric(x) || ncol(x) != 3L ||
      nrow(x) < 1L || any(!is.finite(x))) {
    stop(sprintf("%s must be a finite numeric matrix with three columns.",
                 name), call. = FALSE)
  }
  if (!is.null(n) && nrow(x) != n) {
    stop(sprintf("%s must have the same number of rows as hand.", name),
         call. = FALSE)
  }
  storage.mode(x) <- "double"
  x
}


#' Trunk compensation during reaching
#'
#' Decomposes hand transport into trunk translation and arm-relative transport,
#' and optionally computes signed axial trunk rotation from shoulder markers.
#'
#' @param trunk,hand Numeric `n` by 3 position matrices in a common coordinate
#'   frame and unit.
#' @param shoulder_r,shoulder_l Optional right and left shoulder position
#'   matrices used for axial rotation. Supply both or neither.
#' @param reach_axis Optional length-3 reach-direction vector. The net hand
#'   displacement is used by default.
#' @param vertical_axis Index (1, 2, or 3) of the vertical coordinate axis.
#' @param onset,offset Optional 1-based sample bounds.
#'
#' @return A `trunk_compensation` object containing trunk, hand, and arm
#'   transport, trunk contribution, signed rotation in degrees, and reach axis.
#'
#' @references
#' Cirstea MC, Levin MF (2000). Compensatory strategies for reaching in stroke.
#' *Brain*, 123:940-953. \doi{10.1093/brain/123.5.940}
#'
#' @export
#'
#' @examples
#' hand <- cbind(seq(0, 0.4, length.out = 20), 0, 0)
#' trunk <- cbind(seq(0, 0.1, length.out = 20), 0, 0)
#' trunkCompensation(trunk, hand)
trunkCompensation <- function(trunk,
                              hand,
                              shoulder_r = NULL,
                              shoulder_l = NULL,
                              reach_axis = NULL,
                              vertical_axis = 3L,
                              onset = NULL,
                              offset = NULL) {
  hand <- .reach_xyz(hand, "hand")
  trunk <- .reach_xyz(trunk, "trunk", nrow(hand))
  n <- nrow(hand)

  if (!is.numeric(vertical_axis) || length(vertical_axis) != 1L ||
      !is.finite(vertical_axis) || vertical_axis != floor(vertical_axis) ||
      !vertical_axis %in% 1:3) {
    stop("vertical_axis must be one of 1, 2, or 3.", call. = FALSE)
  }
  vertical_axis <- as.integer(vertical_axis)
  validate_bound <- function(value, default, name) {
    value <- value %||% default
    if (!is.numeric(value) || length(value) != 1L || !is.finite(value) ||
        value != floor(value) || value < 1 || value > n) {
      stop(sprintf("%s must be a 1-based sample index within the trajectory.",
                   name), call. = FALSE)
    }
    as.integer(value)
  }
  onset <- validate_bound(onset, 1L, "onset")
  offset <- validate_bound(offset, n, "offset")
  if (offset < onset) {
    stop("offset must be greater than or equal to onset.", call. = FALSE)
  }

  axis <- reach_axis %||% (hand[offset, ] - hand[onset, ])
  if (!is.numeric(axis) || !is.null(dim(axis)) || length(axis) != 3L ||
      any(!is.finite(axis))) {
    stop("reach_axis must be a finite numeric vector of length three.",
         call. = FALSE)
  }
  axis_norm <- sqrt(sum(axis^2))
  if (axis_norm <= 0) {
    stop("reach_axis has zero length; supply an explicit reach direction.",
         call. = FALSE)
  }
  unit_axis <- as.numeric(axis / axis_norm)

  hand_transport <- sum((hand[offset, ] - hand[onset, ]) * unit_axis)
  trunk_displacement <- sum(
    (trunk[offset, ] - trunk[onset, ]) * unit_axis
  )
  arm_transport <- hand_transport - trunk_displacement
  trunk_contribution <- if (abs(hand_transport) < 1e-9) {
    NA_real_
  } else {
    trunk_displacement / hand_transport
  }

  shoulders_supplied <- c(!is.null(shoulder_r), !is.null(shoulder_l))
  if (xor(shoulders_supplied[1L], shoulders_supplied[2L])) {
    stop("shoulder_r and shoulder_l must be supplied together.",
         call. = FALSE)
  }
  trunk_rotation <- NA_real_
  if (all(shoulders_supplied)) {
    shoulder_r <- .reach_xyz(shoulder_r, "shoulder_r", n)
    shoulder_l <- .reach_xyz(shoulder_l, "shoulder_l", n)
    initial <- shoulder_r[onset, ] - shoulder_l[onset, ]
    final <- shoulder_r[offset, ] - shoulder_l[offset, ]
    raw_norms <- c(sqrt(sum(initial^2)), sqrt(sum(final^2)))
    vertical_fraction <- c(
      abs(initial[vertical_axis]) / raw_norms[1L],
      abs(final[vertical_axis]) / raw_norms[2L]
    )
    if (any(is.finite(vertical_fraction) & vertical_fraction > 0.8)) {
      warning(
        "Shoulder line is mostly aligned with the declared vertical axis; ",
        "verify vertical_axis and coordinate orientation.",
        call. = FALSE
      )
    }
    initial[vertical_axis] <- 0
    final[vertical_axis] <- 0
    initial_norm <- sqrt(sum(initial^2))
    final_norm <- sqrt(sum(final^2))
    if (initial_norm <= 0 || final_norm <= 0) {
      warning("Projected shoulder line has zero length; rotation is undefined.",
              call. = FALSE)
    } else {
      cross <- c(
        initial[2L] * final[3L] - initial[3L] * final[2L],
        initial[3L] * final[1L] - initial[1L] * final[3L],
        initial[1L] * final[2L] - initial[2L] * final[1L]
      )
      vertical <- numeric(3L)
      vertical[vertical_axis] <- 1
      trunk_rotation <- atan2(
        sum(cross * vertical), sum(initial * final)
      ) * 180 / pi
    }
  }

  out <- list(
    trunk_displacement = trunk_displacement,
    hand_transport = hand_transport,
    arm_transport = arm_transport,
    trunk_contribution = trunk_contribution,
    trunk_rotation = trunk_rotation,
    reach_axis = unit_axis,
    onset = onset,
    offset = offset
  )
  class(out) <- "trunk_compensation"
  out
}


#' @export
print.trunk_compensation <- function(x, ...) {
  cat("<trunk_compensation>\n")
  cat(sprintf("  hand: %.4g  trunk: %.4g  arm: %.4g\n",
              x$hand_transport, x$trunk_displacement, x$arm_transport))
  cat(sprintf("  trunk contribution: %s  rotation: %s deg\n",
              if (is.na(x$trunk_contribution)) {
                "NA"
              } else {
                sprintf("%.3f", x$trunk_contribution)
              },
              if (is.na(x$trunk_rotation)) {
                "NA"
              } else {
                sprintf("%.2f", x$trunk_rotation)
              }))
  invisible(x)
}


#' Resolve a marker in position assays
#' @keywords internal
#' @noRd
.reach_marker_index <- function(marker, labels, n_markers, argument = "marker") {
  if (is.numeric(marker) && length(marker) == 1L && is.finite(marker) &&
      marker == floor(marker) && marker >= 1 && marker <= n_markers) {
    return(as.integer(marker))
  }
  if (is.character(marker) && length(marker) == 1L && !is.na(marker) &&
      nzchar(marker)) {
    index <- match(marker, labels)
    if (!is.na(index)) {
      return(as.integer(index))
    }
  }
  stop(sprintf("%s must identify one marker in the position assays.",
               argument), call. = FALSE)
}


#' Reaching kinematics report for a PhysioExperiment
#'
#' Extracts a hand-marker trajectory, computes tangential speed with
#' [computeVelocity()] and [computeSpeed()], and reports temporal, submovement,
#' smoothness, endpoint, and optional trunk-compensation metrics.
#'
#' @param pe A `PhysioExperiment` with `position_x`, `position_y`, and
#'   optionally `position_z` assays.
#' @param marker Reaching hand marker name or column index.
#' @param target Optional target coordinate matching trajectory dimension.
#' @param assay_prefix Position-assay prefix (default `"position"`).
#' @param sampling_rate Optional sampling frequency in Hz; defaults to
#'   [PhysioCore::samplingRate()].
#' @param onset_threshold Movement threshold.
#' @param trunk_marker Optional trunk marker name or column index.
#' @param shoulder_markers Optional length-2 vector identifying right and left
#'   shoulder markers.
#' @param ... Additional arguments passed to [sparc()].
#'
#' @return A `reaching_kinematics` report with movement time, peak velocity,
#'   time to peak, movement units, SPARC, LDLJ, dimensionless jerk, movement
#'   bounds, sampling rate, marker, and optional endpoint/trunk results.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' pe <- make_mocap_markers(n_time = 200, n_markers = 3, sr = 200)
#' reachingKinematics(pe, marker = "Marker1")
#' }
reachingKinematics <- function(pe,
                               marker,
                               target = NULL,
                               assay_prefix = "position",
                               sampling_rate = NULL,
                               onset_threshold = 0.05,
                               trunk_marker = NULL,
                               shoulder_markers = NULL,
                               ...) {
  if (!inherits(pe, "PhysioExperiment")) {
    stop("pe must be a PhysioExperiment.", call. = FALSE)
  }
  if (!is.character(assay_prefix) || length(assay_prefix) != 1L ||
      is.na(assay_prefix) || !nzchar(assay_prefix)) {
    stop("assay_prefix must be a non-empty string.", call. = FALSE)
  }
  fs <- sampling_rate %||% as.numeric(samplingRate(pe))[1L]
  fs <- .reach_fs(fs)

  axes <- c("x", "y", "z")
  candidates <- paste0(assay_prefix, "_", axes)
  assay_names <- SummarizedExperiment::assayNames(pe)
  present <- candidates %in% assay_names
  if (!all(present[1:2])) {
    stop("Position x and y assays are required for reaching analysis.",
         call. = FALSE)
  }
  position_assays <- candidates[present]
  position <- lapply(
    position_assays,
    function(name) as.matrix(SummarizedExperiment::assay(pe, name))
  )
  dimensions <- vapply(position, dim, integer(2L))
  if (length(unique(dimensions[1L, ])) != 1L ||
      length(unique(dimensions[2L, ])) != 1L) {
    stop("Position assays must have identical dimensions.", call. = FALSE)
  }
  if (any(vapply(position, function(x) {
    !is.numeric(x) || any(!is.finite(x))
  }, logical(1)))) {
    stop("Position assays must contain finite numeric values.", call. = FALSE)
  }

  labels <- colnames(position[[1L]])
  if (is.null(labels)) {
    cd <- SummarizedExperiment::colData(pe)
    if ("label" %in% names(cd)) {
      labels <- as.character(cd[["label"]])
    } else {
      labels <- as.character(seq_len(ncol(position[[1L]])))
    }
  }
  marker_index <- .reach_marker_index(
    marker, labels, ncol(position[[1L]])
  )
  marker_label <- labels[marker_index]

  velocity_pe <- computeVelocity(
    pe, assay_names = position_assays, sampling_rate = fs
  )
  velocity_assays <- paste0(
    "velocity_",
    sub("^(position|keypoint)_", "", position_assays)
  )
  speed_pe <- computeSpeed(velocity_pe, velocity_assays = velocity_assays)
  speed <- as.numeric(
    SummarizedExperiment::assay(speed_pe, "speed")[, marker_index]
  )
  trajectory <- do.call(
    cbind, lapply(position, function(x) as.numeric(x[, marker_index]))
  )

  movement_time <- movementTime(
    speed, fs, onset_threshold = onset_threshold
  )
  onset <- attr(movement_time, "onset")
  offset <- attr(movement_time, "offset")
  if (is.na(onset) || is.na(offset)) {
    segment <- speed
  } else {
    segment <- speed[seq.int(onset, offset)]
  }
  finite_segment <- segment[is.finite(segment)]
  has_motion <- length(finite_segment) > 0L && max(finite_segment) > 0
  sparc_value <- if (length(segment) >= 4L && has_motion) {
    sparc(segment, fs, ...)
  } else {
    NA_real_
  }
  ldlj_value <- if (length(segment) >= 3L && has_motion) {
    ldlj(segment, fs)
  } else {
    NA_real_
  }
  jerk_value <- if (length(segment) >= 3L && has_motion) {
    dimensionlessJerk(segment, fs)
  } else {
    NA_real_
  }

  out <- list(
    movement_time = unname(movement_time),
    peak_velocity = unname(peakVelocity(speed)),
    time_to_peak = timeToPeakVelocity(
      speed, fs, onset_threshold = onset_threshold
    ),
    time_to_peak_frac = timeToPeakVelocity(
      speed, fs, onset_threshold = onset_threshold, normalize = TRUE
    ),
    n_movement_units = as.integer(movementUnits(segment)),
    sparc = sparc_value,
    ldlj = ldlj_value,
    dimensionless_jerk = jerk_value,
    onset = onset,
    offset = offset,
    fs = fs,
    marker = marker_label
  )

  endpoint_index <- if (is.na(offset)) nrow(trajectory) else offset
  if (!is.null(target)) {
    endpoint <- endpointError(
      matrix(trajectory[endpoint_index, ], nrow = 1L), target
    )
    out$endpoint_rmse <- endpoint$rmse
  }

  if (!is.null(shoulder_markers) && is.null(trunk_marker)) {
    stop("trunk_marker is required when shoulder_markers are supplied.",
         call. = FALSE)
  }
  if (!is.null(trunk_marker)) {
    trunk_index <- .reach_marker_index(
      trunk_marker, labels, ncol(position[[1L]]), "trunk_marker"
    )
    trunk <- do.call(
      cbind, lapply(position, function(x) as.numeric(x[, trunk_index]))
    )
    if (ncol(trunk) == 2L) {
      trunk <- cbind(trunk, 0)
      hand_xyz <- cbind(trajectory, 0)
    } else {
      hand_xyz <- trajectory
    }

    shoulder_r <- shoulder_l <- NULL
    if (!is.null(shoulder_markers)) {
      if (length(shoulder_markers) != 2L) {
        stop("shoulder_markers must identify right and left shoulders.",
             call. = FALSE)
      }
      shoulder_indices <- vapply(seq_len(2L), function(i) {
        .reach_marker_index(
          shoulder_markers[i], labels, ncol(position[[1L]]),
          "shoulder_markers"
        )
      }, integer(1))
      shoulder_trajectory <- lapply(shoulder_indices, function(index) {
        value <- do.call(
          cbind, lapply(position, function(x) as.numeric(x[, index]))
        )
        if (ncol(value) == 2L) cbind(value, 0) else value
      })
      shoulder_r <- shoulder_trajectory[[1L]]
      shoulder_l <- shoulder_trajectory[[2L]]
    }

    trunk_onset <- if (is.na(onset)) 1L else onset
    trunk_offset <- if (is.na(offset)) nrow(hand_xyz) else offset
    out$trunk <- trunkCompensation(
      trunk, hand_xyz, shoulder_r, shoulder_l,
      onset = trunk_onset, offset = trunk_offset
    )
  }

  class(out) <- "reaching_kinematics"
  out
}


#' @export
print.reaching_kinematics <- function(x, ...) {
  cat(sprintf("<reaching_kinematics> marker=%s, fs=%g Hz\n",
              x$marker, x$fs))
  cat(sprintf("  movement time: %s s  peak velocity: %.4g\n",
              if (is.na(x$movement_time)) {
                "NA"
              } else {
                sprintf("%.3f", x$movement_time)
              },
              x$peak_velocity))
  cat(sprintf("  movement units: %d  SPARC: %s  LDLJ: %s\n",
              x$n_movement_units,
              if (is.na(x$sparc)) "NA" else sprintf("%.4f", x$sparc),
              if (is.na(x$ldlj)) "NA" else sprintf("%.4f", x$ldlj)))
  invisible(x)
}
