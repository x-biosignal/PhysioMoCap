# Recursive Newton-Euler (RNE) inverse dynamics for the lower limb.
#
# A proper distal-to-proximal chain (foot -> shank -> thigh) that propagates
# segment reaction forces and moments up the kinematic chain. Each segment's
# proximal joint reaction is found from Newton's law and each joint moment from
# the Euler (angular momentum) balance about the segment centre of mass. Ground
# reaction force / free moment enter at the foot; gravity and segment inertia
# enter at every level. Supports the sagittal plane (2D) and 3D.

.GRAVITY <- 9.80665

# Second time-derivative of each column of a matrix, central in the interior and
# a second-order one-sided stencil at the endpoints, sampled at `fs` Hz.
.second_derivative <- function(x, fs) {
  x <- as.matrix(x)
  dt <- 1 / fs
  n <- nrow(x)
  d2 <- matrix(0, n, ncol(x))
  if (n >= 3) {
    d2[2:(n - 1), ] <- (x[3:n, , drop = FALSE] - 2 * x[2:(n - 1), , drop = FALSE] +
                        x[1:(n - 2), , drop = FALSE]) / dt^2
    if (n >= 4) {                      # one-sided 4-point endpoints
      d2[1, ] <- (2 * x[1, ] - 5 * x[2, ] + 4 * x[3, ] - x[4, ]) / dt^2
      d2[n, ] <- (2 * x[n, ] - 5 * x[n - 1, ] + 4 * x[n - 2, ] -
                  x[n - 3, ]) / dt^2
    } else {                           # n == 3: only the central estimate exists
      d2[1, ] <- d2[2, ]; d2[3, ] <- d2[2, ]
    }
  }
  d2
}

# First time-derivative of a vector, central in the interior and a second-order
# one-sided stencil at the endpoints.
.first_derivative <- function(x, fs) {
  x <- as.numeric(x)
  dt <- 1 / fs
  n <- length(x)
  d <- numeric(n)
  if (n >= 3) {
    d[2:(n - 1)] <- (x[3:n] - x[1:(n - 2)]) / (2 * dt)
    d[1] <- (-3 * x[1] + 4 * x[2] - x[3]) / (2 * dt)
    d[n] <- (3 * x[n] - 4 * x[n - 1] + x[n - 2]) / (2 * dt)
  }
  d
}

# 2D cross product (r x F)_z for n x 2 matrices.
.cross2d <- function(r, f) r[, 1] * f[, 2] - r[, 2] * f[, 1]

# Unwrap a segment-angle series to avoid +/-pi jumps before differentiating.
# NA differences do not propagate (a single missing frame stays local rather
# than poisoning the whole cumulative sum).
.unwrap <- function(a) {
  d <- diff(a)
  d <- d - 2 * pi * round(d / (2 * pi))
  d[is.na(d)] <- 0
  out <- a[1] + c(0, cumsum(d))
  out[is.na(a)] <- NA_real_
  out
}

# Segment orientation angle (radians) of the vector distal - proximal (2D).
.segment_angle <- function(prox, dist) {
  .unwrap(atan2(dist[, 2] - prox[, 2], dist[, 1] - prox[, 1]))
}

# Centre of mass of a segment spanning `prox` to `dist` (each an n x d matrix of
# joint-centre coordinates), placed at `fraction` of the segment length from the
# proximal end (the de Leva / Winter COM ratio).
.segment_com <- function(prox, dist, fraction) {
  prox + fraction * (dist - prox)
}

# Linear acceleration of a segment COM trajectory, by second-order numerical
# differentiation at `fs` Hz.
.segment_linear_accel <- function(com, fs) {
  .second_derivative(com, fs)
}

# Gravity vector for a chain expressed in `d` dimensions with the vertical along
# axis `vertical` ("y" for the sagittal x-y plane, "y" or "z" in 3D).
.gravity_vector <- function(gravity, d, vertical = "y") {
  gvec <- numeric(d)
  k <- switch(vertical, y = 2L, z = 3L,
              stop("'vertical' must be \"y\" or \"z\".", call. = FALSE))
  if (k > d) {
    stop(sprintf("vertical = \"%s\" needs %d dimensions, but the chain is %dD.",
                 vertical, k, d), call. = FALSE)
  }
  gvec[k] <- -gravity
  gvec
}

