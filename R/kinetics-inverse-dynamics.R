# Inverse Dynamics Functions
# Planar inverse dynamics utilities for joint moments and joint power.

#' Estimate segment inertial properties for lower-limb inverse dynamics
#'
#' Builds foot/shank/thigh inertial parameters from body mass and segment
#' lengths using De Leva-style coefficients.
#'
#' @param body_mass Body mass in kilograms.
#' @param segment_lengths Named numeric vector with `foot`, `shank`, and
#'   `thigh` lengths in meters. If `NULL`, lengths are estimated from
#'   `body_height`.
#' @param body_height Body height in meters, required when
#'   `segment_lengths = NULL`.
#' @param model Anthropometric coefficient set: `"deLeva_male"` or
#'   `"deLeva_female"`.
#'
#' @return A data.frame with segment mass, COM fraction, radius of gyration,
#'   and segment moment of inertia about COM.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [segmentParameters()] for body segment inertial parameters,
#'   [inverseDynamics2D()] for 2D inverse dynamics computation,
#'   [inverseDynamics3D()] for 3D inverse dynamics computation.
#'
#' @export
#'
#' @examples
#' inertia <- estimateSegmentInertia(
#'   body_mass = 70,
#'   segment_lengths = c(foot = 0.25, shank = 0.43, thigh = 0.45)
#' )
estimateSegmentInertia <- function(body_mass,
                                   segment_lengths = NULL,
                                   body_height = NULL,
                                   model = c("deLeva_male", "deLeva_female")) {

  model <- match.arg(model)

  stopifnot(is.numeric(body_mass), length(body_mass) == 1, body_mass > 0)

  if (is.null(segment_lengths)) {
    if (!is.numeric(body_height) || length(body_height) != 1 || body_height <= 0) {
      stop("Provide either segment_lengths or a positive body_height.", call. = FALSE)
    }

    # Typical lower-limb segment length ratios relative to body height.
    segment_lengths <- c(
      foot = 0.152 * body_height,
      shank = 0.246 * body_height,
      thigh = 0.245 * body_height
    )
  }

  stopifnot(is.numeric(segment_lengths))

  required <- c("foot", "shank", "thigh")
  if (!all(required %in% names(segment_lengths))) {
    stop("segment_lengths must be a named vector containing: foot, shank, thigh.",
         call. = FALSE)
  }

  lens <- as.numeric(segment_lengths[required])
  if (any(!is.finite(lens) | lens <= 0)) {
    stop("All segment lengths must be positive finite values.", call. = FALSE)
  }

  coeff <- .segment_inertia_coefficients(model)

  mass <- coeff$mass_fraction * body_mass
  com <- coeff$com_proximal_fraction
  rg <- coeff$radius_gyration_fraction
  inertia <- mass * (rg * lens)^2

  data.frame(
    segment = coeff$segment,
    length = lens,
    mass = mass,
    mass_fraction = coeff$mass_fraction,
    com_proximal_fraction = com,
    radius_gyration_fraction = rg,
    inertia = inertia,
    stringsAsFactors = FALSE
  )
}


