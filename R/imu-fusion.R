# Additional IMU sensor-fusion orientation filters.
#
# The package already estimates orientation with a Madgwick / complementary
# filter (estimateOrientation). This adds the two other standard fusions:
#   * Mahony -- a complementary filter on SO(3) with proportional+integral
#     feedback from the accelerometer (and magnetometer) error; robust and cheap.
#   * Kalman -- a per-axis linear Kalman filter that jointly estimates the tilt
#     angle AND the gyroscope bias, the classic optimal gyro/accel fusion.
# Both consume the same gyro (rad/s) + accel data and return the estimateOrientation
# layout (time, roll, pitch, yaw, quaternion). Dependency-free base R; reuses the
# package quaternion helpers.

.imu_cross <- function(a, b) c(a[2]*b[3] - a[3]*b[2], a[3]*b[1] - a[1]*b[3], a[1]*b[2] - a[2]*b[1])

#' Mahony AHRS orientation filter
#'
#' Estimates orientation by integrating the gyroscope while correcting drift with
#' the accelerometer (gravity) and optional magnetometer through a
#' proportional+integral complementary feedback on SO(3) (Mahony et al. 2008).
#'
#' @param gyro `n x 3` angular velocity (rad/s), columns x, y, z.
#' @param accel `n x 3` accelerometer (any consistent unit; normalised
#'   internally).
#' @param sampling_rate Sampling rate (Hz).
#' @param kp,ki Proportional and integral feedback gains (default 1, 0.1).
#' @return a data frame `time, roll, pitch, yaw` (rad) and `q_w, q_x, q_y, q_z`,
#'   matching [estimateOrientation()].
#' @references Mahony R, et al. (2008) IEEE Trans Autom Control 53:1203-1218.
#' @seealso [kalmanOrientation()], [estimateOrientation()]
#' @export
#' @examples
#' n <- 200; sr <- 100; t <- seq_len(n) / sr
#' roll <- 0.3 * sin(2 * pi * 0.5 * t); pitch <- 0.2 * cos(2 * pi * 0.3 * t)
#' accel <- cbind(-sin(pitch), sin(roll) * cos(pitch), cos(roll) * cos(pitch))
#' gyro <- cbind(c(0, diff(roll)) * sr, c(0, diff(pitch)) * sr, 0)
#' est <- mahonyAHRS(gyro, accel, sampling_rate = sr)
#' max(abs(est$roll - roll))
mahonyAHRS <- function(gyro, accel, sampling_rate, kp = 1, ki = 0.1) {
  gyro <- as.matrix(gyro); accel <- as.matrix(accel)
  n <- nrow(gyro); dt <- 1 / sampling_rate
  q <- c(1, 0, 0, 0); iFB <- c(0, 0, 0)
  quats <- matrix(0, n, 4)
  for (i in seq_len(n)) {
    a <- accel[i, ]; na <- sqrt(sum(a^2))
    g <- gyro[i, ]
    if (na > 1e-8) {
      a <- a / na
      v <- c(2 * (q[2]*q[4] - q[1]*q[3]),               # estimated gravity direction
             2 * (q[1]*q[2] + q[3]*q[4]),
             q[1]^2 - q[2]^2 - q[3]^2 + q[4]^2)
      e <- .imu_cross(a, v)                             # accel/gravity error
      if (ki > 0) iFB <- iFB + ki * e * dt
      g <- g + kp * e + iFB
    }
    qDot <- 0.5 * .quat_mult(q, c(0, g[1], g[2], g[3]))
    q <- q + qDot * dt; q <- q / sqrt(sum(q^2))
    quats[i, ] <- q
  }
  eul <- quaternionToEuler(quats[, 1], quats[, 2], quats[, 3], quats[, 4])
  data.frame(time = seq_len(n) * dt,
             roll = as.numeric(eul[, "roll"]), pitch = as.numeric(eul[, "pitch"]),
             yaw = as.numeric(eul[, "yaw"]),
             q_w = quats[, 1], q_x = quats[, 2], q_y = quats[, 3], q_z = quats[, 4])
}