# One RNE segment step (2D). Given the segment's mass/inertia, COM position and
# acceleration, angular acceleration, its proximal joint position, and the
# distal load (force `Fd` acting on this segment at position `rd`, moment `Md`),
# return the proximal reaction force `Fp` and joint moment `Mp` this segment's
# proximal neighbour must supply.
.rne_step_2d <- function(mass, inertia, com, a_com, alpha, r_prox, Fd, rd, Md,
                         gvec) {
  Fp <- mass * a_com - Fd - matrix(gvec, nrow(a_com), 2, byrow = TRUE) * mass
  Mp <- inertia * alpha -
    .cross2d(r_prox - com, Fp) -
    .cross2d(rd - com, Fd) - Md
  list(Fp = Fp, Mp = Mp)
}

#' Recursive Newton-Euler inverse dynamics for the lower limb
#'
#' Computes net ankle, knee and hip joint moments (and the joint reaction
#' forces) with a proper distal-to-proximal recursive Newton-Euler chain
#' (foot -> shank -> thigh). The ground reaction force and free moment enter at
#' the foot; each segment contributes its inertia and gravity. Segment linear
#' and angular accelerations are obtained by numerical differentiation of the
#' marker-derived centre-of-mass and orientation trajectories.
#'
#' @param joints A matrix/data.frame of joint-centre coordinates over time with
#'   columns `ankle_x`, `ankle_y`, `knee_x`, `knee_y`, `hip_x`, `hip_y` and the
#'   foot distal end `toe_x`, `toe_y` (for `dims = "3D"` add the `_z` columns).
#' @param grf A matrix/data.frame with the ground reaction force `fx`, `fy`
#'   (and `fz` for 3D), the centre of pressure `cop_x`, `cop_y` (and `cop_z`),
#'   and an optional free moment: `tz` in 2D, or any of `tx`/`ty`/`tz` in 3D
#'   (each defaulting to 0).
#' @param inertia A segment inertia table as returned by
#'   [estimateSegmentInertia()] (rows `foot`, `shank`, `thigh`).
#' @param sampling_rate Sampling rate in Hz.
#' @param dims `"2D"` (sagittal plane, default) or `"3D"`.
#' @param gravity Gravitational acceleration (default 9.80665 m/s^2).
#' @param vertical Which coordinate axis points up: `"y"` (the default, matching
#'   the sagittal x-y convention) or `"z"`. Only meaningful for `dims = "3D"`;
#'   a 2D chain must use `"y"`. Gravity acts along the negative of this axis, so
#'   getting it wrong silently mis-signs every gravitational moment.
#' @return A data.frame with `time`, the net joint moments
#'   (`ankle_moment`, `knee_moment`, `hip_moment`) and the proximal joint
#'   reaction forces for each joint.
#' @references
#'   Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#'   4th ed. Wiley. Featherstone R (2008). "Rigid Body Dynamics Algorithms."
#' @seealso [estimateSegmentInertia()], [scaleBodyModel()], [inverseDynamics2D()]
#' @export
#' @examples
#' n <- 50
#' joints <- data.frame(
#'   ankle_x = rep(0, n), ankle_y = rep(0.08, n),
#'   toe_x = rep(0.15, n), toe_y = rep(0.03, n),
#'   knee_x = rep(0, n),   knee_y = rep(0.48, n),
#'   hip_x = rep(0, n),    hip_y = rep(0.90, n))
#' grf <- data.frame(fx = rep(0, n), fy = rep(0, n),
#'                   cop_x = rep(0, n), cop_y = rep(0, n))
#' inertia <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
#' inverseDynamicsRNE(joints, grf, inertia, sampling_rate = 100)
inverseDynamicsRNE <- function(joints, grf, inertia, sampling_rate,
                               dims = c("2D", "3D"), gravity = .GRAVITY,
                               vertical = c("y", "z")) {
  dims <- match.arg(dims)
  vertical <- match.arg(vertical)
  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1,
            sampling_rate > 0)
  if (dims == "3D") {
    return(.inverseDynamicsRNE3D(joints, grf, inertia, sampling_rate, gravity,
                                 vertical))
  }
  if (vertical != "y") {
    stop("A 2D sagittal chain is in the x-y plane; use vertical = \"y\".",
         call. = FALSE)
  }
  joints <- as.data.frame(joints)
  grf <- as.data.frame(grf)
  need_j <- c("ankle_x", "ankle_y", "toe_x", "toe_y", "knee_x", "knee_y",
              "hip_x", "hip_y")
  if (!all(need_j %in% names(joints))) {
    stop("2D RNE 'joints' needs columns: ", paste(need_j, collapse = ", "),
         call. = FALSE)
  }
  need_g <- c("fx", "fy", "cop_x", "cop_y")
  if (!all(need_g %in% names(grf))) {
    stop("2D RNE 'grf' needs columns: ", paste(need_g, collapse = ", "),
         call. = FALSE)
  }
  n <- nrow(joints)
  if (n < 3) {
    stop("inverseDynamicsRNE needs at least 3 frames for differentiation.",
         call. = FALSE)
  }
  fs <- sampling_rate

  ip <- function(seg, col) {
    v <- inertia[inertia$segment == seg, col]
    if (length(v) != 1) stop("inertia missing segment '", seg, "'.",
                             call. = FALSE)
    as.numeric(v)
  }

  ankle <- cbind(joints$ankle_x, joints$ankle_y)
  toe   <- cbind(joints$toe_x, joints$toe_y)
  knee  <- cbind(joints$knee_x, joints$knee_y)
  hip   <- cbind(joints$hip_x, joints$hip_y)

  # Segment COM = proximal + com_fraction * (distal - proximal).
  com_foot  <- .segment_com(ankle, toe, ip("foot", "com_proximal_fraction"))
  com_shank <- .segment_com(knee, ankle, ip("shank", "com_proximal_fraction"))
  com_thigh <- .segment_com(hip, knee, ip("thigh", "com_proximal_fraction"))

  a_foot  <- .segment_linear_accel(com_foot, fs)
  a_shank <- .segment_linear_accel(com_shank, fs)
  a_thigh <- .segment_linear_accel(com_thigh, fs)

  al_foot  <- .second_derivative(matrix(.segment_angle(ankle, toe)), fs)[, 1]
  al_shank <- .second_derivative(matrix(.segment_angle(knee, ankle)), fs)[, 1]
  al_thigh <- .second_derivative(matrix(.segment_angle(hip, knee)), fs)[, 1]

  GRF <- cbind(grf$fx, grf$fy)
  cop <- cbind(grf$cop_x, grf$cop_y)
  Tz  <- if ("tz" %in% names(grf)) as.numeric(grf$tz) else rep(0, n)
  gvec <- .gravity_vector(gravity, 2L, vertical)

  foot <- .rne_step_2d(ip("foot", "mass"), ip("foot", "inertia"),
                       com_foot, a_foot, al_foot, ankle, GRF, cop, Tz, gvec)
  shank <- .rne_step_2d(ip("shank", "mass"), ip("shank", "inertia"),
                        com_shank, a_shank, al_shank, knee,
                        -foot$Fp, ankle, -foot$Mp, gvec)
  thigh <- .rne_step_2d(ip("thigh", "mass"), ip("thigh", "inertia"),
                        com_thigh, a_thigh, al_thigh, hip,
                        -shank$Fp, knee, -shank$Mp, gvec)

  data.frame(
    time = (seq_len(n) - 1) / fs,
    ankle_moment = foot$Mp, knee_moment = shank$Mp, hip_moment = thigh$Mp,
    ankle_fx = foot$Fp[, 1], ankle_fy = foot$Fp[, 2],
    knee_fx = shank$Fp[, 1], knee_fy = shank$Fp[, 2],
    hip_fx = thigh$Fp[, 1], hip_fy = thigh$Fp[, 2])
}