#' Compute 2D lower-limb joint moments with inverse dynamics
#'
#' Computes sagittal-plane ankle, knee, and hip net moments from joint-center
#' coordinates, GRF, COP, and segment inertial properties, using a recursive
#' link-segment Newton-Euler chain (foot -> shank -> thigh).
#'
#' @param joints Matrix/data.frame with columns `ankle_x`, `ankle_y`,
#'   `knee_x`, `knee_y`, `hip_x`, `hip_y`, and - for
#'   `model = "newton_euler"` - the foot distal end `toe_x`, `toe_y`.
#' @param grf Matrix/data.frame with at least `fx` and `fy` columns, and
#'   optionally `cop_x` and `cop_y`.
#' @param sampling_rate Sampling rate in Hz.
#' @param angles Optional matrix/data.frame with columns `ankle`, `knee`,
#'   `hip` (joint angles).
#' @param angular_velocity Optional matrix/data.frame with columns
#'   `ankle`, `knee`, `hip`.
#' @param angular_acceleration Optional matrix/data.frame with columns
#'   `ankle`, `knee`, `hip`.
#' @param inertial Optional data.frame from `estimateSegmentInertia()`. Required
#'   for `model = "newton_euler"` unless `body_mass` is given; under
#'   `model = "quasi_static"` it only supplies an `I * alpha` correction and is
#'   ignored when omitted.
#' @param angle_unit Unit of `angles`: `"radian"` or `"degree"`.
#' @param model Which dynamics model to use. `"newton_euler"` (the default)
#'   runs the full recursive link-segment Newton-Euler chain via
#'   [inverseDynamicsRNE()]. `"quasi_static"` is the legacy massless-segment
#'   approximation, retained only for reproducing older results (see Details).
#' @param body_mass Body mass in kg. Used to build the segment inertia table
#'   with [estimateSegmentInertia()] when `inertial` is not supplied.
#' @param body_height Body height in m, passed to [estimateSegmentInertia()]
#'   when segment lengths must be estimated from stature. If `NULL`, segment
#'   lengths are measured from the marker data with [scaleBodyModel()].
#' @param gravity Gravitational acceleration in m/s^2.
#'
#' @return A data.frame with time index and joint moments (`ankle_moment`,
#'   `knee_moment`, `hip_moment`). If angular velocity is available,
#'   corresponding power columns are included. `model = "newton_euler"` also
#'   returns the proximal joint reaction forces (`ankle_fx`, `ankle_fy`, ...).
#'
#' @details
#' The default `"newton_euler"` model propagates reactions distal to proximal:
#' the ground reaction force and free moment enter at the foot, and every
#' segment contributes its weight \eqn{m g}, its linear inertia
#' \eqn{m a_{com}} and its angular inertia \eqn{I \alpha}. Segment centres of
#' mass come from the anthropometric ratios in `inertial`, and their linear and
#' angular accelerations from numerical differentiation of the marker
#' trajectories, so a segment mass source (`inertial` or `body_mass`) and the
#' foot distal end (`toe_x`, `toe_y`) are required.
#'
#' Because the recursion differentiates the marker trajectories twice, it
#' amplifies marker noise: the joint moments are only as good as the smoothing
#' applied beforehand. On a static limb sampled at 200 Hz, 1 mm of white marker
#' noise produces a spurious moment about 24 times the true value; a 6 Hz
#' zero-lag low-pass ([butterworthFilter()], or [filterSignals()] on the
#' positions) reduces that by more than an order of magnitude. Filter the marker
#' data before calling this function. The quasi-static model never
#' differentiated positions, so this exposure is new.
#'
#' `"quasi_static"` reproduces the pre-1.0 behaviour: each joint moment is the
#' moment of the *ground reaction force alone* about that joint centre, plus an
#' optional \eqn{I \alpha} term. It omits segment weight and linear inertia
#' entirely, so it returns identically zero whenever the limb is off the ground
#' (the whole swing phase) and underestimates stance moments - at the hip by
#' roughly 8% in quiet standing. It is kept only so that analyses published
#' against the old implementation can be reproduced, and emits a message when
#' selected.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [inverseDynamicsRNE()] for the underlying recursion,
#'   [inverseDynamics3D()] for 3D inverse dynamics computation,
#'   [estimateSegmentInertia()] for segment inertial properties,
#'   [computeJointPower()] for joint power calculation.
#'
#' @export
#'
#' @examples
#' n <- 200
#' joints <- data.frame(
#'   ankle_x = rep(0.00, n), ankle_y = rep(0.05, n),
#'   toe_x   = rep(0.15, n), toe_y   = rep(0.01, n),
#'   knee_x = rep(0.00, n),  knee_y = rep(0.45, n),
#'   hip_x = rep(0.00, n),   hip_y = rep(0.85, n)
#' )
#' grf <- data.frame(fx = rep(0, n), fy = abs(sin(seq(0, pi, length.out = n))) * 800,
#'                   cop_x = rep(0.02, n), cop_y = rep(0, n))
#' id <- inverseDynamics2D(joints, grf, sampling_rate = 100, body_mass = 70)
inverseDynamics2D <- function(joints,
                              grf,
                              sampling_rate,
                              angles = NULL,
                              angular_velocity = NULL,
                              angular_acceleration = NULL,
                              inertial = NULL,
                              angle_unit = c("radian", "degree"),
                              model = c("newton_euler", "quasi_static"),
                              body_mass = NULL,
                              body_height = NULL,
                              gravity = .GRAVITY) {

  angle_unit <- match.arg(angle_unit)
  model <- match.arg(model)
  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1, sampling_rate > 0)

  if (model == "newton_euler") {
    return(.inverseDynamicsNE(joints, grf, sampling_rate, angles,
                              angular_velocity, angular_acceleration, inertial,
                              angle_unit, body_mass, body_height, gravity,
                              dims = "2D", vertical = "y"))
  }
  .quasi_static_notice("inverseDynamics2D")

  joints <- .coerce_joint_centers(joints)
  grf <- .coerce_grf_2d(grf, n_expected = nrow(joints))

  n <- nrow(joints)
  time <- (seq_len(n) - 1) / sampling_rate

  # External moment from GRF about each joint center.
  # Positive sign follows right-hand rule in the sagittal plane.
  m_ankle_ext <- (joints$ankle_x - grf$cop_x) * grf$fy -
    (joints$ankle_y - grf$cop_y) * grf$fx
  m_knee_ext <- (joints$knee_x - grf$cop_x) * grf$fy -
    (joints$knee_y - grf$cop_y) * grf$fx
  m_hip_ext <- (joints$hip_x - grf$cop_x) * grf$fy -
    (joints$hip_y - grf$cop_y) * grf$fx

  alpha <- angular_acceleration
  omega <- angular_velocity

  if (!is.null(angles)) {
    ang <- .coerce_joint_angles(angles, n_expected = n)
    if (angle_unit == "degree") {
      ang <- ang * pi / 180
    }

    dt <- 1 / sampling_rate

    if (is.null(omega)) {
      omega <- data.frame(
        ankle = differentiate(ang$ankle, dt = dt, order = 1L),
        knee = differentiate(ang$knee, dt = dt, order = 1L),
        hip = differentiate(ang$hip, dt = dt, order = 1L)
      )
    } else {
      omega <- .coerce_joint_angles(omega, n_expected = n)
      if (angle_unit == "degree") {
        omega <- omega * pi / 180
      }
    }

    if (is.null(alpha)) {
      alpha <- data.frame(
        ankle = differentiate(omega$ankle, dt = dt, order = 1L),
        knee = differentiate(omega$knee, dt = dt, order = 1L),
        hip = differentiate(omega$hip, dt = dt, order = 1L)
      )
    } else {
      alpha <- .coerce_joint_angles(alpha, n_expected = n)
      if (angle_unit == "degree") {
        alpha <- alpha * pi / 180
      }
    }
  } else {
    if (!is.null(omega)) {
      omega <- .coerce_joint_angles(omega, n_expected = n)
      if (angle_unit == "degree") {
        omega <- omega * pi / 180
      }
    }
    if (!is.null(alpha)) {
      alpha <- .coerce_joint_angles(alpha, n_expected = n)
      if (angle_unit == "degree") {
        alpha <- alpha * pi / 180
      }
    }
  }

  ankle_moment <- m_ankle_ext
  knee_moment <- m_knee_ext
  hip_moment <- m_hip_ext

  if (!is.null(inertial)) {
    inertial <- .validate_inertial_table(inertial)

    i_foot <- inertial$inertia[inertial$segment == "foot"]
    i_shank <- inertial$inertia[inertial$segment == "shank"]
    i_thigh <- inertial$inertia[inertial$segment == "thigh"]

    if (length(i_foot) == 1 && length(i_shank) == 1 && length(i_thigh) == 1 &&
        !is.null(alpha)) {
      ankle_moment <- ankle_moment + i_foot * alpha$ankle
      knee_moment <- knee_moment + i_shank * alpha$knee
      hip_moment <- hip_moment + i_thigh * alpha$hip
    }
  }

  out <- data.frame(
    time = time,
    ankle_moment = ankle_moment,
    knee_moment = knee_moment,
    hip_moment = hip_moment,
    stringsAsFactors = FALSE
  )

  if (!is.null(omega)) {
    out$ankle_power <- computeJointPower(out$ankle_moment, omega$ankle)
    out$knee_power <- computeJointPower(out$knee_moment, omega$knee)
    out$hip_power <- computeJointPower(out$hip_moment, omega$hip)
  }

  out
}