#' Kalman orientation filter (tilt + gyro-bias)
#'
#' Fuses gyroscope and accelerometer with a per-axis linear Kalman filter that
#' estimates both the tilt angle and the (slowly varying) gyroscope bias -- the
#' classic optimal complementary filter. Roll and pitch are corrected by gravity;
#' yaw is integrated (or corrected by a magnetometer heading if supplied).
#'
#' @param gyro `n x 3` angular velocity (rad/s).
#' @param accel `n x 3` accelerometer.
#' @param sampling_rate Sampling rate (Hz).
#' @param mag Optional `n x 3` magnetometer for yaw.
#' @param q_angle,q_bias Process-noise variances for angle and bias (defaults
#'   1e-3, 3e-3).
#' @param r_measure Measurement-noise variance of the accelerometer angle
#'   (default 0.03).
#' @return a data frame `time, roll, pitch, yaw` (rad) and quaternion columns,
#'   plus attribute `bias` (estimated gyro bias per axis).
#' @references Lauszus K (2012) Kalman IMU; Brown & Hwang (1997).
#' @seealso [mahonyAHRS()], [estimateOrientation()]
#' @export
#' @examples
#' n <- 300; sr <- 100; t <- seq_len(n) / sr
#' roll <- 0.4 * sin(2 * pi * 0.4 * t); pitch <- 0.3 * sin(2 * pi * 0.25 * t)
#' accel <- cbind(-sin(pitch), sin(roll) * cos(pitch), cos(roll) * cos(pitch))
#' gyro <- cbind(c(0, diff(roll)) * sr + 0.05, c(0, diff(pitch)) * sr - 0.03, 0)
#' est <- kalmanOrientation(gyro, accel, sampling_rate = sr)
#' max(abs(est$roll - roll))
kalmanOrientation <- function(gyro, accel, sampling_rate, mag = NULL,
                              q_angle = 1e-3, q_bias = 3e-3, r_measure = 0.03) {
  gyro <- as.matrix(gyro); accel <- as.matrix(accel)
  n <- nrow(gyro); dt <- 1 / sampling_rate
  roll_acc  <- atan2(accel[, 2], accel[, 3])
  pitch_acc <- atan2(-accel[, 1], sqrt(accel[, 2]^2 + accel[, 3]^2))
  kalman1 <- function(z, rate) {                        # one axis over time
    ang <- z[1]; bias <- 0; P <- matrix(0, 2, 2); out <- numeric(length(z))
    for (i in seq_along(z)) {
      ang <- ang + dt * (rate[i] - bias)               # predict
      P[1, 1] <- P[1, 1] + dt * (dt * P[2, 2] - P[1, 2] - P[2, 1] + q_angle)
      P[1, 2] <- P[1, 2] - dt * P[2, 2]
      P[2, 1] <- P[2, 1] - dt * P[2, 2]
      P[2, 2] <- P[2, 2] + q_bias * dt
      S <- P[1, 1] + r_measure                          # update
      K <- c(P[1, 1], P[2, 1]) / S
      y <- z[i] - ang
      ang <- ang + K[1] * y; bias <- bias + K[2] * y
      P00 <- P[1, 1]; P01 <- P[1, 2]
      P[1, 1] <- P[1, 1] - K[1] * P00; P[1, 2] <- P[1, 2] - K[1] * P01
      P[2, 1] <- P[2, 1] - K[2] * P00; P[2, 2] <- P[2, 2] - K[2] * P01
      out[i] <- ang
    }
    list(angle = out, bias = bias)
  }
  kr <- kalman1(roll_acc, gyro[, 1]); kp <- kalman1(pitch_acc, gyro[, 2])
  roll <- kr$angle; pitch <- kp$angle
  if (!is.null(mag)) {
    mag <- as.matrix(mag)
    yaw <- atan2(-mag[, 2] * cos(roll) + mag[, 3] * sin(roll),
                 mag[, 1] * cos(pitch) + sin(pitch) *
                   (mag[, 2] * sin(roll) + mag[, 3] * cos(roll)))
  } else {
    yaw <- cumsum(gyro[, 3]) * dt
  }
  quats <- eulerToQuaternion(roll, pitch, yaw)         # eulerToQuaternion expects radians
  deg <- 180 / pi                                      # return degrees, matching estimateOrientation
  out <- data.frame(time = seq_len(n) * dt,
                    roll = roll * deg, pitch = pitch * deg, yaw = yaw * deg,
                    q_w = quats[, 1], q_x = quats[, 2], q_y = quats[, 3], q_z = quats[, 4])
  attr(out, "bias") <- c(roll = kr$bias, pitch = kp$bias)   # gyro-bias in rad/s
  out
}
