# IMU Processing Functions
# Sensor fusion, gravity removal, and calibration for inertial measurement units.

# --- Internal quaternion helpers ---

#' Quaternion multiplication
#'
#' Multiplies two quaternions q1 and q2 using Hamilton product.
#' Each quaternion is a numeric vector of length 4: (w, x, y, z).
#'
#' @param q1 Numeric vector of length 4 (w, x, y, z).
#' @param q2 Numeric vector of length 4 (w, x, y, z).
#' @return Numeric vector of length 4 (w, x, y, z).
#' @keywords internal
#' @noRd
.quat_mult <- function(q1, q2) {
  w1 <- q1[1]; x1 <- q1[2]; y1 <- q1[3]; z1 <- q1[4]
  w2 <- q2[1]; x2 <- q2[2]; y2 <- q2[3]; z2 <- q2[4]
  c(
    w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
    w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
    w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
    w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2
  )
}


#' Quaternion conjugate
#'
#' Returns the conjugate of a quaternion (negates imaginary components).
#'
#' @param q Numeric vector of length 4 (w, x, y, z).
#' @return Numeric vector of length 4 (w, -x, -y, -z).
#' @keywords internal
#' @noRd
.quat_conj <- function(q) {
  c(q[1], -q[2], -q[3], -q[4])
}


#' Rotate a 3D vector by a quaternion
#'
#' Rotates vector v by quaternion q using: v' = q * (0, v) * q_conj.
#' Returns only the vector (imaginary) part.
#'
#' @param q Numeric vector of length 4 (w, x, y, z).
#' @param v Numeric vector of length 3 (x, y, z).
#' @return Numeric vector of length 3 (rotated vector).
#' @keywords internal
#' @noRd
.quat_rotate_vector <- function(q, v) {
  v_quat <- c(0, v[1], v[2], v[3])
  result <- .quat_mult(.quat_mult(q, v_quat), .quat_conj(q))
  result[2:4]
}


#' Normalize a vector to unit length
#'
#' @param v Numeric vector.
#' @return Unit-length numeric vector, or zero vector if input has zero norm.
#' @keywords internal
#' @noRd
.normalize_vec <- function(v) {
  n <- sqrt(sum(v^2))
  if (n < .Machine$double.eps) return(rep(0, length(v)))
  v / n
}


# --- Internal filter implementations ---

#' Madgwick AHRS filter
#'
#' Implements the Madgwick gradient-descent-based orientation filter for
#' accelerometer and gyroscope data with optional magnetometer.
#'
#' @param accel Numeric matrix (n x 3) of accelerometer readings (m/s^2).
#' @param gyro Numeric matrix (n x 3) of gyroscope readings (rad/s).
#' @param mag Numeric matrix (n x 3) of magnetometer readings, or NULL.
#' @param beta Numeric. Filter gain parameter (default 0.1).
#' @param dt Numeric. Sampling interval in seconds.
#' @return Numeric matrix (n x 4) of quaternions (w, x, y, z) per sample.
#' @keywords internal
#' @noRd
.madgwick_filter <- function(accel, gyro, mag = NULL, beta = 0.1, dt) {
  n <- nrow(accel)
  q_out <- matrix(0, nrow = n, ncol = 4)

  # Initialize to identity quaternion

  q <- c(1, 0, 0, 0)

  for (i in seq_len(n)) {
    ax <- accel[i, 1]; ay <- accel[i, 2]; az <- accel[i, 3]
    wx <- gyro[i, 1];  wy <- gyro[i, 2];  wz <- gyro[i, 3]

    # Gyroscope quaternion rate of change
    q_dot_gyro <- 0.5 * .quat_mult(q, c(0, wx, wy, wz))

    # Normalize accelerometer measurement
    a_norm <- sqrt(ax^2 + ay^2 + az^2)
    if (a_norm > .Machine$double.eps) {
      ax <- ax / a_norm
      ay <- ay / a_norm
      az <- az / a_norm

      # Estimated direction of gravity from quaternion
      qw <- q[1]; qx <- q[2]; qy <- q[3]; qz <- q[4]

      # Objective function: f = q* (0,0,0,1) q - (ax, ay, az)
      # Rotation of gravity reference (0,0,1) by current quaternion estimate
      f <- c(
        2 * (qx * qz - qw * qy) - ax,
        2 * (qw * qx + qy * qz) - ay,
        (qw^2 - qx^2 - qy^2 + qz^2) - az
      )

      # Jacobian (transposed) of f with respect to quaternion
      # J^T * f gives the gradient
      grad <- c(
        -2 * qy * f[1] + 2 * qx * f[2],
         2 * qz * f[1] + 2 * qw * f[2] - 4 * qx * f[3],
        -2 * qw * f[1] + 2 * qz * f[2] - 4 * qy * f[3],
         2 * qx * f[1] + 2 * qy * f[2]
      )

      grad <- .normalize_vec(grad)

      # Apply gradient descent correction
      q <- q + (q_dot_gyro - beta * grad) * dt
    } else {
      # If accelerometer is unreliable, use gyro only
      q <- q + q_dot_gyro * dt
    }

    # Normalize quaternion
    q <- .normalize_vec(q)

    q_out[i, ] <- q
  }

  colnames(q_out) <- c("w", "x", "y", "z")
  q_out
}


