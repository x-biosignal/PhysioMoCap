# Foot-mounted IMU spatiotemporal gait via ZUPT-aided strapdown integration.
# Zero-velocity updates (ZUPT) reset the integrated velocity at each detected
# foot-flat/stance phase, bounding the drift that otherwise grows quadratically
# when double-integrating accelerometer data.

#' Detect foot-IMU stance phases for zero-velocity updates
#'
#' Flags the stationary (foot-flat) samples of a foot-mounted IMU trace, used as
#' zero-velocity-update (ZUPT) anchors by [strapdownIntegrate()] and
#' [footImuGait()]. The default `"magnitude"` detector marks a sample as stance
#' when the accelerometer magnitude is close to gravity *and* the gyroscope
#' magnitude is small; the `"shoe"` detector is the SHOE (Stance Hypothesis
#' Optimal Estimation) generalised-likelihood-ratio test of Skog et al. (2010).
#'
#' @param accel Numeric matrix (n x 3) of accelerometer readings (m/s^2).
#' @param gyro Numeric matrix (n x 3) of gyroscope readings (rad/s).
#' @param sampling_rate Sampling rate in Hz.
#' @param g Gravitational acceleration magnitude (default 9.81 m/s^2).
#' @param method `"magnitude"` (default) or `"shoe"`.
#' @param accel_threshold Magnitude method: max `|‖accel‖ - g|` for stance
#'   (default 0.6 m/s^2).
#' @param gyro_threshold Magnitude method: max `‖gyro‖` for stance
#'   (default 0.6 rad/s).
#' @param sigma_a,sigma_g SHOE method: accelerometer / gyroscope noise standard
#'   deviations (default 0.05 and 0.05).
#' @param gamma SHOE method: test-statistic threshold below which a sample is
#'   stance (default 1e4).
#' @param window Number of samples in the SHOE sliding window (default is about
#'   50 ms of data).
#' @param min_stance Minimum stance-run length in samples; shorter runs are
#'   discarded as spurious (default is about 50 ms of data).
#'
#' @return A logical vector of length `n`, `TRUE` at stance samples.
#'
#' @references
#' Skog I, Handel P, Nilsson J-O, Rantakokko J (2010). "Zero-velocity detection
#' -- an algorithm evaluation." IEEE Trans Biomed Eng 57(11):2657-2666.
#'
#' @seealso [strapdownIntegrate()], [footImuGait()].
#'
#' @export
detectStanceZUPT <- function(accel, gyro, sampling_rate, g = 9.81,
                             method = c("magnitude", "shoe"),
                             accel_threshold = 0.6, gyro_threshold = 0.6,
                             sigma_a = 0.05, sigma_g = 0.05, gamma = 1e4,
                             window = NULL, min_stance = NULL) {
  method <- match.arg(method)
  accel <- .imu_as_n3(accel, "accel")
  gyro <- .imu_as_n3(gyro, "gyro")
  if (nrow(accel) != nrow(gyro)) {
    stop("accel and gyro must have the same number of rows.", call. = FALSE)
  }
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      is.na(sampling_rate) || sampling_rate <= 0) {
    stop("sampling_rate must be a single positive number.", call. = FALSE)
  }
  n <- nrow(accel)
  if (is.null(window)) window <- max(1L, round(0.05 * sampling_rate))
  if (is.null(min_stance)) min_stance <- max(1L, round(0.05 * sampling_rate))

  amag <- sqrt(rowSums(accel^2))
  gmag <- sqrt(rowSums(gyro^2))

  if (method == "magnitude") {
    stance <- abs(amag - g) < accel_threshold & gmag < gyro_threshold
  } else {
    stance <- logical(n)
    half <- window %/% 2L
    inv_a2 <- 1 / sigma_a^2
    inv_g2 <- 1 / sigma_g^2
    for (k in seq_len(n)) {
      lo <- max(1L, k - half)
      hi <- min(n, k + half)
      aw <- accel[lo:hi, , drop = FALSE]
      gw <- gyro[lo:hi, , drop = FALSE]
      amean <- colMeans(aw)
      nrm <- sqrt(sum(amean^2))
      ahat <- if (nrm > 0) amean / nrm else c(0, 0, 0)
      resid <- sweep(aw, 2, g * ahat)
      stat <- (inv_a2 * sum(resid^2) + inv_g2 * sum(gw^2)) / nrow(aw)
      stance[k] <- stat < gamma
    }
  }
  stance[is.na(stance)] <- FALSE

  # Drop stance runs shorter than min_stance
  .imu_prune_runs(stance, min_stance)
}


