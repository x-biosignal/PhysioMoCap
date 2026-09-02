# Numerical Derivative Functions for Movement Analysis
# Provides velocity, acceleration, jerk, and speed computations

#' Differentiate a numeric vector or matrix
#'
#' Low-level function to compute numerical derivatives of arbitrary order
#' using finite difference methods.
#'
#' @param x Numeric vector or matrix (time x channels).
#' @param dt Time step between samples (1 / sampling_rate).
#' @param method Difference method: "central", "forward", or "backward".
#' @param order Derivative order: 1 (velocity), 2 (acceleration), or 3 (jerk).
#'
#' @return Differentiated data with same dimensions as input. Boundary values
#'   where the stencil cannot be applied are set to NA.
#'
#' @details
#' For \code{method = "central"} with \code{order = 1}:
#' \deqn{f'(i) = (x[i+1] - x[i-1]) / (2 \cdot dt)}
#'
#' For \code{method = "central"} with \code{order = 2}:
#' \deqn{f''(i) = (x[i+1] - 2 x[i] + x[i-1]) / dt^2}
#'
#' For higher orders, the derivative is computed by repeated application of
#' the first-order formula.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [computeVelocity()] for computing velocity from PhysioExperiment,
#'   [computeAcceleration()] for second-order derivatives,
#'   [savgolFilter()] for smoothed differentiation via Savitzky-Golay.
#'
#' @export
#' @examples
#' # Differentiate sin to get cos
#' t <- seq(0, 2 * pi, length.out = 200)
#' x <- sin(t)
#' dx <- differentiate(x, dt = t[2] - t[1], method = "central", order = 1)
#' # dx should approximate cos(t)
differentiate <- function(x, dt, method = c("central", "forward", "backward"),
                          order = 1L) {
  method <- match.arg(method)
  stopifnot(is.numeric(dt), length(dt) == 1, dt > 0)

  order <- as.integer(order)
  stopifnot(order >= 1L, order <= 3L)

  if (is.matrix(x)) {
    result <- apply(x, 2, function(col) {
      .differentiateVector(col, dt, method, order)
    })
    colnames(result) <- colnames(x)
    return(result)
  }

  if (is.numeric(x)) {
    return(.differentiateVector(x, dt, method, order))
  }

  stop("x must be a numeric vector or matrix", call. = FALSE)
}


#' Differentiate a single numeric vector
#' @keywords internal
#' @noRd
.differentiateVector <- function(x, dt, method, order) {
  n <- length(x)
  if (n < 3) {
    return(rep(NA_real_, n))
  }

  result <- x
  for (k in seq_len(order)) {
    result <- .diffOnce(result, dt, method)
  }
  result
}


#' Apply a single differentiation step
#' @keywords internal
#' @noRd
.diffOnce <- function(x, dt, method) {
  n <- length(x)
  result <- rep(NA_real_, n)

  if (n < 2) return(result)

  switch(method,
    "central" = {
      if (n >= 3) {
        for (i in 2:(n - 1)) {
          if (!is.na(x[i - 1]) && !is.na(x[i + 1])) {
            result[i] <- (x[i + 1] - x[i - 1]) / (2 * dt)
          }
        }
      }
      # Boundary: forward diff at start, backward diff at end
      if (!is.na(x[1]) && !is.na(x[2])) {
        result[1] <- (x[2] - x[1]) / dt
      }
      if (!is.na(x[n - 1]) && !is.na(x[n])) {
        result[n] <- (x[n] - x[n - 1]) / dt
      }
    },
    "forward" = {
      for (i in seq_len(n - 1)) {
        if (!is.na(x[i]) && !is.na(x[i + 1])) {
          result[i] <- (x[i + 1] - x[i]) / dt
        }
      }
      # Last element is NA (no forward neighbor)
    },
    "backward" = {
      for (i in 2:n) {
        if (!is.na(x[i - 1]) && !is.na(x[i])) {
          result[i] <- (x[i] - x[i - 1]) / dt
        }
      }
      # First element is NA (no backward neighbor)
    }
  )

  result
}