#' Complementary filter
#'
#' A simple complementary filter that blends accelerometer-derived tilt
#' with gyroscope-integrated orientation. Only estimates roll and pitch
#' (no yaw from accelerometer alone).
#'
#' @param accel Numeric matrix (n x 3) of accelerometer readings (m/s^2).
#' @param gyro Numeric matrix (n x 3) of gyroscope readings (rad/s).
#' @param alpha Numeric. Complementary filter coefficient (0 to 1).
#'   Higher values trust the gyroscope more. Default 0.98.
#' @param dt Numeric. Sampling interval in seconds.
#' @return Numeric matrix (n x 4) of quaternions (w, x, y, z) per sample.
#' @keywords internal
#' @noRd
.complementary_filter <- function(accel, gyro, alpha = 0.98, dt) {
  n <- nrow(accel)
  q_out <- matrix(0, nrow = n, ncol = 4)

  # Helper: compute roll and pitch from accelerometer reading
  # Convention: gravity reference is (0, 0, -g), so at rest with

  # accel = (0, 0, -g) we expect roll=0, pitch=0.
  # We negate az to match the Madgwick filter convention where gravity
  # reference is (0, 0, 1) in the body frame.
  .accel_to_rp <- function(ax, ay, az) {
    # Treat the normalized accelerometer as pointing opposite to gravity
    # Roll: rotation about X from the XZ plane
    roll <- atan2(ay, -az)
    # Pitch: rotation about Y
    pitch <- atan2(ax, sqrt(ay^2 + az^2))
    c(roll, pitch)
  }

  # Initialize roll, pitch, yaw from accelerometer
  ax <- accel[1, 1]; ay <- accel[1, 2]; az <- accel[1, 3]
  rp <- .accel_to_rp(ax, ay, az)
  roll <- rp[1]
  pitch <- rp[2]
  yaw <- 0

  q <- as.numeric(eulerToQuaternion(roll, pitch, yaw))
  q_out[1, ] <- q

  for (i in seq(2, n)) {
    ax <- accel[i, 1]; ay <- accel[i, 2]; az <- accel[i, 3]
    wx <- gyro[i, 1];  wy <- gyro[i, 2];  wz <- gyro[i, 3]

    # Gyroscope integration: quaternion rate of change
    q_dot <- 0.5 * .quat_mult(q, c(0, wx, wy, wz))
    q_gyro <- .normalize_vec(q + q_dot * dt)

    # Get Euler angles from gyro-predicted quaternion
    euler_gyro <- quaternionToEuler(q_gyro[1], q_gyro[2], q_gyro[3], q_gyro[4],
                                     degrees = FALSE)
    roll_gyro <- euler_gyro[1, "roll"]
    pitch_gyro <- euler_gyro[1, "pitch"]
    yaw_gyro <- euler_gyro[1, "yaw"]

    # Accelerometer-derived tilt angles
    a_norm <- sqrt(ax^2 + ay^2 + az^2)
    if (a_norm > .Machine$double.eps) {
      rp <- .accel_to_rp(ax, ay, az)
      roll_accel <- rp[1]
      pitch_accel <- rp[2]
    } else {
      roll_accel <- roll_gyro
      pitch_accel <- pitch_gyro
    }

    # Complementary blend
    roll <- alpha * roll_gyro + (1 - alpha) * roll_accel
    pitch <- alpha * pitch_gyro + (1 - alpha) * pitch_accel
    yaw <- yaw_gyro  # Yaw from gyro only (no correction without magnetometer)

    # Convert back to quaternion
    q <- as.numeric(eulerToQuaternion(roll, pitch, yaw))
    q <- .normalize_vec(q)

    q_out[i, ] <- q
  }

  colnames(q_out) <- c("w", "x", "y", "z")
  q_out
}