#' Compute 3D lower-limb joint moments with inverse dynamics
#'
#' Computes ankle, knee, and hip net moment vectors in 3D from joint-center
#' coordinates, GRF, COP, and segment inertial properties, using a recursive
#' link-segment Newton-Euler chain (foot -> shank -> thigh).
#'
#' @param joints Matrix/data.frame with columns `ankle_x`, `ankle_y`, `ankle_z`,
#'   `knee_x`, `knee_y`, `knee_z`, `hip_x`, `hip_y`, `hip_z`, and - for
#'   `model = "newton_euler"` - the foot distal end `toe_x`, `toe_y`, `toe_z`.
#' @param grf Matrix/data.frame with columns `fx`, `fy`, `fz` and optional
#'   `cop_x`, `cop_y`, `cop_z` (and, for `model = "newton_euler"`, optional free
#'   moments `tx`, `ty`, `tz`).
#' @param sampling_rate Sampling rate in Hz.
#' @param angles Optional matrix/data.frame containing 3D joint angles with
#'   columns `ankle_x`, `ankle_y`, `ankle_z`, `knee_x`, `knee_y`, `knee_z`,
#'   `hip_x`, `hip_y`, `hip_z`.
#' @param angular_velocity Optional 3D joint angular velocity table.
#' @param angular_acceleration Optional 3D joint angular acceleration table.
#' @param inertial Optional data.frame from `estimateSegmentInertia()`. Required
#'   for `model = "newton_euler"` unless `body_mass` is given; under
#'   `model = "quasi_static"` it only supplies an `I * alpha` correction and is
#'   ignored when omitted.
#' @param angle_unit Unit of angle-related inputs: `"radian"` or `"degree"`.
#' @param model Which dynamics model to use: `"newton_euler"` (the default,
#'   the full recursive chain via [inverseDynamicsRNE()]) or `"quasi_static"`
#'   (the legacy massless-segment approximation; see [inverseDynamics2D()]).
#' @param body_mass Body mass in kg, used to build the segment inertia table
#'   with [estimateSegmentInertia()] when `inertial` is not supplied.
#' @param body_height Body height in m, used when segment lengths must be
#'   estimated from stature rather than measured from the markers.
#' @param gravity Gravitational acceleration in m/s^2.
#' @param vertical Which coordinate axis points up, `"y"` (default) or `"z"`.
#'   Gravity acts along the negative of this axis, so it must match the
#'   laboratory convention of `joints`. The default follows this package's
#'   marker convention (x antero-posterior, y vertical, z medio-lateral) and
#'   the sagittal `inverseDynamics2D()`; note that force-plate hardware
#'   normally reports the vertical force as `fz`, so `grf` may need reordering
#'   to match. A mismatch is checked against the marker geometry and warned
#'   about, because the wrong axis silently removes every gravitational moment.
#'   Used only by `model = "newton_euler"`; the quasi-static model has no
#'   gravity term and therefore ignores it.
#'
#' @return A data.frame with time and moment components:
#'   `*_moment_x`, `*_moment_y`, `*_moment_z`. If angular velocity is
#'   available, `*_power_total` columns are included.
#'   `model = "newton_euler"` also returns the proximal joint reaction force
#'   components (`ankle_fx`, `ankle_fy`, `ankle_fz`, ...).
#'
#' @details
#' See [inverseDynamics2D()] for what the two models compute and why the
#' quasi-static one is retained only for reproducibility. The 3D moment balance
#' uses an axisymmetric segment inertia and neglects the gyroscopic
#' \eqn{\omega \times I \omega} term and any spin about the segment long axis,
#' which is not observable from two joint centres.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [inverseDynamicsRNE()] for the underlying recursion,
#'   [inverseDynamics2D()] for sagittal-plane inverse dynamics,
#'   [estimateSegmentInertia()] for segment inertial properties,
#'   [computeJointPower()] for joint power calculation.
#'
#' @export
#'
#' @examples
#' n <- 200
#' joints <- data.frame(
#'   ankle_x = rep(0.00, n), ankle_y = rep(0.05, n), ankle_z = rep(0.00, n),
#'   toe_x   = rep(0.15, n), toe_y   = rep(0.01, n), toe_z   = rep(0.00, n),
#'   knee_x = rep(0.00, n),  knee_y = rep(0.45, n),  knee_z = rep(0.00, n),
#'   hip_x = rep(0.00, n),   hip_y = rep(0.85, n),   hip_z = rep(0.00, n)
#' )
#' grf <- data.frame(
#'   fx = rep(50, n), fy = rep(700, n), fz = rep(0, n),
#'   cop_x = rep(0.02, n), cop_y = rep(0, n), cop_z = rep(0, n)
#' )
#' out <- inverseDynamics3D(joints, grf, sampling_rate = 100, body_mass = 70)
inverseDynamics3D <- function(joints,
                              grf,
                              sampling_rate,
                              angles = NULL,
                              angular_velocity = NULL,
                              angular_acceleration = NULL,
                              inertial = NULL,
                              angle_unit = c("radian", "degree"),
                              model = c("newton_euler", "quasi_static"),
                              body_mass = NULL,
                              body_height = NULL,
                              gravity = .GRAVITY,
                              vertical = c("y", "z")) {

  angle_unit <- match.arg(angle_unit)
  model <- match.arg(model)
  vertical <- match.arg(vertical)
  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1, sampling_rate > 0)

  if (model == "newton_euler") {
    return(.inverseDynamicsNE(joints, grf, sampling_rate, angles,
                              angular_velocity, angular_acceleration, inertial,
                              angle_unit, body_mass, body_height, gravity,
                              dims = "3D", vertical = vertical))
  }
  .quasi_static_notice("inverseDynamics3D")

  joints <- .coerce_joint_centers_3d(joints)
  grf <- .coerce_grf_3d(grf, n_expected = nrow(joints))

  n <- nrow(joints)
  time <- (seq_len(n) - 1) / sampling_rate

  r_ankle <- cbind(
    joints$ankle_x - grf$cop_x,
    joints$ankle_y - grf$cop_y,
    joints$ankle_z - grf$cop_z
  )
  r_knee <- cbind(
    joints$knee_x - grf$cop_x,
    joints$knee_y - grf$cop_y,
    joints$knee_z - grf$cop_z
  )
  r_hip <- cbind(
    joints$hip_x - grf$cop_x,
    joints$hip_y - grf$cop_y,
    joints$hip_z - grf$cop_z
  )

  f_vec <- cbind(grf$fx, grf$fy, grf$fz)
  m_ankle <- .cross_rows(r_ankle, f_vec)
  m_knee <- .cross_rows(r_knee, f_vec)
  m_hip <- .cross_rows(r_hip, f_vec)

  omega <- angular_velocity
  alpha <- angular_acceleration

  if (!is.null(angles)) {
    ang <- .coerce_joint_axes_3d(angles, n_expected = n)
    if (angle_unit == "degree") {
      ang <- ang * pi / 180
    }

    dt <- 1 / sampling_rate
    if (is.null(omega)) {
      omega <- as.data.frame(
        apply(ang, 2, function(v) differentiate(v, dt = dt, order = 1L)),
        stringsAsFactors = FALSE
      )
    } else {
      omega <- .coerce_joint_axes_3d(omega, n_expected = n)
      if (angle_unit == "degree") {
        omega <- omega * pi / 180
      }
    }

    if (is.null(alpha)) {
      alpha <- as.data.frame(
        apply(omega, 2, function(v) differentiate(v, dt = dt, order = 1L)),
        stringsAsFactors = FALSE
      )
    } else {
      alpha <- .coerce_joint_axes_3d(alpha, n_expected = n)
      if (angle_unit == "degree") {
        alpha <- alpha * pi / 180
      }
    }
  } else {
    if (!is.null(omega)) {
      omega <- .coerce_joint_axes_3d(omega, n_expected = n)
      if (angle_unit == "degree") {
        omega <- omega * pi / 180
      }
    }
    if (!is.null(alpha)) {
      alpha <- .coerce_joint_axes_3d(alpha, n_expected = n)
      if (angle_unit == "degree") {
        alpha <- alpha * pi / 180
      }
    }
  }

  if (!is.null(inertial) && !is.null(alpha)) {
    inertial <- .validate_inertial_table(inertial)

    i_foot <- inertial$inertia[inertial$segment == "foot"][1]
    i_shank <- inertial$inertia[inertial$segment == "shank"][1]
    i_thigh <- inertial$inertia[inertial$segment == "thigh"][1]

    if (is.finite(i_foot)) {
      m_ankle <- m_ankle + i_foot * as.matrix(alpha[, c("ankle_x", "ankle_y", "ankle_z")])
    }
    if (is.finite(i_shank)) {
      m_knee <- m_knee + i_shank * as.matrix(alpha[, c("knee_x", "knee_y", "knee_z")])
    }
    if (is.finite(i_thigh)) {
      m_hip <- m_hip + i_thigh * as.matrix(alpha[, c("hip_x", "hip_y", "hip_z")])
    }
  }

  out <- data.frame(
    time = time,
    ankle_moment_x = m_ankle[, 1],
    ankle_moment_y = m_ankle[, 2],
    ankle_moment_z = m_ankle[, 3],
    knee_moment_x = m_knee[, 1],
    knee_moment_y = m_knee[, 2],
    knee_moment_z = m_knee[, 3],
    hip_moment_x = m_hip[, 1],
    hip_moment_y = m_hip[, 2],
    hip_moment_z = m_hip[, 3],
    stringsAsFactors = FALSE
  )

  if (!is.null(omega)) {
    w_ankle <- as.matrix(omega[, c("ankle_x", "ankle_y", "ankle_z")])
    w_knee <- as.matrix(omega[, c("knee_x", "knee_y", "knee_z")])
    w_hip <- as.matrix(omega[, c("hip_x", "hip_y", "hip_z")])

    out$ankle_power_total <- rowSums(m_ankle * w_ankle)
    out$knee_power_total <- rowSums(m_knee * w_knee)
    out$hip_power_total <- rowSums(m_hip * w_hip)
  }

  out
}