#' Compute velocity from position data
#'
#' Computes velocity (first derivative) from position assays in a
#' PhysioExperiment object using finite differences.
#'
#' @param pe A PhysioExperiment object containing position assays.
#' @param assay_names Character vector of assay names to differentiate.
#'   If NULL (default), auto-detects position_x/y/z or keypoint_x/y assays.
#' @param method Finite difference method: "central" (default), "forward",
#'   or "backward".
#' @param sampling_rate Sampling rate in Hz. If NULL (default), uses
#'   \code{samplingRate(pe)}.
#'
#' @return PhysioExperiment with new velocity assays added. For 3D marker data,
#'   assays named velocity_x, velocity_y, velocity_z. For 2D keypoint data,
#'   assays named velocity_kp_x, velocity_kp_y.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [computeAcceleration()] for second-order derivatives,
#'   [computeSpeed()] for scalar speed from velocity components,
#'   [differentiate()] for general-purpose numerical differentiation.
#'
#' @export
#' @examples
#' \dontrun{
#' pe <- make_mocap_markers(n_time = 100, n_markers = 4, sr = 120)
#' pe <- computeVelocity(pe)
#' # velocity_x, velocity_y, velocity_z assays are now present
#' }
computeVelocity <- function(pe, assay_names = NULL, method = "central",
                            sampling_rate = NULL) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  method <- match.arg(method, c("central", "forward", "backward"))

  sr <- sampling_rate %||% samplingRate(pe)
  dt <- 1 / sr

  # Auto-detect assay names if not provided
  if (is.null(assay_names)) {
    all_assays <- SummarizedExperiment::assayNames(pe)
    pos_3d <- c("position_x", "position_y", "position_z")
    kp_2d <- c("keypoint_x", "keypoint_y")

    if (all(pos_3d %in% all_assays)) {
      assay_names <- pos_3d
    } else if (all(kp_2d %in% all_assays)) {
      assay_names <- kp_2d
    } else {
      stop("Cannot auto-detect position assays. ",
           "Expected position_x/y/z or keypoint_x/y. ",
           "Provide assay_names explicitly.", call. = FALSE)
    }
  }

  # Determine output naming convention
  is_keypoint <- any(grepl("^keypoint_", assay_names))

  for (aname in assay_names) {
    data <- SummarizedExperiment::assay(pe, aname)
    vel <- differentiate(data, dt = dt, method = method, order = 1L)

    # Build output assay name
    suffix <- sub("^(position|keypoint)_", "", aname)
    if (is_keypoint) {
      out_name <- paste0("velocity_kp_", suffix)
    } else {
      out_name <- paste0("velocity_", suffix)
    }

    SummarizedExperiment::assay(pe, out_name) <- vel
  }

  .recordProv(pe, output_assay = "velocity", .package = "PhysioMoCap")
}