# --- Exported functions ---

#' Estimate orientation from IMU sensors using sensor fusion
#'
#' Fuses accelerometer, gyroscope, and optionally magnetometer data to
#' estimate 3D orientation over time. Returns both quaternion and Euler
#' angle representations.
#'
#' @param accel Numeric matrix (n x 3) of accelerometer readings in m/s^2.
#'   Columns correspond to x, y, z axes.
#' @param gyro Numeric matrix (n x 3) of gyroscope readings in rad/s.
#'   Columns correspond to x, y, z axes.
#' @param mag Numeric matrix (n x 3) of magnetometer readings, or `NULL`
#'   if unavailable. Default `NULL`.
#' @param method Character. Sensor fusion method: `"madgwick"` (default)
#'   or `"complementary"`.
#' @param beta Numeric. Filter gain for the Madgwick filter (default 0.1).
#'   For the complementary filter this parameter sets the alpha coefficient
#'   (gyroscope trust weight). Lower values for Madgwick or higher values
#'   for complementary increase reliance on the gyroscope.
#' @param sampling_rate Numeric. Sampling rate in Hz.
#'
#' @return A data.frame with columns:
#'   \describe{
#'     \item{time}{Time in seconds from start.}
#'     \item{roll}{Roll angle (degrees), rotation about X axis.}
#'     \item{pitch}{Pitch angle (degrees), rotation about Y axis.}
#'     \item{yaw}{Yaw angle (degrees), rotation about Z axis.}
#'     \item{q_w}{Quaternion scalar component.}
#'     \item{q_x}{Quaternion x component.}
#'     \item{q_y}{Quaternion y component.}
#'     \item{q_z}{Quaternion z component.}
#'   }
#'
#' @details
#' The Madgwick filter uses a gradient-descent algorithm to correct
#' gyroscope drift using accelerometer (and optionally magnetometer)
#' measurements. The `beta` parameter controls the correction strength.
#'
#' The complementary filter blends gyroscope integration (high-pass)
#' with accelerometer tilt estimation (low-pass). The `beta` parameter
#' serves as the alpha coefficient, controlling the balance between
#' gyroscope and accelerometer contributions.
#'
#' @references
#' Madgwick SOH, Harrison AJL, Vaidyanathan R (2011). "Estimation of IMU
#' and MARG orientation using a gradient descent algorithm." IEEE
#' International Conference on Rehabilitation Robotics.
#'
#' @seealso [removeGravity()], [calibrateIMU()], [quaternionToEuler()]
#'
#' @export
#' @examples
#' # Simulate static IMU data (sensor resting with gravity along -Z)
#' n <- 100
#' accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
#' gyro <- matrix(0, nrow = n, ncol = 3)
#' result <- estimateOrientation(accel, gyro, sampling_rate = 100)
#' head(result)
estimateOrientation <- function(accel, gyro, mag = NULL,
                                 method = c("madgwick", "complementary"),
                                 beta = 0.1, sampling_rate) {
  method <- match.arg(method)

  # Input validation
  stopifnot(is.matrix(accel) && ncol(accel) == 3)
  stopifnot(is.matrix(gyro) && ncol(gyro) == 3)
  stopifnot(nrow(accel) == nrow(gyro))
  if (!is.null(mag)) {
    stopifnot(is.matrix(mag) && ncol(mag) == 3)
    stopifnot(nrow(mag) == nrow(accel))
  }
  stopifnot(is.numeric(beta) && length(beta) == 1 && beta > 0)
  stopifnot(is.numeric(sampling_rate) && length(sampling_rate) == 1 &&
              sampling_rate > 0)

  n <- nrow(accel)
  dt <- 1 / sampling_rate

  # Run the selected filter
  if (method == "madgwick") {
    quats <- .madgwick_filter(accel, gyro, mag, beta, dt)
  } else {
    quats <- .complementary_filter(accel, gyro, alpha = beta, dt)
  }

  # Convert quaternions to Euler angles using the existing function
  euler <- quaternionToEuler(quats[, 1], quats[, 2], quats[, 3], quats[, 4],
                              degrees = TRUE)

  # Build output data.frame
  time <- seq(0, by = dt, length.out = n)

  data.frame(
    time  = time,
    roll  = as.numeric(euler[, "roll"]),
    pitch = as.numeric(euler[, "pitch"]),
    yaw   = as.numeric(euler[, "yaw"]),
    q_w   = quats[, 1],
    q_x   = quats[, 2],
    q_y   = quats[, 3],
    q_z   = quats[, 4]
  )
}