#' ZUPT-aided strapdown integration of world-frame acceleration
#'
#' Double-integrates world-frame linear acceleration to velocity and position,
#' applying a zero-velocity update (ZUPT) at each stance sample: the integrated
#' velocity is de-drifted so that it returns to zero at every stance sample
#' (linear de-drifting within each swing), which bounds the per-stride
#' integration drift.
#'
#' @param accel_world Numeric matrix (n x 3) of gravity-free acceleration in the
#'   world frame (m/s^2), e.g. from [removeGravity()] rotated into world axes.
#' @param sampling_rate Sampling rate in Hz.
#' @param stance Logical vector of length `n`, `TRUE` at stance samples
#'   (from [detectStanceZUPT()]).
#'
#' @return A list with numeric matrices `velocity` and `position` (each n x 3).
#'
#' @references
#' Mariani B, Hoskovec C, Rochat S, Bula C, Penders J, Aminian K (2010).
#' "3D gait assessment in young and elderly subjects using foot-worn inertial
#' sensors." J Biomech 43(15):2999-3006.
#'
#' @seealso [detectStanceZUPT()], [footImuGait()].
#'
#' @export
strapdownIntegrate <- function(accel_world, sampling_rate, stance) {
  accel_world <- .imu_as_n3(accel_world, "accel_world")
  n <- nrow(accel_world)
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      is.na(sampling_rate) || sampling_rate <= 0) {
    stop("sampling_rate must be a single positive number.", call. = FALSE)
  }
  if (!is.logical(stance) || length(stance) != n) {
    stop("stance must be a logical vector the same length as accel_world.",
         call. = FALSE)
  }
  if (!any(stance)) {
    stop("No stance samples: cannot apply zero-velocity updates. Loosen the ",
         "detectStanceZUPT() thresholds.", call. = FALSE)
  }

  dt <- 1 / sampling_rate
  v_raw <- .imu_cumtrapz(accel_world, dt)

  # Linear de-drift so velocity == 0 at every stance sample (ZUPT)
  knots <- which(stance)
  v <- v_raw
  for (j in 1:3) {
    drift <- .imu_dedrift(knots, v_raw[, j], n)
    v[, j] <- v_raw[, j] - drift
  }
  v[stance, ] <- 0

  position <- .imu_cumtrapz(v, dt)
  list(velocity = v, position = position)
}