#' Compute joint power from moment and angular velocity
#'
#' Joint power is the product of the net joint moment and the joint angular
#' velocity. Positive power (`generation`) reflects concentric muscle action
#' doing work on the segment; negative power (`absorption`) reflects eccentric
#' action absorbing energy. Set `split = TRUE` to return the generation and
#' absorption components alongside the total.
#'
#' @param moment Numeric vector of joint moment values.
#' @param angular_velocity Numeric vector of joint angular velocity in rad/s.
#' @param split Logical; if `TRUE`, return a data frame with the total `power`
#'   split into non-negative `generation` (`P > 0`) and non-positive
#'   `absorption` (`P < 0`) components. Default `FALSE` returns the total power
#'   vector (backward compatible).
#'
#' @return If `split = FALSE`, a numeric vector of joint power (W). If
#'   `split = TRUE`, a data frame with columns `power`, `generation`, and
#'   `absorption` (each in W); `generation + absorption == power` elementwise.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [inverseDynamics2D()] for computing joint moments in 2D,
#'   [inverseDynamics3D()] for computing joint moments in 3D,
#'   [jointWork()] for integrating power into concentric/eccentric work,
#'   [labelPowerBursts()] for Winter power-burst nomenclature.
#'
#' @export
#'
#' @examples
#' computeJointPower(c(10, 12, 8), c(2, 1.5, 1))
#' computeJointPower(c(10, -12, 8), c(2, 1.5, -1), split = TRUE)
computeJointPower <- function(moment, angular_velocity, split = FALSE) {
  if (!is.numeric(moment) || !is.numeric(angular_velocity)) {
    stop("moment and angular_velocity must be numeric.", call. = FALSE)
  }
  if (length(moment) != length(angular_velocity)) {
    stop("moment and angular_velocity must have the same length.", call. = FALSE)
  }
  if (!is.logical(split) || length(split) != 1L || is.na(split)) {
    stop("split must be a single TRUE or FALSE.", call. = FALSE)
  }

  power <- moment * angular_velocity
  if (!split) {
    return(power)
  }

  data.frame(
    power = power,
    generation = pmax(power, 0),
    absorption = pmin(power, 0)
  )
}


#' Integrate joint power into concentric and eccentric work
#'
#' Integrates a joint power time series (from [computeJointPower()]) with the
#' trapezoidal rule to obtain concentric work (integral of positive
#' "generation" power) and eccentric work (integral of negative "absorption"
#' power). Because the trapezoidal rule is linear in the sampled values,
#' `concentric_work + eccentric_work` equals the net integrated work to
#' floating-point precision. Work can optionally be split per gait cycle or
#' movement phase and normalised to body mass.
#'
#' @param power Numeric vector of joint power (W), or a data frame with a
#'   `power` column as returned by `computeJointPower(..., split = TRUE)`.
#' @param sampling_rate Sampling rate in Hz.
#' @param body_mass Optional body mass in kilograms; if supplied, mass-normalised
#'   work columns (`*_per_kg`, J/kg) are added.
#' @param windows Optional named list of integer index vectors, each selecting
#'   the samples of one gait cycle or phase (e.g. from [segmentPhases()]). Work
#'   is computed independently within each window. If `NULL`, work is computed
#'   over the whole series (window label `"full"`).
#'
#' @return A data frame (class `joint_work`) with one row per window and columns
#'   `window`, `concentric_work`, `eccentric_work`, and `net_work` (J), plus the
#'   mass-normalised counterparts when `body_mass` is given.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [computeJointPower()], [labelPowerBursts()].
#'
#' @export
#'
#' @examples
#' t <- seq(0, 1, length.out = 101)
#' power <- 100 * sin(2 * pi * t)
#' jointWork(power, sampling_rate = 100, body_mass = 70)
jointWork <- function(power, sampling_rate, body_mass = NULL, windows = NULL) {
  if (is.data.frame(power)) {
    if (!"power" %in% names(power)) {
      stop("A data frame `power` must contain a `power` column.", call. = FALSE)
    }
    power <- power[["power"]]
  }
  if (!is.numeric(power)) {
    stop("power must be numeric.", call. = FALSE)
  }
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      is.na(sampling_rate) || sampling_rate <= 0) {
    stop("sampling_rate must be a single positive number.", call. = FALSE)
  }
  if (!is.null(body_mass) &&
      (!is.numeric(body_mass) || length(body_mass) != 1L ||
       is.na(body_mass) || body_mass <= 0)) {
    stop("body_mass must be a single positive number or NULL.", call. = FALSE)
  }
  if (anyNA(power)) {
    warning("power contains NA; integrated work will be NA for affected windows.",
            call. = FALSE)
  }
  n <- length(power)
  if (is.null(windows)) {
    windows <- list(full = seq_len(n))
  }
  if (!is.list(windows) || is.null(names(windows)) || any(names(windows) == "")) {
    stop("windows must be a named list of integer index vectors.", call. = FALSE)
  }

  dt <- 1 / sampling_rate
  rows <- lapply(names(windows), function(nm) {
    idx <- windows[[nm]]
    if (!is.numeric(idx) || any(is.na(idx)) || any(idx < 1) || any(idx > n)) {
      stop(sprintf("Window '%s' has out-of-range indices.", nm), call. = FALSE)
    }
    idx <- as.integer(idx)
    if (is.unsorted(idx) || anyDuplicated(idx)) {
      stop(sprintf("Window '%s' indices must be strictly increasing and unique.",
                   nm), call. = FALSE)
    }
    p <- power[idx]
    conc <- .trapz(pmax(p, 0), dt)
    ecc <- .trapz(pmin(p, 0), dt)
    net <- .trapz(p, dt)
    data.frame(
      window = nm,
      concentric_work = conc,
      eccentric_work = ecc,
      net_work = net,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)

  if (!is.null(body_mass)) {
    out$concentric_work_per_kg <- out$concentric_work / body_mass
    out$eccentric_work_per_kg <- out$eccentric_work / body_mass
    out$net_work_per_kg <- out$net_work / body_mass
  }

  rownames(out) <- NULL
  attr(out, "sampling_rate") <- sampling_rate
  attr(out, "body_mass") <- body_mass
  class(out) <- c("joint_work", "data.frame")
  out
}


#' Label joint power bursts with Winter nomenclature
#'
#' Segments a single-gait-cycle joint power time series into contiguous
#' same-sign bursts and assigns Winter's power-phase labels: `A1`/`A2` for the
#' ankle, `H1`-`H3` for the hip, and `K1`-`K4` for the knee. Each canonical
#' burst has an expected sign (generation vs absorption) and an approximate
#' location within the gait cycle; detected bursts are matched to the nearest
#' unused canonical burst of the same sign.
#'
#' The `power` vector is assumed to span exactly one gait cycle (initial contact
#' to the next ipsilateral initial contact), so burst timing is reported as a
#' percentage of the cycle.
#'
#' @param power Numeric vector of joint power (W) over one gait cycle, or a data
#'   frame with a `power` column.
#' @param sampling_rate Sampling rate in Hz.
#' @param joint One of `"ankle"`, `"knee"`, or `"hip"`.
#' @param body_mass Optional body mass in kilograms; if supplied, a `work_per_kg`
#'   column (J/kg) is added.
#'
#' @return A data frame (class `power_bursts`) with one row per detected burst:
#'   `label` (canonical burst name or `NA` if unmatched), `joint`, `type`
#'   (`"generation"` or `"absorption"`), `start_pct`, `end_pct`, `peak_power`
#'   (W, signed), and `work` (J), ordered by time.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons. Power-phase nomenclature A1-A2 / H1-H3 / K1-K4.
#'
#' @seealso [computeJointPower()], [jointWork()].
#'
#' @export
#'
#' @examples
#' t <- seq(0, 1, length.out = 101)
#' ankle_power <- ifelse(t < 0.4, -50 * sin(pi * t / 0.4),
#'                       120 * sin(pi * (t - 0.4) / 0.2) * (t < 0.6))
#' labelPowerBursts(ankle_power, sampling_rate = 100, joint = "ankle")
labelPowerBursts <- function(power, sampling_rate, joint = c("ankle", "knee", "hip"),
                             body_mass = NULL) {
  if (is.data.frame(power)) {
    if (!"power" %in% names(power)) {
      stop("A data frame `power` must contain a `power` column.", call. = FALSE)
    }
    power <- power[["power"]]
  }
  if (!is.numeric(power)) {
    stop("power must be numeric.", call. = FALSE)
  }
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      is.na(sampling_rate) || sampling_rate <= 0) {
    stop("sampling_rate must be a single positive number.", call. = FALSE)
  }
  joint <- match.arg(joint)
  if (!is.null(body_mass) &&
      (!is.numeric(body_mass) || length(body_mass) != 1L ||
       is.na(body_mass) || body_mass <= 0)) {
    stop("body_mass must be a single positive number or NULL.", call. = FALSE)
  }

  if (anyNA(power)) {
    warning("power contains NA; bursts are split at NA samples and their work ",
            "no longer tiles jointWork() totals. Impute or trim NA first.",
            call. = FALSE)
  }

  n <- length(power)
  dt <- 1 / sampling_rate
  bursts <- .detect_power_bursts(power, dt)

  if (nrow(bursts) == 0L) {
    # No sign runs (e.g. a joint held still, all-zero or all-NA power).
    out <- data.frame(
      label = character(0), joint = character(0), type = character(0),
      start_pct = numeric(0), end_pct = numeric(0),
      peak_power = numeric(0), work = numeric(0),
      stringsAsFactors = FALSE
    )
    if (!is.null(body_mass)) {
      out$work_per_kg <- numeric(0)
    }
    rownames(out) <- NULL
    class(out) <- c("power_bursts", "data.frame")
    return(out)
  }

  canon <- .winter_burst_table(joint)
  labels <- .assign_burst_labels(bursts, canon, n)

  out <- data.frame(
    label = labels,
    joint = joint,
    type = ifelse(bursts$sign > 0, "generation", "absorption"),
    start_pct = if (n > 1) 100 * (bursts$start - 1) / (n - 1) else 0,
    end_pct = if (n > 1) 100 * (bursts$end - 1) / (n - 1) else 0,
    peak_power = bursts$peak,
    work = bursts$work,
    stringsAsFactors = FALSE
  )
  if (!is.null(body_mass)) {
    out$work_per_kg <- out$work / body_mass
  }
  rownames(out) <- NULL
  class(out) <- c("power_bursts", "data.frame")
  out
}


