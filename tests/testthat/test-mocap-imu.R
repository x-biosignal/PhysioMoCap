library(testthat)
library(PhysioMoCap)

# --- Quaternion math tests ---

test_that(".quat_mult computes Hamilton product correctly", {
  # Identity * any = any
  q_id <- c(1, 0, 0, 0)
  q <- c(0.5, 0.5, 0.5, 0.5)
  result <- PhysioMoCap:::.quat_mult(q_id, q)
  expect_equal(result, q, tolerance = 1e-10)

  # any * identity = any
  result2 <- PhysioMoCap:::.quat_mult(q, q_id)
  expect_equal(result2, q, tolerance = 1e-10)

  # i * j = k: (0,1,0,0) * (0,0,1,0) = (0,0,0,1)
  qi <- c(0, 1, 0, 0)
  qj <- c(0, 0, 1, 0)
  qk <- c(0, 0, 0, 1)
  expect_equal(PhysioMoCap:::.quat_mult(qi, qj), qk, tolerance = 1e-10)

  # j * k = i: (0,0,1,0) * (0,0,0,1) = (0,1,0,0)
  expect_equal(PhysioMoCap:::.quat_mult(qj, qk), qi, tolerance = 1e-10)

  # k * i = j: (0,0,0,1) * (0,1,0,0) = (0,0,1,0)
  expect_equal(PhysioMoCap:::.quat_mult(qk, qi), qj, tolerance = 1e-10)
})

test_that(".quat_conj negates imaginary parts", {
  q <- c(0.7071, 0.7071, 0, 0)
  result <- PhysioMoCap:::.quat_conj(q)
  expect_equal(result, c(0.7071, -0.7071, 0, 0), tolerance = 1e-10)

  # Conjugate of identity is identity
  expect_equal(PhysioMoCap:::.quat_conj(c(1, 0, 0, 0)), c(1, 0, 0, 0))
})

test_that(".quat_rotate_vector rotates correctly", {
  # 90-degree rotation about Z: (1,0,0) -> (0,1,0)
  q_z90 <- c(cos(pi / 4), 0, 0, sin(pi / 4))
  v <- c(1, 0, 0)
  result <- PhysioMoCap:::.quat_rotate_vector(q_z90, v)
  expect_equal(result, c(0, 1, 0), tolerance = 1e-6)

  # Identity rotation: vector unchanged
  q_id <- c(1, 0, 0, 0)
  v2 <- c(3, 4, 5)
  result2 <- PhysioMoCap:::.quat_rotate_vector(q_id, v2)
  expect_equal(result2, v2, tolerance = 1e-10)

  # 180-degree rotation about Z: (1,0,0) -> (-1,0,0)
  q_z180 <- c(0, 0, 0, 1)
  result3 <- PhysioMoCap:::.quat_rotate_vector(q_z180, c(1, 0, 0))
  expect_equal(result3, c(-1, 0, 0), tolerance = 1e-6)
})

test_that(".quat_mult with conjugate gives identity (unit quaternion)", {
  # q * q_conj = (1, 0, 0, 0) for unit quaternions
  q <- c(cos(pi / 6), sin(pi / 6), 0, 0)  # 60-degree rotation about X
  result <- PhysioMoCap:::.quat_mult(q, PhysioMoCap:::.quat_conj(q))
  expect_equal(result, c(1, 0, 0, 0), tolerance = 1e-10)
})


# --- estimateOrientation tests ---

test_that("estimateOrientation static: accel=[0,0,-9.81] gives roll=0, pitch=0", {
  n <- 200
  accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
  gyro <- matrix(0, nrow = n, ncol = 3)

  result <- estimateOrientation(accel, gyro, sampling_rate = 100)

  expect_s3_class(result, "data.frame")
  expect_true(all(c("time", "roll", "pitch", "yaw",
                     "q_w", "q_x", "q_y", "q_z") %in% names(result)))
  expect_equal(nrow(result), n)

  # For static upright sensor, roll and pitch should converge to near zero
  # Check the last samples (after convergence)
  tail_idx <- (n - 20):n
  expect_equal(result$roll[tail_idx], rep(0, length(tail_idx)),
               tolerance = 1)
  expect_equal(result$pitch[tail_idx], rep(0, length(tail_idx)),
               tolerance = 1)
})