#' Remove gravity from accelerometer data
#'
#' Subtracts the rotated gravity vector from raw accelerometer data,
#' leaving only dynamic (linear) acceleration. The gravity direction
#' is determined by rotating the reference gravity vector `(0, 0, -g)`
#' from the world frame into the sensor frame using the provided
#' orientation quaternions.
#'
#' @param accel Numeric matrix (n x 3) of raw accelerometer readings
#'   in m/s^2.
#' @param orientation A data.frame or matrix containing orientation
#'   quaternions. If a data.frame, must contain columns `q_w`, `q_x`,
#'   `q_y`, `q_z` (as returned by `estimateOrientation()`). If a
#'   matrix, must have 4 columns (w, x, y, z).
#' @param g Numeric. Gravitational acceleration magnitude
#'   (default 9.81 m/s^2).
#'
#' @return Numeric matrix (n x 3) of dynamic (gravity-free) acceleration.
#'
#' @details
#' For each time step, the gravity vector in the world frame
#' `(0, 0, -g)` is rotated into the sensor frame using the conjugate
#' of the orientation quaternion. This rotated gravity is then
#' subtracted from the raw accelerometer reading.
#'
#' @references
#' Madgwick SOH, Harrison AJL, Vaidyanathan R (2011). "Estimation of IMU
#' and MARG orientation using a gradient descent algorithm." IEEE
#' International Conference on Rehabilitation Robotics.
#'
#' @seealso [estimateOrientation()], [calibrateIMU()], [quaternionToEuler()]
#'
#' @export
#' @examples
#' n <- 100
#' accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
#' gyro <- matrix(0, nrow = n, ncol = 3)
#' ori <- estimateOrientation(accel, gyro, sampling_rate = 100)
#' dyn_accel <- removeGravity(accel, ori)
removeGravity <- function(accel, orientation, g = 9.81) {
  stopifnot(is.matrix(accel) && ncol(accel) == 3)
  stopifnot(is.numeric(g) && length(g) == 1 && g > 0)

  # Extract quaternion columns

  if (is.data.frame(orientation)) {
    stopifnot(all(c("q_w", "q_x", "q_y", "q_z") %in% names(orientation)))
    qw <- orientation$q_w
    qx <- orientation$q_x
    qy <- orientation$q_y
    qz <- orientation$q_z
  } else if (is.matrix(orientation)) {
    stopifnot(ncol(orientation) == 4)
    qw <- orientation[, 1]
    qx <- orientation[, 2]
    qy <- orientation[, 3]
    qz <- orientation[, 4]
  } else {
    stop("'orientation' must be a data.frame or matrix with quaternion data.",
         call. = FALSE)
  }

  n <- nrow(accel)
  stopifnot(length(qw) == n)

  # Gravity vector in world frame (pointing down along -Z)
  gravity_world <- c(0, 0, -g)

  # For each sample, rotate gravity into sensor frame and subtract
  dyn_accel <- matrix(0, nrow = n, ncol = 3)
  for (i in seq_len(n)) {
    q <- c(qw[i], qx[i], qy[i], qz[i])
    # Rotate world gravity into sensor frame: q_conj * gravity * q
    gravity_sensor <- .quat_rotate_vector(.quat_conj(q), gravity_world)
    dyn_accel[i, ] <- accel[i, ] - gravity_sensor
  }

  colnames(dyn_accel) <- c("x", "y", "z")
  dyn_accel
}


