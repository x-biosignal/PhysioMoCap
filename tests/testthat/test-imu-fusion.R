# Mahony and Kalman IMU fusion, verified on synthetic IMU data generated from a
# known orientation (accel = gravity in body frame; gyro = Euler rates + bias).

sim_imu <- function(n = 400, sr = 100, gyro_bias = c(0, 0, 0), accel_noise = 0,
                    seed = 1) {
  set.seed(seed)
  t <- seq_len(n) / sr
  roll  <- 0.4 * sin(2 * pi * 0.4 * t)
  pitch <- 0.3 * sin(2 * pi * 0.25 * t + 0.5)
  accel <- cbind(-sin(pitch),
                 sin(roll) * cos(pitch),
                 cos(roll) * cos(pitch)) + matrix(rnorm(n * 3, 0, accel_noise), n, 3)
  gyro <- cbind(c(0, diff(roll)) * sr + gyro_bias[1],
                c(0, diff(pitch)) * sr + gyro_bias[2],
                gyro_bias[3])
  list(t = t, roll = roll, pitch = pitch, accel = accel, gyro = gyro)
}

deg <- 180 / pi                                       # filters return degrees

test_that("Mahony recovers roll and pitch from clean IMU data", {
  d <- sim_imu()
  est <- mahonyAHRS(d$gyro, d$accel, sampling_rate = 100)
  keep <- 50:400                                      # ignore convergence transient
  # Mahony is a complementary filter -> a small dynamic-tracking lag is expected
  expect_lt(max(abs(est$roll[keep] / deg - d$roll[keep])), 0.1)
  expect_lt(max(abs(est$pitch[keep] / deg - d$pitch[keep])), 0.1)
  expect_equal(nrow(est), 400)
  expect_true(all(c("q_w", "q_x", "q_y", "q_z") %in% names(est)))
})

test_that("Kalman recovers orientation AND estimates gyro bias", {
  bias <- c(0.05, -0.03, 0)
  d <- sim_imu(gyro_bias = bias, accel_noise = 0.02, seed = 2)
  est <- kalmanOrientation(d$gyro, d$accel, sampling_rate = 100)
  keep <- 60:400
  expect_lt(max(abs(est$roll[keep] / deg - d$roll[keep])), 0.08)
  expect_lt(max(abs(est$pitch[keep] / deg - d$pitch[keep])), 0.08)
  # the estimated bias (rad/s) approaches the true gyro bias
  b <- attr(est, "bias")
  expect_lt(abs(b["roll"] - bias[1]), 0.02)
  expect_lt(abs(b["pitch"] - bias[2]), 0.02)
})

test_that("Kalman rejects gyro bias better than raw integration", {
  bias <- c(0.1, 0, 0)
  d <- sim_imu(gyro_bias = bias, seed = 3)
  est <- kalmanOrientation(d$gyro, d$accel, sampling_rate = 100)
  raw <- cumsum(d$gyro[, 1]) / 100                    # naive gyro integration drifts (rad)
  kf_err  <- max(abs(est$roll[100:400] / deg - d$roll[100:400]))
  raw_err <- max(abs(raw[100:400] - d$roll[100:400]))
  expect_lt(kf_err, raw_err)                          # fusion beats integration
})

test_that("Kalman uses a magnetometer for yaw when provided", {
  d <- sim_imu(seed = 4)
  yaw_true <- 0.5 * sin(2 * pi * 0.2 * d$t)
  # synthetic level-ish magnetometer pointing to a heading = yaw_true
  mag <- cbind(cos(yaw_true), -sin(yaw_true), 0)
  est <- kalmanOrientation(d$gyro, d$accel, sampling_rate = 100, mag = mag)
  expect_gt(cor(est$yaw, yaw_true), 0.9)
})

test_that("both filters return the estimateOrientation layout", {
  d <- sim_imu(n = 100)
  for (est in list(mahonyAHRS(d$gyro, d$accel, sampling_rate = 100),
                   kalmanOrientation(d$gyro, d$accel, sampling_rate = 100))) {
    expect_true(all(c("time", "roll", "pitch", "yaw",
                      "q_w", "q_x", "q_y", "q_z") %in% names(est)))
  }
})