# 3D cross product for n x 3 matrices.
.cross3d <- function(a, b) {
  cbind(a[, 2] * b[, 3] - a[, 3] * b[, 2],
        a[, 3] * b[, 1] - a[, 1] * b[, 3],
        a[, 1] * b[, 2] - a[, 2] * b[, 1])
}

# 3D recursive Newton-Euler. The force chain is exact; the moment balance uses
# an axisymmetric (isotropic transverse) segment inertia so the angular term is
# I * alpha with alpha = d/dt(e x de/dt) of the long-axis unit vector e (the
# unobservable long-axis spin is taken as zero). Gravity acts along the negative
# of the `vertical` axis.
.inverseDynamicsRNE3D <- function(joints, grf, inertia, sampling_rate,
                                  gravity = .GRAVITY, vertical = "y") {
  joints <- as.data.frame(joints)
  grf <- as.data.frame(grf)
  need_j <- as.vector(outer(c("ankle", "toe", "knee", "hip"),
                            c("_x", "_y", "_z"), paste0))
  if (!all(need_j %in% names(joints))) {
    stop("3D RNE 'joints' needs x/y/z columns for ankle, toe, knee, hip.",
         call. = FALSE)
  }
  need_g <- c("fx", "fy", "fz", "cop_x", "cop_y", "cop_z")
  if (!all(need_g %in% names(grf))) {
    stop("3D RNE 'grf' needs fx/fy/fz and cop_x/cop_y/cop_z.", call. = FALSE)
  }
  n <- nrow(joints)
  if (n < 3) {
    stop("inverseDynamicsRNE needs at least 3 frames for differentiation.",
         call. = FALSE)
  }
  fs <- sampling_rate
  ip <- function(seg, col) {
    v <- inertia[inertia$segment == seg, col]
    if (length(v) != 1) stop("inertia missing segment '", seg, "'.",
                             call. = FALSE)
    as.numeric(v)
  }
  jm <- function(m) cbind(joints[[paste0(m, "_x")]], joints[[paste0(m, "_y")]],
                          joints[[paste0(m, "_z")]])
  ankle <- jm("ankle"); toe <- jm("toe"); knee <- jm("knee"); hip <- jm("hip")

  com_seg <- function(prox, dist, seg) {
    .segment_com(prox, dist, ip(seg, "com_proximal_fraction"))
  }
  gvec0 <- .gravity_vector(gravity, 3L, vertical)
  # Angular acceleration of a segment from its long-axis unit vector.
  ang_accel <- function(prox, dist) {
    e <- .normalize_rows(dist - prox)
    edot <- apply(e, 2, .first_derivative, fs = fs)
    omega <- .cross3d(e, edot)
    apply(omega, 2, .first_derivative, fs = fs)   # alpha (n x 3)
  }

  segstep <- function(seg, prox, dist, Fd, rd, Md) {
    com <- com_seg(prox, dist, seg)
    a_com <- .segment_linear_accel(com, fs)
    alpha <- ang_accel(prox, dist)
    m <- ip(seg, "mass"); It <- ip(seg, "inertia")
    gvec <- matrix(gvec0, n, 3, byrow = TRUE)
    Fp <- m * a_com - Fd - m * gvec
    Mp <- It * alpha - .cross3d(prox - com, Fp) - .cross3d(rd - com, Fd) - Md
    list(Fp = Fp, Mp = Mp)
  }

  GRF <- cbind(grf$fx, grf$fy, grf$fz)
  cop <- cbind(grf$cop_x, grf$cop_y, grf$cop_z)
  # Free-moment components default to zero individually (a plate may report only
  # the vertical free moment `tz`).
  col_or_zero <- function(nm) {
    if (nm %in% names(grf)) as.numeric(grf[[nm]]) else rep(0, n)
  }
  Mfree <- cbind(col_or_zero("tx"), col_or_zero("ty"), col_or_zero("tz"))

  foot <- segstep("foot", ankle, toe, GRF, cop, Mfree)
  shank <- segstep("shank", knee, ankle, -foot$Fp, ankle, -foot$Mp)
  thigh <- segstep("thigh", hip, knee, -shank$Fp, knee, -shank$Mp)

  data.frame(
    time = (seq_len(n) - 1) / fs,
    ankle_mx = foot$Mp[, 1], ankle_my = foot$Mp[, 2], ankle_mz = foot$Mp[, 3],
    knee_mx = shank$Mp[, 1], knee_my = shank$Mp[, 2], knee_mz = shank$Mp[, 3],
    hip_mx = thigh$Mp[, 1], hip_my = thigh$Mp[, 2], hip_mz = thigh$Mp[, 3],
    ankle_fx = foot$Fp[, 1], ankle_fy = foot$Fp[, 2], ankle_fz = foot$Fp[, 3],
    knee_fx = shank$Fp[, 1], knee_fy = shank$Fp[, 2], knee_fz = shank$Fp[, 3],
    hip_fx = thigh$Fp[, 1], hip_fy = thigh$Fp[, 2], hip_fz = thigh$Fp[, 3])
}