#' Calibrate IMU from static data
#'
#' Estimates accelerometer and gyroscope biases from data recorded
#' during a static (motionless) period. The accelerometer bias is
#' computed relative to the expected gravity vector, and the gyroscope
#' bias is the mean angular velocity during the static period.
#'
#' @param accel_static Numeric matrix (n x 3) of accelerometer readings
#'   during the static period, in m/s^2.
#' @param gyro_static Numeric matrix (n x 3) of gyroscope readings
#'   during the static period, in rad/s.
#'
#' @return A list with components:
#'   \describe{
#'     \item{accel_bias}{Numeric vector of length 3. Mean accelerometer
#'       bias for each axis. For a perfectly calibrated sensor at rest,
#'       this would be (0, 0, 0) after accounting for gravity.}
#'     \item{gyro_bias}{Numeric vector of length 3. Mean gyroscope bias
#'       for each axis (rad/s). A stationary sensor should read zero;
#'       any offset is the bias.}
#'   }
#'
#' @details
#' The function assumes the sensor is stationary. The accelerometer bias
#' is estimated by subtracting the expected gravity contribution from the
#' mean accelerometer reading. Gravity direction is inferred from the
#' mean acceleration direction, and its expected magnitude is 9.81 m/s^2.
#'
#' The gyroscope bias is simply the mean of the gyroscope readings during
#' the static period (should be near zero for a stationary sensor).
#'
#' @references
#' Madgwick SOH, Harrison AJL, Vaidyanathan R (2011). "Estimation of IMU
#' and MARG orientation using a gradient descent algorithm." IEEE
#' International Conference on Rehabilitation Robotics.
#'
#' @seealso [estimateOrientation()], [removeGravity()]
#'
#' @export
#' @examples
#' # Simulate static IMU data with known biases
#' n <- 500
#' accel_bias_true <- c(0.05, -0.03, 0.02)
#' gyro_bias_true <- c(0.001, -0.002, 0.0015)
#' accel <- matrix(rep(c(0, 0, -9.81), each = n), ncol = 3) +
#'   matrix(rep(accel_bias_true, each = n), ncol = 3)
#' gyro <- matrix(rep(gyro_bias_true, each = n), ncol = 3)
#' cal <- calibrateIMU(accel, gyro)
calibrateIMU <- function(accel_static, gyro_static) {
  stopifnot(is.matrix(accel_static) && ncol(accel_static) == 3)
  stopifnot(is.matrix(gyro_static) && ncol(gyro_static) == 3)
  stopifnot(nrow(accel_static) > 0 && nrow(gyro_static) > 0)

  # Gyroscope bias: mean reading during static period (should be zero)
  gyro_bias <- colMeans(gyro_static)
  names(gyro_bias) <- c("x", "y", "z")

  # Accelerometer bias: mean reading minus expected gravity
  #
  # Strategy: identify the dominant gravity axis (the axis with the

  # largest absolute mean value), assign +/-9.81 to that axis based on
  # its sign, and set the expected gravity on the other axes to zero.
  # The bias is then the difference between the measured mean and this
  # expected gravity vector.
  accel_mean <- colMeans(accel_static)
  abs_mean <- abs(accel_mean)
  dominant_axis <- which.max(abs_mean)

  gravity_expected <- c(0, 0, 0)
  gravity_expected[dominant_axis] <- sign(accel_mean[dominant_axis]) * 9.81

  accel_bias <- accel_mean - gravity_expected
  names(accel_bias) <- c("x", "y", "z")

  list(
    accel_bias = accel_bias,
    gyro_bias  = gyro_bias
  )
}