#' Foot-IMU spatiotemporal gait parameters
#'
#' End-to-end foot-mounted IMU gait pipeline: estimate orientation, remove
#' gravity, rotate acceleration into the world frame, detect stance, and
#' ZUPT-integrate to a drift-bounded foot trajectory, then derive per-stride
#' stride length, foot clearance, stance/swing time and gait velocity.
#'
#' @param accel Numeric matrix (n x 3) of accelerometer readings (m/s^2).
#' @param gyro Numeric matrix (n x 3) of gyroscope readings (rad/s).
#' @param sampling_rate Sampling rate in Hz.
#' @param g Gravitational acceleration magnitude (default 9.81 m/s^2).
#' @param orientation Optional orientation (a data frame with `q_w`/`q_x`/`q_y`/
#'   `q_z`, or an n x 4 quaternion matrix). If `NULL`, [estimateOrientation()]
#'   is run internally.
#' @param orientation_method Sensor-fusion method for the internal orientation
#'   estimate, `"madgwick"` (default) or `"complementary"`. Ignored when
#'   `orientation` is supplied.
#' @param beta Madgwick filter gain for the internal orientation estimate
#'   (default 0.02). A foot IMU sees large dynamic accelerations, so a small,
#'   gyro-dominant gain avoids swing-phase tilt error; raise it for
#'   lower-dynamic mounting or noisier gyroscopes. Ignored when `orientation`
#'   is supplied.
#' @param stance Optional logical stance vector; if `NULL`, [detectStanceZUPT()]
#'   is used.
#' @param vertical_axis World axis that points up (1, 2 or 3; default 3). Used
#'   for foot clearance and to de-drift vertical position to the floor.
#' @param ... Additional arguments forwarded to [detectStanceZUPT()] (e.g.
#'   `method`, `accel_threshold`).
#'
#' @return An `imu_gait` object: a list with `strides` (a data frame with one
#'   row per detected stride: `stride`, `stride_length`, `foot_clearance`,
#'   `stance_time`, `swing_time`, `stride_time`, `gait_velocity`), the world-frame
#'   `position` and `velocity` matrices, the `stance` mask, and `sampling_rate`.
#'
#' @references
#' Mariani B et al. (2010) J Biomech 43(15):2999-3006;
#' Rebula JR, Ojeda LV, Adamczyk PG, Kuo AD (2013). "Measurement of foot
#' placement and its variability with inertial sensors." Gait & Posture
#' 38(4):974-980.
#'
#' @seealso [detectStanceZUPT()], [strapdownIntegrate()],
#'   [estimateOrientation()], [removeGravity()].
#'
#' @export
footImuGait <- function(accel, gyro, sampling_rate, g = 9.81,
                        orientation = NULL,
                        orientation_method = c("madgwick", "complementary"),
                        beta = 0.02, stance = NULL,
                        vertical_axis = 3, ...) {
  orientation_method <- match.arg(orientation_method)
  accel <- .imu_as_n3(accel, "accel")
  gyro <- .imu_as_n3(gyro, "gyro")
  if (nrow(accel) != nrow(gyro)) {
    stop("accel and gyro must have the same number of rows.", call. = FALSE)
  }
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      is.na(sampling_rate) || sampling_rate <= 0) {
    stop("sampling_rate must be a single positive number.", call. = FALSE)
  }
  vertical_axis <- as.integer(vertical_axis)[1]
  if (is.na(vertical_axis) || !vertical_axis %in% 1:3) {
    stop("vertical_axis must be 1, 2 or 3.", call. = FALSE)
  }
  n <- nrow(accel)

  # 1. Orientation quaternions (sensor -> world)
  if (is.null(orientation)) {
    orientation <- estimateOrientation(accel, gyro,
                                       method = orientation_method,
                                       beta = beta,
                                       sampling_rate = sampling_rate)
  }
  q <- .imu_quat_matrix(orientation, n)

  # 2. Remove gravity (sensor frame), 3. rotate into world frame
  dyn_sensor <- removeGravity(accel, orientation, g = g)
  accel_world <- matrix(0, n, 3)
  for (i in seq_len(n)) {
    accel_world[i, ] <- .quat_rotate_vector(q[i, ], dyn_sensor[i, ])
  }

  # 4. Stance detection
  if (is.null(stance)) {
    stance <- detectStanceZUPT(accel, gyro, sampling_rate = sampling_rate,
                               g = g, ...)
  } else {
    if (!is.logical(stance) || length(stance) != n) {
      stop("stance must be a logical vector of length nrow(accel).",
           call. = FALSE)
    }
  }

  # 5. ZUPT strapdown integration
  si <- strapdownIntegrate(accel_world, sampling_rate, stance)
  position <- si$position

  # De-drift the vertical position so the foot returns to the floor each stance
  knots <- which(stance)
  vdrift <- .imu_dedrift(knots, position[, vertical_axis], n)
  position[, vertical_axis] <- position[, vertical_axis] - vdrift

  # 6. Per-stride parameters between successive stance runs
  runs <- .imu_runs(stance)
  strides <- .imu_stride_table(runs, position, vertical_axis, sampling_rate)

  out <- list(
    strides = strides,
    position = position,
    velocity = si$velocity,
    stance = stance,
    sampling_rate = sampling_rate
  )
  class(out) <- "imu_gait"
  out
}


#' @export
print.imu_gait <- function(x, ...) {
  ns <- nrow(x$strides)
  cat("<imu_gait>\n")
  cat(sprintf("  samples: %d @ %g Hz\n", length(x$stance), x$sampling_rate))
  cat(sprintf("  stance samples: %d (%.1f%%)\n", sum(x$stance),
              100 * mean(x$stance)))
  cat(sprintf("  strides: %d\n", ns))
  if (ns > 0) {
    cat(sprintf("  stride length : mean %.3f m (sd %.3f)\n",
                mean(x$strides$stride_length), stats::sd(x$strides$stride_length)))
    cat(sprintf("  foot clearance: mean %.3f m\n",
                mean(x$strides$foot_clearance)))
    cat(sprintf("  gait velocity : mean %.3f m/s\n",
                mean(x$strides$gait_velocity)))
  }
  invisible(x)
}


# --- internal helpers --------------------------------------------------------

#' Coerce IMU input to an n x 3 numeric matrix
#' @keywords internal
#' @noRd
.imu_as_n3 <- function(x, what) {
  if (is.data.frame(x)) x <- as.matrix(x)
  if (!is.matrix(x) || !is.numeric(x) || ncol(x) != 3L) {
    stop(sprintf("%s must be a numeric n x 3 matrix.", what), call. = FALSE)
  }
  x
}