#' Compute acceleration from position or velocity data
#'
#' Computes acceleration (second derivative) from position or velocity assays.
#' If velocity assays already exist, differentiates those (first derivative of
#' velocity). Otherwise, computes the second derivative of position directly.
#'
#' @param pe A PhysioExperiment object.
#' @param assay_names Character vector of assay names to differentiate.
#'   If NULL (default), auto-detects velocity_x/y/z (preferred) or
#'   position_x/y/z assays.
#' @param method Finite difference method: "central" (default), "forward",
#'   or "backward".
#' @param sampling_rate Sampling rate in Hz. If NULL (default), uses
#'   \code{samplingRate(pe)}.
#'
#' @return PhysioExperiment with new accel_x, accel_y, accel_z assays added.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [computeVelocity()] for first-order derivatives,
#'   [computeJerk()] for third-order derivatives,
#'   [differentiate()] for general-purpose numerical differentiation.
#'
#' @export
#' @examples
#' \dontrun{
#' pe <- make_mocap_markers(n_time = 100, n_markers = 4, sr = 120)
#' pe <- computeAcceleration(pe)
#' }
computeAcceleration <- function(pe, assay_names = NULL, method = "central",
                                sampling_rate = NULL) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  method <- match.arg(method, c("central", "forward", "backward"))

  sr <- sampling_rate %||% samplingRate(pe)
  dt <- 1 / sr

  all_assays <- SummarizedExperiment::assayNames(pe)

  # Auto-detect: prefer velocity assays, fall back to position
  from_velocity <- FALSE
  if (is.null(assay_names)) {
    vel_3d <- c("velocity_x", "velocity_y", "velocity_z")
    vel_kp <- c("velocity_kp_x", "velocity_kp_y")
    pos_3d <- c("position_x", "position_y", "position_z")
    kp_2d <- c("keypoint_x", "keypoint_y")

    if (all(vel_3d %in% all_assays)) {
      assay_names <- vel_3d
      from_velocity <- TRUE
    } else if (all(vel_kp %in% all_assays)) {
      assay_names <- vel_kp
      from_velocity <- TRUE
    } else if (all(pos_3d %in% all_assays)) {
      assay_names <- pos_3d
    } else if (all(kp_2d %in% all_assays)) {
      assay_names <- kp_2d
    } else {
      stop("Cannot auto-detect velocity or position assays. ",
           "Provide assay_names explicitly.", call. = FALSE)
    }
  } else {
    from_velocity <- any(grepl("^velocity", assay_names))
  }

  # Determine derivative order based on source
  deriv_order <- if (from_velocity) 1L else 2L

  for (aname in assay_names) {
    data <- SummarizedExperiment::assay(pe, aname)

    if (deriv_order == 2L && method == "central") {
      # Use direct second-order central difference for better accuracy
      accel <- .secondDerivCentral(data, dt)
    } else {
      accel <- differentiate(data, dt = dt, method = method, order = deriv_order)
    }

    # Build output assay name
    suffix <- sub("^(velocity_kp_|velocity_|position_|keypoint_)", "", aname)
    out_name <- paste0("accel_", suffix)

    SummarizedExperiment::assay(pe, out_name) <- accel
  }

  .recordProv(pe, output_assay = "acceleration", .package = "PhysioMoCap")
}


#' Direct second derivative using central difference
#'
#' Computes \code{(x[i+1] - 2*x[i] + x[i-1]) / dt^2} which is more accurate
#' than applying the first derivative formula twice.
#'
#' @param x Numeric vector or matrix.
#' @param dt Time step.
#' @return Differentiated data with NAs at boundaries.
#' @keywords internal
#' @noRd
.secondDerivCentral <- function(x, dt) {
  if (is.matrix(x)) {
    result <- apply(x, 2, function(col) .secondDerivCentralVec(col, dt))
    colnames(result) <- colnames(x)
    return(result)
  }
  .secondDerivCentralVec(x, dt)
}


#' @keywords internal
#' @noRd
.secondDerivCentralVec <- function(x, dt) {
  n <- length(x)
  result <- rep(NA_real_, n)
  if (n < 3) return(result)

  for (i in 2:(n - 1)) {
    if (!is.na(x[i - 1]) && !is.na(x[i]) && !is.na(x[i + 1])) {
      result[i] <- (x[i + 1] - 2 * x[i] + x[i - 1]) / (dt^2)
    }
  }
  result
}