#' Scale a de Leva segment inertia model to a subject
#'
#' Scales the de Leva (1996) body-segment inertial parameters to a subject's
#' body mass and segment lengths (or stature). A thin, explicitly-named wrapper
#' around [estimateSegmentInertia()].
#'
#' @param body_mass Subject body mass in kg.
#' @param segment_lengths Optional named vector of `foot`, `shank`, `thigh`
#'   lengths (m). If omitted, `body_height` is used with typical ratios.
#' @param body_height Subject stature in m (used when `segment_lengths` is
#'   omitted).
#' @param model `"deLeva_male"` or `"deLeva_female"`.
#' @return A segment inertia data.frame (see [estimateSegmentInertia()]).
#' @references de Leva P (1996). "Adjustments to Zatsiorsky-Seluyanov's segment
#'   inertia parameters." J Biomech, 29(9), 1223-1230.
#' @seealso [scaleBodyModel()], [estimateSegmentInertia()], [inverseDynamicsRNE()]
#' @export
#' @examples
#' scaleSegmentModel(body_mass = 68, body_height = 1.70)
scaleSegmentModel <- function(body_mass, segment_lengths = NULL,
                              body_height = NULL,
                              model = c("deLeva_male", "deLeva_female")) {
  model <- match.arg(model)
  estimateSegmentInertia(body_mass = body_mass,
                         segment_lengths = segment_lengths,
                         body_height = body_height, model = model)
}