#' Extract an n x 4 quaternion matrix (w, x, y, z) from orientation input
#' @keywords internal
#' @noRd
.imu_quat_matrix <- function(orientation, n) {
  if (is.data.frame(orientation)) {
    if (!all(c("q_w", "q_x", "q_y", "q_z") %in% names(orientation))) {
      stop("orientation data frame must have q_w/q_x/q_y/q_z columns.",
           call. = FALSE)
    }
    q <- as.matrix(orientation[, c("q_w", "q_x", "q_y", "q_z")])
  } else if (is.matrix(orientation) && ncol(orientation) == 4L) {
    q <- orientation
  } else {
    stop("orientation must be a data frame with q_* columns or an n x 4 matrix.",
         call. = FALSE)
  }
  if (nrow(q) != n) {
    stop("orientation must have one row per sample.", call. = FALSE)
  }
  q
}


#' Stance-anchored linear drift estimate for one axis
#'
#' Linear interpolation of the raw signal at the stance `knots`, extrapolated as
#' a constant beyond the first/last stance (`rule = 2`). With a single knot,
#' `stats::approx()` cannot interpolate, so the knot value is held constant over
#' the whole trace (a pure offset that still forces the de-drifted value to zero
#' at that stance sample).
#' @keywords internal
#' @noRd
.imu_dedrift <- function(knots, x, n) {
  if (length(knots) < 2L) {
    return(rep(x[knots[1]], n))
  }
  stats::approx(knots, x[knots], xout = seq_len(n), rule = 2)$y
}


#' Cumulative trapezoidal integral of each column (starts at 0)
#' @keywords internal
#' @noRd
.imu_cumtrapz <- function(y, dt) {
  n <- nrow(y)
  out <- matrix(0, n, ncol(y))
  if (n < 2L) {
    return(out)
  }
  incr <- (y[-1L, , drop = FALSE] + y[-n, , drop = FALSE]) / 2 * dt
  out[-1L, ] <- apply(incr, 2, cumsum)
  out
}


#' Contiguous TRUE runs as a list of c(start, end)
#' @keywords internal
#' @noRd
.imu_runs <- function(mask) {
  n <- length(mask)
  runs <- list()
  i <- 1L
  while (i <= n) {
    if (isTRUE(mask[i])) {
      j <- i
      while (j < n && isTRUE(mask[j + 1L])) j <- j + 1L
      runs[[length(runs) + 1L]] <- c(i, j)
      i <- j + 1L
    } else {
      i <- i + 1L
    }
  }
  runs
}


#' Remove TRUE runs shorter than min_len
#' @keywords internal
#' @noRd
.imu_prune_runs <- function(mask, min_len) {
  for (r in .imu_runs(mask)) {
    if (r[2] - r[1] + 1L < min_len) {
      mask[r[1]:r[2]] <- FALSE
    }
  }
  mask
}


#' Build the per-stride parameter table from stance runs and the trajectory
#' @keywords internal
#' @noRd
.imu_stride_table <- function(runs, position, vertical_axis, sr) {
  empty <- data.frame(
    stride = integer(0), stride_length = numeric(0),
    foot_clearance = numeric(0), stance_time = numeric(0),
    swing_time = numeric(0), stride_time = numeric(0),
    gait_velocity = numeric(0)
  )
  if (length(runs) < 2L) {
    return(empty)
  }
  horiz <- setdiff(1:3, vertical_axis)
  rep_idx <- vapply(runs, function(r) as.integer(round(mean(r))), integer(1))

  rows <- vector("list", length(runs) - 1L)
  for (k in seq_len(length(runs) - 1L)) {
    a <- rep_idx[k]
    b <- rep_idx[k + 1L]
    disp <- position[b, ] - position[a, ]
    stride_length <- sqrt(sum(disp[horiz]^2))
    # foot clearance: peak vertical rise during the swing between the runs
    swing_lo <- runs[[k]][2]
    swing_hi <- runs[[k + 1L]][1]
    floor_level <- position[a, vertical_axis]
    seg_v <- position[swing_lo:swing_hi, vertical_axis]
    foot_clearance <- max(seg_v) - floor_level
    stance_time <- (runs[[k]][2] - runs[[k]][1] + 1L) / sr
    swing_time <- (runs[[k + 1L]][1] - runs[[k]][2]) / sr
    stride_time <- (b - a) / sr
    gait_velocity <- if (stride_time > 0) stride_length / stride_time else NA_real_
    rows[[k]] <- data.frame(
      stride = k, stride_length = stride_length,
      foot_clearance = foot_clearance, stance_time = stance_time,
      swing_time = swing_time, stride_time = stride_time,
      gait_velocity = gait_velocity
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