#' Compute jerk from position data
#'
#' Computes jerk (third derivative of position) from position assays.
#'
#' @param pe A PhysioExperiment object containing position assays.
#' @param method Finite difference method: "central" (default), "forward",
#'   or "backward".
#' @param sampling_rate Sampling rate in Hz. If NULL (default), uses
#'   \code{samplingRate(pe)}.
#'
#' @return PhysioExperiment with new jerk_x, jerk_y, jerk_z assays added.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [computeAcceleration()] for second-order derivatives,
#'   [computeVelocity()] for first-order derivatives,
#'   [differentiate()] for general-purpose numerical differentiation.
#'
#' @export
#' @examples
#' \dontrun{
#' pe <- make_mocap_markers(n_time = 100, n_markers = 4, sr = 120)
#' pe <- computeJerk(pe)
#' }
computeJerk <- function(pe, method = "central", sampling_rate = NULL) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  method <- match.arg(method, c("central", "forward", "backward"))

  sr <- sampling_rate %||% samplingRate(pe)
  dt <- 1 / sr

  all_assays <- SummarizedExperiment::assayNames(pe)

  pos_3d <- c("position_x", "position_y", "position_z")
  kp_2d <- c("keypoint_x", "keypoint_y")

  if (all(pos_3d %in% all_assays)) {
    assay_names <- pos_3d
  } else if (all(kp_2d %in% all_assays)) {
    assay_names <- kp_2d
  } else {
    stop("Cannot auto-detect position assays for jerk computation. ",
         "Expected position_x/y/z or keypoint_x/y.", call. = FALSE)
  }

  is_keypoint <- any(grepl("^keypoint_", assay_names))

  for (aname in assay_names) {
    data <- SummarizedExperiment::assay(pe, aname)
    jerk <- differentiate(data, dt = dt, method = method, order = 3L)

    suffix <- sub("^(position|keypoint)_", "", aname)
    if (is_keypoint) {
      out_name <- paste0("jerk_kp_", suffix)
    } else {
      out_name <- paste0("jerk_", suffix)
    }

    SummarizedExperiment::assay(pe, out_name) <- jerk
  }

  .recordProv(pe, output_assay = "jerk", .package = "PhysioMoCap")
}


#' Compute scalar speed from velocity
#'
#' Computes the magnitude of the velocity vector (Euclidean norm) at each
#' time point for each marker/keypoint.
#'
#' @param pe A PhysioExperiment object containing velocity assays.
#' @param velocity_assays Character vector of velocity assay names.
#'   If NULL (default), auto-detects velocity_x/y/z or velocity_kp_x/y.
#'
#' @return PhysioExperiment with a new "speed" assay containing the scalar
#'   speed: \code{sqrt(vx^2 + vy^2 + vz^2)}.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [computeVelocity()] for computing velocity components,
#'   [computeAcceleration()] for computing acceleration.
#'
#' @export
#' @examples
#' \dontrun{
#' pe <- make_mocap_markers(n_time = 100, n_markers = 4, sr = 120)
#' pe <- computeVelocity(pe)
#' pe <- computeSpeed(pe)
#' }
computeSpeed <- function(pe, velocity_assays = NULL) {
  stopifnot(inherits(pe, "PhysioExperiment"))

  all_assays <- SummarizedExperiment::assayNames(pe)

  if (is.null(velocity_assays)) {
    vel_3d <- c("velocity_x", "velocity_y", "velocity_z")
    vel_kp <- c("velocity_kp_x", "velocity_kp_y")

    if (all(vel_3d %in% all_assays)) {
      velocity_assays <- vel_3d
    } else if (all(vel_kp %in% all_assays)) {
      velocity_assays <- vel_kp
    } else {
      stop("Cannot auto-detect velocity assays. ",
           "Compute velocity first with computeVelocity() or ",
           "provide velocity_assays explicitly.", call. = FALSE)
    }
  }

  # Sum of squares across velocity components
  sum_sq <- NULL
  for (aname in velocity_assays) {
    vel <- SummarizedExperiment::assay(pe, aname)
    if (is.null(sum_sq)) {
      sum_sq <- vel^2
    } else {
      sum_sq <- sum_sq + vel^2
    }
  }

  speed <- sqrt(sum_sq)
  SummarizedExperiment::assay(pe, "speed") <- speed

  .recordProv(pe, output_assay = "speed", .package = "PhysioMoCap")
}