test_that("estimateOrientation static: 90-degree pitch tilt", {
  # Sensor tilted 90 degrees forward: gravity along X
  n <- 300
  accel <- matrix(c(rep(-9.81, n), rep(0, n), rep(0, n)), ncol = 3)
  gyro <- matrix(0, nrow = n, ncol = 3)

  result <- estimateOrientation(accel, gyro, method = "madgwick",
                                 beta = 0.5, sampling_rate = 100)

  # After convergence, pitch should be near 90 degrees
  tail_idx <- (n - 20):n
  expect_equal(abs(result$pitch[tail_idx]), rep(90, length(tail_idx)),
               tolerance = 5)
})

test_that("estimateOrientation gyro integration accumulates rotation", {
  # Constant rotation about Z axis: 1 rad/s for 1 second
  n <- 100
  sr <- 100
  accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
  gyro <- matrix(c(rep(0, n), rep(0, n), rep(1, n)), ncol = 3)

  result <- estimateOrientation(accel, gyro, method = "madgwick",
                                 beta = 0.01, sampling_rate = sr)

  # After 1 second at 1 rad/s, yaw should be approximately 1 radian = 57.3 deg
  # With low beta, gyro dominates
  final_yaw <- result$yaw[n]
  expect_true(abs(final_yaw) > 30)  # Should have meaningful rotation
})

test_that("estimateOrientation complementary filter converges on static data", {
  n <- 200
  accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
  gyro <- matrix(0, nrow = n, ncol = 3)

  result <- estimateOrientation(accel, gyro, method = "complementary",
                                 beta = 0.98, sampling_rate = 100)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), n)

  # Roll and pitch should converge to near zero for static upright data
  tail_idx <- (n - 20):n
  expect_equal(result$roll[tail_idx], rep(0, length(tail_idx)),
               tolerance = 1)
  expect_equal(result$pitch[tail_idx], rep(0, length(tail_idx)),
               tolerance = 1)
})

test_that("estimateOrientation Madgwick and complementary converge to similar result on static data", {
  n <- 500
  accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
  gyro <- matrix(0, nrow = n, ncol = 3)

  result_m <- estimateOrientation(accel, gyro, method = "madgwick",
                                   beta = 0.1, sampling_rate = 100)
  result_c <- estimateOrientation(accel, gyro, method = "complementary",
                                   beta = 0.98, sampling_rate = 100)

  # Both should converge to similar roll/pitch (near zero for static upright)
  tail_idx <- (n - 10):n
  expect_equal(result_m$roll[tail_idx], result_c$roll[tail_idx],
               tolerance = 5)
  expect_equal(result_m$pitch[tail_idx], result_c$pitch[tail_idx],
               tolerance = 5)
})

test_that("estimateOrientation returns correct time column", {
  n <- 50
  sr <- 200
  accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
  gyro <- matrix(0, nrow = n, ncol = 3)

  result <- estimateOrientation(accel, gyro, sampling_rate = sr)

  expected_time <- seq(0, by = 1 / sr, length.out = n)
  expect_equal(result$time, expected_time, tolerance = 1e-12)
})

test_that("estimateOrientation validates inputs", {
  n <- 10
  accel <- matrix(rnorm(n * 3), ncol = 3)
  gyro <- matrix(rnorm(n * 3), ncol = 3)

  # Invalid method
  expect_error(estimateOrientation(accel, gyro, method = "invalid",
                                    sampling_rate = 100))

  # Non-matrix inputs
  expect_error(estimateOrientation(1:10, gyro, sampling_rate = 100))

  # Mismatched rows
  expect_error(estimateOrientation(accel, matrix(0, nrow = n + 1, ncol = 3),
                                    sampling_rate = 100))

  # Invalid beta

  expect_error(estimateOrientation(accel, gyro, beta = -1, sampling_rate = 100))

  # Invalid sampling_rate
  expect_error(estimateOrientation(accel, gyro, sampling_rate = 0))
})

test_that("estimateOrientation quaternions are unit length", {
  n <- 100
  accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
  gyro <- matrix(rnorm(n * 3, sd = 0.1), ncol = 3)

  result <- estimateOrientation(accel, gyro, sampling_rate = 100)

  # All quaternions should be approximately unit length
  q_norms <- sqrt(result$q_w^2 + result$q_x^2 + result$q_y^2 + result$q_z^2)
  expect_equal(q_norms, rep(1, n), tolerance = 1e-6)
})


# --- removeGravity tests ---