#' @keywords internal
#' @noRd
.trapz <- function(y, dt) {
  n <- length(y)
  if (n < 2L) {
    return(0)
  }
  sum((y[-1L] + y[-n]) / 2) * dt
}


#' Detect contiguous same-sign power bursts
#' @keywords internal
#' @noRd
.detect_power_bursts <- function(power, dt) {
  n <- length(power)
  s <- sign(power)
  s[is.na(s)] <- 0
  # Runs of constant sign; zeros (and NA) act as burst boundaries.
  starts <- integer(0)
  ends <- integer(0)
  signs <- numeric(0)
  i <- 1L
  while (i <= n) {
    if (s[i] == 0) {
      i <- i + 1L
      next
    }
    j <- i
    while (j < n && s[j + 1L] == s[i]) {
      j <- j + 1L
    }
    starts <- c(starts, i)
    ends <- c(ends, j)
    signs <- c(signs, s[i])
    i <- j + 1L
  }
  m <- length(starts)
  peak <- numeric(m)
  work <- numeric(m)
  for (k in seq_len(m)) {
    seg <- power[starts[k]:ends[k]]
    peak[k] <- if (signs[k] > 0) max(seg) else min(seg)
    # Trapezoid over the burst plus the half-interval up to the zero crossing
    # on each open boundary, so burst works tile the pmax/pmin decomposition
    # used by jointWork() exactly (Sum of burst work == net integrated work).
    w <- .trapz(seg, dt)
    if (starts[k] > 1L) w <- w + power[starts[k]] / 2 * dt
    if (ends[k] < n)    w <- w + power[ends[k]] / 2 * dt
    work[k] <- w
  }
  data.frame(
    start = starts, end = ends, sign = signs,
    center = (starts + ends) / 2,
    peak = peak, work = work,
    stringsAsFactors = FALSE
  )
}


#' Canonical Winter power-burst table for a joint
#' @keywords internal
#' @noRd
.winter_burst_table <- function(joint) {
  # center = approximate fraction of the gait cycle (IC = 0, toe-off ~ 0.6).
  switch(joint,
    ankle = data.frame(
      label = c("A1", "A2"),
      sign = c(-1, 1),
      center = c(0.25, 0.50),
      stringsAsFactors = FALSE
    ),
    hip = data.frame(
      label = c("H1", "H2", "H3"),
      sign = c(1, -1, 1),
      center = c(0.10, 0.35, 0.60),
      stringsAsFactors = FALSE
    ),
    knee = data.frame(
      label = c("K1", "K2", "K3", "K4"),
      sign = c(-1, 1, -1, -1),
      center = c(0.10, 0.22, 0.45, 0.85),
      stringsAsFactors = FALSE
    )
  )
}


#' Match detected bursts to canonical labels by sign and nearest centre
#'
#' Bursts are visited in temporal order and each is assigned the nearest unused
#' canonical burst of the same sign, using the burst centre as a fraction of the
#' true gait cycle (`0` at initial contact, `1` at the next). Visiting bursts in
#' time order (rather than iterating the canonical table) prevents an early
#' canonical label from stealing a burst that belongs to a later one.
#'
#' @param n Number of samples in the cycle (for the true-cycle fraction).
#' @keywords internal
#' @noRd
.assign_burst_labels <- function(bursts, canon, n) {
  m <- nrow(bursts)
  labels <- rep(NA_character_, m)
  if (m == 0L) {
    return(labels)
  }
  denom <- if (n > 1L) n - 1L else 1
  # burst centre as a fraction of the true gait cycle (0..1)
  frac <- (bursts$center - 1) / denom
  used_canon <- rep(FALSE, nrow(canon))
  for (b in order(frac)) {
    cand <- which(!used_canon & canon$sign == bursts$sign[b])
    if (length(cand) == 0L) {
      next
    }
    best <- cand[which.min(abs(canon$center[cand] - frac[b]))]
    labels[b] <- canon$label[best]
    used_canon[best] <- TRUE
  }
  labels
}