#' Scale a body model from marker-measured segment lengths
#'
#' Measures each lower-limb segment length from joint-centre trajectories (the
#' mean over frames of the distance between the segment's endpoints) and scales
#' the de Leva model to the subject's body mass with those measured lengths.
#'
#' @param joints A matrix/data.frame with `ankle`, `toe`, `knee`, `hip` joint
#'   coordinate columns (`_x`/`_y`, plus `_z` for 3D), as for
#'   [inverseDynamicsRNE()].
#' @param body_mass Subject body mass in kg.
#' @param model `"deLeva_male"` or `"deLeva_female"`.
#' @return A segment inertia data.frame with the marker-measured `length`.
#' @seealso [scaleSegmentModel()], [inverseDynamicsRNE()]
#' @export
#' @examples
#' n <- 10
#' joints <- data.frame(
#'   ankle_x = rep(0, n), ankle_y = rep(0.08, n), toe_x = rep(0.15, n),
#'   toe_y = rep(0.03, n), knee_x = rep(0, n), knee_y = rep(0.48, n),
#'   hip_x = rep(0, n), hip_y = rep(0.90, n))
#' scaleBodyModel(joints, body_mass = 70)
scaleBodyModel <- function(joints, body_mass,
                           model = c("deLeva_male", "deLeva_female")) {
  model <- match.arg(model)
  joints <- as.data.frame(joints)
  dims <- if ("ankle_z" %in% names(joints)) c("_x", "_y", "_z") else
    c("_x", "_y")
  pt <- function(m) as.matrix(joints[, paste0(m, dims), drop = FALSE])
  seg_len <- function(a, b) mean(sqrt(rowSums((pt(a) - pt(b))^2)), na.rm = TRUE)
  segment_lengths <- c(foot = seg_len("ankle", "toe"),
                       shank = seg_len("knee", "ankle"),
                       thigh = seg_len("hip", "knee"))
  estimateSegmentInertia(body_mass = body_mass,
                         segment_lengths = segment_lengths, model = model)
}