test_that("removeGravity static sensor produces near-zero dynamic acceleration", {
  n <- 200
  accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
  gyro <- matrix(0, nrow = n, ncol = 3)

  ori <- estimateOrientation(accel, gyro, sampling_rate = 100, beta = 0.5)
  dyn_accel <- removeGravity(accel, ori)

  expect_equal(ncol(dyn_accel), 3)
  expect_equal(nrow(dyn_accel), n)
  expect_true(!is.null(colnames(dyn_accel)))

  # Dynamic acceleration should be near zero for static sensor
  tail_idx <- (n - 20):n
  expect_equal(as.numeric(dyn_accel[tail_idx, ]),
               rep(0, length(tail_idx) * 3),
               tolerance = 1)
})

test_that("removeGravity works with matrix orientation input", {
  n <- 50
  accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)

  # Identity orientation: gravity is along -Z in both world and sensor frame
  ori_mat <- matrix(rep(c(1, 0, 0, 0), each = n), ncol = 4)

  dyn_accel <- removeGravity(accel, ori_mat)

  # With identity orientation, gravity in sensor frame = (0, 0, -9.81)
  # accel - gravity = (0, 0, -9.81) - (0, 0, -9.81) = 0
  expect_equal(as.numeric(dyn_accel),
               rep(0, n * 3),
               tolerance = 1e-6)
})

test_that("removeGravity preserves dynamic acceleration", {
  n <- 50
  # Sensor with gravity + dynamic acceleration of (1, 0, 0)
  dynamic <- matrix(c(rep(1, n), rep(0, n), rep(0, n)), ncol = 3)
  accel <- matrix(c(rep(1, n), rep(0, n), rep(-9.81, n)), ncol = 3)

  # Identity orientation
  ori_mat <- matrix(rep(c(1, 0, 0, 0), each = n), ncol = 4)

  dyn_accel <- removeGravity(accel, ori_mat)

  # Should recover the dynamic component
  expect_equal(dyn_accel[, 1], rep(1, n), tolerance = 1e-6)
  expect_equal(dyn_accel[, 2], rep(0, n), tolerance = 1e-6)
  expect_equal(dyn_accel[, 3], rep(0, n), tolerance = 1e-6)
})

test_that("removeGravity validates inputs", {
  n <- 10
  accel <- matrix(rnorm(n * 3), ncol = 3)

  expect_error(removeGravity(accel, list(a = 1)))
  expect_error(removeGravity(1:10, matrix(0, n, 4)))
})


# --- calibrateIMU tests ---

test_that("calibrateIMU estimates gyro bias correctly from static data", {
  n <- 500
  gyro_bias_true <- c(0.01, -0.02, 0.015)

  accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
  gyro <- matrix(rep(gyro_bias_true, each = n), ncol = 3) +
    matrix(rnorm(n * 3, sd = 0.001), ncol = 3)

  cal <- calibrateIMU(accel, gyro)

  expect_type(cal, "list")
  expect_true(all(c("accel_bias", "gyro_bias") %in% names(cal)))
  expect_length(cal$gyro_bias, 3)
  expect_length(cal$accel_bias, 3)

  # Gyro bias should be close to true bias
  expect_equal(unname(cal$gyro_bias), gyro_bias_true, tolerance = 0.005)
})

test_that("calibrateIMU estimates accel bias correctly from static data", {
  n <- 500
  accel_bias_true <- c(0.05, -0.03, 0.02)

  # Static sensor: gravity along -Z plus bias
  accel <- matrix(c(rep(0 + accel_bias_true[1], n),
                     rep(0 + accel_bias_true[2], n),
                     rep(-9.81 + accel_bias_true[3], n)), ncol = 3)
  gyro <- matrix(0, nrow = n, ncol = 3)

  cal <- calibrateIMU(accel, gyro)

  # Accel bias should be close to true bias
  expect_equal(unname(cal$accel_bias), accel_bias_true, tolerance = 0.01)
})

test_that("calibrateIMU returns named vectors", {
  n <- 100
  accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
  gyro <- matrix(0, nrow = n, ncol = 3)

  cal <- calibrateIMU(accel, gyro)

  expect_equal(names(cal$accel_bias), c("x", "y", "z"))
  expect_equal(names(cal$gyro_bias), c("x", "y", "z"))
})

test_that("calibrateIMU validates inputs", {
  expect_error(calibrateIMU(1:10, matrix(0, 10, 3)))
  expect_error(calibrateIMU(matrix(0, 10, 3), 1:10))
  expect_error(calibrateIMU(matrix(0, 0, 3), matrix(0, 0, 3)))
})