#' Get inertial coefficient table
#' @keywords internal
#' @noRd
.segment_inertia_coefficients <- function(model) {
  if (model == "deLeva_female") {
    return(data.frame(
      segment = c("foot", "shank", "thigh"),
      mass_fraction = c(0.0133, 0.0433, 0.1478),
      com_proximal_fraction = c(0.5000, 0.4330, 0.4330),
      radius_gyration_fraction = c(0.4750, 0.3020, 0.3230),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    segment = c("foot", "shank", "thigh"),
    mass_fraction = c(0.0145, 0.0465, 0.1416),
    com_proximal_fraction = c(0.5000, 0.4330, 0.4330),
    radius_gyration_fraction = c(0.4750, 0.3020, 0.3230),
    stringsAsFactors = FALSE
  )
}


#' Coerce joint-center table
#' @keywords internal
#' @noRd
.coerce_joint_centers <- function(joints) {
  if (!is.matrix(joints) && !is.data.frame(joints)) {
    stop("joints must be a matrix or data.frame.", call. = FALSE)
  }

  j <- as.data.frame(joints)
  req <- c("ankle_x", "ankle_y", "knee_x", "knee_y", "hip_x", "hip_y")
  if (!all(req %in% names(j))) {
    stop("joints must contain columns: ankle_x, ankle_y, knee_x, knee_y, hip_x, hip_y.",
         call. = FALSE)
  }

  out <- j[, req, drop = FALSE]
  for (nm in names(out)) {
    out[[nm]] <- as.numeric(out[[nm]])
  }
  out
}


#' Coerce GRF table for 2D inverse dynamics
#' @keywords internal
#' @noRd
.coerce_grf_2d <- function(grf, n_expected) {
  if (!is.matrix(grf) && !is.data.frame(grf)) {
    stop("grf must be a matrix or data.frame.", call. = FALSE)
  }

  g <- as.data.frame(grf)

  # Canonical lower-case naming.
  names(g) <- tolower(names(g))

  if (!all(c("fx", "fy") %in% names(g))) {
    # Try common alternatives.
    map <- list(
      fx = c("force_x", "grf_x", "ground_force_x"),
      fy = c("force_y", "grf_y", "ground_force_y", "vgrf")
    )

    for (target in names(map)) {
      if (!(target %in% names(g))) {
        cand <- map[[target]]
        hit <- cand[cand %in% names(g)]
        if (length(hit) > 0) {
          g[[target]] <- g[[hit[1]]]
        }
      }
    }
  }

  if (!all(c("fx", "fy") %in% names(g))) {
    stop("grf must contain fx and fy (or recognized aliases).", call. = FALSE)
  }

  if (!("cop_x" %in% names(g))) {
    g$cop_x <- 0
  }
  if (!("cop_y" %in% names(g))) {
    g$cop_y <- 0
  }

  out <- g[, c("fx", "fy", "cop_x", "cop_y"), drop = FALSE]
  for (nm in names(out)) {
    out[[nm]] <- as.numeric(out[[nm]])
  }

  if (nrow(out) != n_expected) {
    stop("grf rows must match joints rows.", call. = FALSE)
  }

  out
}


#' Coerce joint angle table
#' @keywords internal
#' @noRd
.coerce_joint_angles <- function(x, n_expected) {
  if (!is.matrix(x) && !is.data.frame(x)) {
    stop("angles/velocity/acceleration must be matrix or data.frame.",
         call. = FALSE)
  }

  df <- as.data.frame(x)
  names(df) <- tolower(names(df))

  req <- c("ankle", "knee", "hip")
  if (!all(req %in% names(df))) {
    # Try *_angle naming.
    alias <- c(ankle = "ankle_angle", knee = "knee_angle", hip = "hip_angle")
    for (nm in req) {
      if (!(nm %in% names(df)) && alias[[nm]] %in% names(df)) {
        df[[nm]] <- df[[alias[[nm]]]]
      }
    }
  }

  if (!all(req %in% names(df))) {
    stop("Expected columns ankle, knee, hip (or *_angle aliases).", call. = FALSE)
  }

  out <- df[, req, drop = FALSE]
  for (nm in names(out)) {
    out[[nm]] <- as.numeric(out[[nm]])
  }

  if (nrow(out) != n_expected) {
    stop("Angle-related inputs must have the same rows as joints.", call. = FALSE)
  }

  out
}


#' Validate inertial table
#' @keywords internal
#' @noRd
.validate_inertial_table <- function(inertial) {
  if (!is.matrix(inertial) && !is.data.frame(inertial)) {
    stop("inertial must be a data.frame returned by estimateSegmentInertia().",
         call. = FALSE)
  }

  df <- as.data.frame(inertial)
  req <- c("segment", "inertia")
  if (!all(req %in% names(df))) {
    stop("inertial must contain columns: segment, inertia.", call. = FALSE)
  }

  need <- c("foot", "shank", "thigh")
  if (!all(need %in% df$segment)) {
    stop("inertial must include foot, shank, and thigh rows.", call. = FALSE)
  }

  df
}


#' Coerce 3D joint-center table
#' @keywords internal
#' @noRd
.coerce_joint_centers_3d <- function(joints) {
  if (!is.matrix(joints) && !is.data.frame(joints)) {
    stop("joints must be a matrix or data.frame.", call. = FALSE)
  }

  j <- as.data.frame(joints)
  req <- c(
    "ankle_x", "ankle_y", "ankle_z",
    "knee_x", "knee_y", "knee_z",
    "hip_x", "hip_y", "hip_z"
  )

  if (!all(req %in% names(j))) {
    stop(
      "joints must contain columns: ankle_x/y/z, knee_x/y/z, hip_x/y/z.",
      call. = FALSE
    )
  }

  out <- j[, req, drop = FALSE]
  for (nm in names(out)) {
    out[[nm]] <- as.numeric(out[[nm]])
  }
  out
}


#' Coerce GRF table for 3D inverse dynamics
#' @keywords internal
#' @noRd
.coerce_grf_3d <- function(grf, n_expected) {
  if (!is.matrix(grf) && !is.data.frame(grf)) {
    stop("grf must be a matrix or data.frame.", call. = FALSE)
  }

  g <- as.data.frame(grf)
  names(g) <- tolower(names(g))

  aliases <- list(
    fx = c("force_x", "grf_x", "ground_force_x"),
    fy = c("force_y", "grf_y", "ground_force_y", "vgrf_y"),
    fz = c("force_z", "grf_z", "ground_force_z", "vgrf")
  )

  for (nm in names(aliases)) {
    if (!(nm %in% names(g))) {
      hit <- aliases[[nm]][aliases[[nm]] %in% names(g)]
      if (length(hit) > 0) {
        g[[nm]] <- g[[hit[1]]]
      }
    }
  }

  if (!all(c("fx", "fy", "fz") %in% names(g))) {
    stop("grf must contain fx, fy, and fz (or recognized aliases).", call. = FALSE)
  }

  if (!("cop_x" %in% names(g))) {
    g$cop_x <- 0
  }
  if (!("cop_y" %in% names(g))) {
    g$cop_y <- 0
  }
  if (!("cop_z" %in% names(g))) {
    g$cop_z <- 0
  }

  out <- g[, c("fx", "fy", "fz", "cop_x", "cop_y", "cop_z"), drop = FALSE]
  for (nm in names(out)) {
    out[[nm]] <- as.numeric(out[[nm]])
  }

  if (nrow(out) != n_expected) {
    stop("grf rows must match joints rows.", call. = FALSE)
  }

  out
}


#' Coerce 3D joint angle/velocity/acceleration table
#' @keywords internal
#' @noRd
.coerce_joint_axes_3d <- function(x, n_expected) {
  if (!is.matrix(x) && !is.data.frame(x)) {
    stop("angles/velocity/acceleration must be matrix or data.frame.",
         call. = FALSE)
  }

  df <- as.data.frame(x)
  names(df) <- tolower(names(df))

  joints <- c("ankle", "knee", "hip")
  axes <- c("x", "y", "z")

  out <- matrix(NA_real_, nrow = nrow(df), ncol = 9)
  out_names <- character(9)
  missing_cols <- character()

  k <- 0L
  for (j in joints) {
    for (a in axes) {
      k <- k + 1L
      out_names[k] <- paste0(j, "_", a)
      candidates <- c(
        paste0(j, "_", a),
        paste0(j, "_", a, "_angle"),
        paste0(j, "_r", a)
      )
      hit <- candidates[candidates %in% names(df)]
      if (length(hit) > 0) {
        out[, k] <- as.numeric(df[[hit[1]]])
      } else {
        missing_cols <- c(missing_cols, paste0(j, "_", a))
      }
    }
  }

  if (length(missing_cols) > 0) {
    stop(
      "Expected 3D columns for ankle/knee/hip over x/y/z axes.\n",
      "Missing examples: ", paste(head(unique(missing_cols), 3), collapse = ", "),
      call. = FALSE
    )
  }

  colnames(out) <- out_names
  out <- as.data.frame(out, stringsAsFactors = FALSE)

  if (nrow(out) != n_expected) {
    stop("Angle-related inputs must have the same rows as joints.", call. = FALSE)
  }

  out
}


#' Row-wise cross product of two Nx3 matrices
#' @keywords internal
#' @noRd
.cross_rows <- function(a, b) {
  a <- as.matrix(a)
  b <- as.matrix(b)
  if (ncol(a) != 3 || ncol(b) != 3 || nrow(a) != nrow(b)) {
    stop("a and b must be Nx3 matrices with matching rows.", call. = FALSE)
  }

  cbind(
    a[, 2] * b[, 3] - a[, 3] * b[, 2],
    a[, 3] * b[, 1] - a[, 1] * b[, 3],
    a[, 1] * b[, 2] - a[, 2] * b[, 1]
  )
}


#' Announce that the legacy quasi-static model was selected
#'
#' @param fn Name of the calling function, for the message.
#' @return Invisibly `NULL`, called for the message.
#' @keywords internal
#' @noRd
.quasi_static_notice <- function(fn) {
  # Once per session: a loop over many trials should not emit one line per call.
  if (isTRUE(getOption("PhysioMoCap.quasi_static_notified"))) {
    return(invisible(NULL))
  }
  options(PhysioMoCap.quasi_static_notified = TRUE)
  message(sprintf(paste0("%s(model = \"quasi_static\") uses the legacy ",
                         "massless-segment approximation: it omits segment ",
                         "weight and linear inertia, so it returns zero ",
                         "moments whenever the limb is off the ground. It is ",
                         "retained only to reproduce older analyses; use the ",
                         "default model = \"newton_euler\" for physically ",
                         "correct moments."), fn))
  invisible(NULL)
}


#' Validate a segment inertia table for the Newton-Euler chain
#'
#' The recursion needs each segment's mass and COM ratio as well as its moment
#' of inertia, which is more than `.validate_inertial_table()` requires.
#'
#' @param inertial Candidate inertia table.
#' @return The validated table as a data.frame.
#' @keywords internal
#' @noRd
.validate_inertia_ne <- function(inertial) {
  if (!is.matrix(inertial) && !is.data.frame(inertial)) {
    stop("inertial must be a data.frame returned by estimateSegmentInertia().",
         call. = FALSE)
  }
  df <- as.data.frame(inertial)
  req <- c("segment", "mass", "com_proximal_fraction", "inertia")
  missing <- setdiff(req, names(df))
  if (length(missing) > 0) {
    stop(sprintf(paste0("model = \"newton_euler\" needs the inertial columns ",
                        "%s; supply the table from estimateSegmentInertia() ",
                        "or scaleBodyModel()."),
                 paste(missing, collapse = ", ")), call. = FALSE)
  }
  need <- c("foot", "shank", "thigh")
  if (!all(need %in% df$segment)) {
    stop("inertial must include foot, shank, and thigh rows.", call. = FALSE)
  }
  bad <- df$segment %in% need &
    (!is.finite(df$mass) | df$mass <= 0 | !is.finite(df$inertia) |
       df$inertia < 0 | !is.finite(df$com_proximal_fraction))
  if (any(bad)) {
    stop(sprintf(paste0("inertial has non-positive or non-finite values for ",
                        "segment(s): %s."),
                 paste(unique(df$segment[bad]), collapse = ", ")),
         call. = FALSE)
  }
  # The COM ratio places the centre of mass along the segment, so it has to lie
  # between the two joint centres; outside [0, 1] the moment arms are wrong.
  off <- df$segment %in% need &
    (df$com_proximal_fraction < 0 | df$com_proximal_fraction > 1)
  if (any(off)) {
    stop(sprintf(paste0("inertial has com_proximal_fraction outside [0, 1] ",
                        "for segment(s): %s. It is the fraction of the segment ",
                        "length from the proximal joint."),
                 paste(unique(df$segment[off]), collapse = ", ")),
         call. = FALSE)
  }
  df
}


#' Resolve the segment inertia table for the Newton-Euler chain
#'
#' Uses `inertial` when supplied, otherwise builds one from `body_mass` -
#' measuring segment lengths from the markers when `body_height` is absent.
#'
#' @param inertial,body_mass,body_height As in [inverseDynamics2D()].
#' @param joints Coerced joint-centre table (used to measure segment lengths).
#' @return A validated segment inertia data.frame.
#' @keywords internal
#' @noRd
.resolve_segment_inertia <- function(inertial, body_mass, body_height, joints) {
  if (!is.null(inertial)) {
    return(.validate_inertia_ne(inertial))
  }
  if (is.null(body_mass)) {
    stop(paste0("model = \"newton_euler\" needs segment masses: supply ",
                "'inertial' (from estimateSegmentInertia()) or 'body_mass'. ",
                "Use model = \"quasi_static\" only to reproduce results from ",
                "the legacy massless-segment implementation."), call. = FALSE)
  }
  stopifnot(is.numeric(body_mass), length(body_mass) == 1, body_mass > 0)
  tab <- if (is.null(body_height)) {
    tryCatch(scaleBodyModel(joints, body_mass = body_mass),
             error = function(e) {
               stop(paste0("Could not measure segment lengths from the marker ",
                           "data (", conditionMessage(e), "). Supply ",
                           "'body_height' or an 'inertial' table instead."),
                    call. = FALSE)
             })
  } else {
    estimateSegmentInertia(body_mass = body_mass, body_height = body_height)
  }
  .validate_inertia_ne(tab)
}


#' Coerce joint centres for the Newton-Euler chain
#'
#' Unlike `.coerce_joint_centers()` the recursion also needs the foot distal
#' end, because the foot segment's centre of mass lies between ankle and toe.
#'
#' @param joints Candidate joint-centre table.
#' @param dims `"2D"` or `"3D"`.
#' @return A data.frame with exactly the required columns, as numeric.
#' @keywords internal
#' @noRd
.coerce_joint_centers_ne <- function(joints, dims) {
  if (!is.matrix(joints) && !is.data.frame(joints)) {
    stop("joints must be a matrix or data.frame.", call. = FALSE)
  }
  j <- as.data.frame(joints)
  axes <- if (dims == "3D") c("_x", "_y", "_z") else c("_x", "_y")
  req <- as.vector(t(outer(c("ankle", "toe", "knee", "hip"), axes, paste0)))
  missing <- setdiff(req, names(j))
  if (length(missing) > 0) {
    stop(sprintf(paste0("model = \"newton_euler\" needs joint columns %s. ",
                        "The foot distal end (toe) locates the foot centre of ",
                        "mass; without it the chain cannot be closed. Use ",
                        "model = \"quasi_static\" only to reproduce results ",
                        "from the legacy massless-segment implementation."),
                 paste(missing, collapse = ", ")), call. = FALSE)
  }
  out <- j[, req, drop = FALSE]
  for (nm in names(out)) out[[nm]] <- as.numeric(out[[nm]])
  out
}


#' Joint angular velocity for the power columns
#'
#' Reproduces the angle handling of the legacy path: derive omega from `angles`
#' by differentiation unless it was supplied directly, converting from degrees
#' when asked.
#'
#' @param angles,angular_velocity,angle_unit As in [inverseDynamics2D()].
#' @param n Number of frames.
#' @param sampling_rate Sampling rate in Hz.
#' @param coerce The coercion function for this dimensionality.
#' @return A data.frame of angular velocities, or `NULL` if none is available.
#' @keywords internal
#' @noRd
.resolve_joint_omega <- function(angles, angular_velocity, angle_unit, n,
                                 sampling_rate, coerce) {
  if (!is.null(angular_velocity)) {
    omega <- coerce(angular_velocity, n_expected = n)
    if (angle_unit == "degree") omega <- omega * pi / 180
    return(omega)
  }
  if (is.null(angles)) return(NULL)
  ang <- coerce(angles, n_expected = n)
  if (angle_unit == "degree") ang <- ang * pi / 180
  dt <- 1 / sampling_rate
  as.data.frame(lapply(ang, function(v) differentiate(v, dt = dt, order = 1L)))
}


#' Sanity-check the declared vertical axis against the marker geometry
#'
#' Gravity acts along the negative of `vertical`, so declaring the wrong axis
#' silently removes every gravitational moment instead of failing. For an
#' upright lower limb the hip-to-ankle separation is dominated by the vertical
#' axis, which gives a cheap data-driven check.
#'
#' @param jt Coerced joint-centre table.
#' @param dims `"2D"` or `"3D"`.
#' @param vertical The declared up axis.
#' @return Invisibly `NULL`, called for its warning.
#' @keywords internal
#' @noRd
.check_vertical_axis <- function(jt, dims, vertical) {
  axes <- if (dims == "3D") c("x", "y", "z") else c("x", "y")
  span <- vapply(axes, function(a) {
    mean(jt[[paste0("hip_", a)]] - jt[[paste0("ankle_", a)]], na.rm = TRUE)
  }, numeric(1))
  if (!any(is.finite(span))) return(invisible(NULL))
  span[!is.finite(span)] <- 0
  biggest <- max(abs(span))
  if (biggest == 0) return(invisible(NULL))

  if (abs(span[[vertical]]) < 0.5 * biggest) {
    dominant <- axes[which.max(abs(span))]
    warning(sprintf(paste0("The hip-to-ankle separation lies mostly along the ",
                           "%s axis (%.3f) rather than the declared vertical ",
                           "%s axis (%.3f). Gravity acts along -%s, so check ",
                           "that 'vertical' matches your laboratory ",
                           "convention - the wrong axis silently drops the ",
                           "gravitational moments."),
                   dominant, span[[dominant]], vertical, span[[vertical]],
                   vertical), call. = FALSE)
  }
  invisible(NULL)
}


#' Sanity-check that the marker coordinates are in metres
#'
#' Segment masses and gravity are in SI units, so millimetre marker data - a
#' common mistake, since C3D files store millimetres - inflates every moment by
#' a factor of a thousand without any other symptom.
#'
#' @param jt Coerced joint-centre table.
#' @param dims `"2D"` or `"3D"`.
#' @return Invisibly `NULL`, called for its warning.
#' @keywords internal
#' @noRd
.check_marker_scale <- function(jt, dims) {
  axes <- if (dims == "3D") c("x", "y", "z") else c("x", "y")
  d2 <- rowSums(vapply(axes, function(a) {
    (jt[[paste0("hip_", a)]] - jt[[paste0("ankle_", a)]])^2
  }, numeric(nrow(jt))))
  limb <- stats::median(sqrt(d2), na.rm = TRUE)
  if (!is.finite(limb) || limb == 0) return(invisible(NULL))

  if (limb > 2 || limb < 0.2) {
    warning(sprintf(paste0("The hip-to-ankle distance is %.4g, which is not a ",
                           "plausible limb length in metres. Segment masses ",
                           "and gravity are in SI units, so marker ",
                           "coordinates must be in metres (C3D files store ",
                           "millimetres)."), limb), call. = FALSE)
  }
  invisible(NULL)
}


#' Full recursive Newton-Euler inverse dynamics behind inverseDynamics2D/3D
#'
#' Validates the inputs the recursion needs, delegates to
#' [inverseDynamicsRNE()], and presents the result under the column names of
#' the 2D/3D entry points, adding joint power when angular velocity is
#' available.
#'
#' @inheritParams inverseDynamics2D
#' @param dims `"2D"` or `"3D"`.
#' @param vertical Which axis points up.
#' @return A data.frame as documented for [inverseDynamics2D()] /
#'   [inverseDynamics3D()].
#' @keywords internal
#' @noRd
.inverseDynamicsNE <- function(joints, grf, sampling_rate, angles,
                               angular_velocity, angular_acceleration, inertial,
                               angle_unit, body_mass, body_height, gravity,
                               dims, vertical) {
  stopifnot(is.numeric(gravity), length(gravity) == 1, is.finite(gravity),
            gravity >= 0)
  if (!is.null(angular_acceleration)) {
    warning(paste0("'angular_acceleration' is ignored by ",
                   "model = \"newton_euler\": the recursion derives each ",
                   "SEGMENT's angular acceleration from the marker ",
                   "trajectories, which is not the same quantity as a JOINT ",
                   "angular acceleration. It is only used by ",
                   "model = \"quasi_static\"."), call. = FALSE)
  }

  jt <- .coerce_joint_centers_ne(joints, dims)
  n <- nrow(jt)
  if (n < 3L) {
    stop(sprintf(paste0("model = \"newton_euler\" needs at least 3 frames to ",
                        "differentiate the marker trajectories; 'joints' has ",
                        "%d."), n), call. = FALSE)
  }
  dead <- names(jt)[vapply(jt, function(v) !any(is.finite(v)), logical(1))]
  if (length(dead) > 0) {
    stop(sprintf(paste0("Marker coordinate(s) %s contain no finite values, so ",
                        "the segment they define cannot be located."),
                 paste(dead, collapse = ", ")), call. = FALSE)
  }
  .check_vertical_axis(jt, dims, vertical)
  .check_marker_scale(jt, dims)
  inertia <- .resolve_segment_inertia(inertial, body_mass, body_height, jt)

  # Keep the free-moment columns, which the entry-point GRF coercers drop.
  g_in <- as.data.frame(grf)
  names(g_in) <- tolower(names(g_in))
  gr <- if (dims == "3D") .coerce_grf_3d(g_in, n_expected = n) else
    .coerce_grf_2d(g_in, n_expected = n)
  for (nm in c("tx", "ty", "tz")) {
    if (nm %in% names(g_in)) gr[[nm]] <- as.numeric(g_in[[nm]])
  }

  rne <- inverseDynamicsRNE(jt, gr, inertia, sampling_rate = sampling_rate,
                            dims = dims, gravity = gravity,
                            vertical = vertical)

  coerce <- if (dims == "3D") .coerce_joint_axes_3d else .coerce_joint_angles
  omega <- .resolve_joint_omega(angles, angular_velocity, angle_unit, n,
                                sampling_rate, coerce)

  if (dims == "2D") {
    out <- data.frame(time = rne$time,
                      ankle_moment = rne$ankle_moment,
                      knee_moment = rne$knee_moment,
                      hip_moment = rne$hip_moment,
                      stringsAsFactors = FALSE)
    if (!is.null(omega)) {
      out$ankle_power <- computeJointPower(out$ankle_moment, omega$ankle)
      out$knee_power <- computeJointPower(out$knee_moment, omega$knee)
      out$hip_power <- computeJointPower(out$hip_moment, omega$hip)
    }
    force_cols <- c("ankle_fx", "ankle_fy", "knee_fx", "knee_fy",
                    "hip_fx", "hip_fy")
  } else {
    out <- data.frame(time = rne$time,
                      ankle_moment_x = rne$ankle_mx,
                      ankle_moment_y = rne$ankle_my,
                      ankle_moment_z = rne$ankle_mz,
                      knee_moment_x = rne$knee_mx,
                      knee_moment_y = rne$knee_my,
                      knee_moment_z = rne$knee_mz,
                      hip_moment_x = rne$hip_mx,
                      hip_moment_y = rne$hip_my,
                      hip_moment_z = rne$hip_mz,
                      stringsAsFactors = FALSE)
    if (!is.null(omega)) {
      for (j in c("ankle", "knee", "hip")) {
        m <- as.matrix(out[, paste0(j, "_moment_", c("x", "y", "z"))])
        w <- as.matrix(omega[, paste0(j, "_", c("x", "y", "z"))])
        out[[paste0(j, "_power_total")]] <- rowSums(m * w)
      }
    }
    force_cols <- as.vector(t(outer(c("ankle", "knee", "hip"),
                                    c("_fx", "_fy", "_fz"), paste0)))
  }

  cbind(out, rne[, force_cols, drop = FALSE])
}
