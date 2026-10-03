library(testthat)
library(PhysioMoCap)

# --- differentiate(): standalone function ---

test_that("differentiate computes derivative of sin as cos", {
  sr <- 1000
  t <- seq(0, 2 * pi, length.out = sr + 1)
  dt <- t[2] - t[1]
  x <- sin(t)

  dx <- differentiate(x, dt = dt, method = "central", order = 1)

  # Interior points should closely match cos(t)
  interior <- 2:(length(t) - 1)
  expected <- cos(t[interior])
  actual <- dx[interior]

  # Central difference on smooth function at this resolution should be very close

  expect_true(all(!is.na(actual)))
  expect_equal(actual, expected, tolerance = 1e-4)
})

test_that("differentiate computes second derivative of sin as -sin", {
  sr <- 1000
  t <- seq(0, 2 * pi, length.out = sr + 1)
  dt <- t[2] - t[1]
  x <- sin(t)

  d2x <- differentiate(x, dt = dt, method = "central", order = 2)

  # Interior points (need at least 2 from each edge for order=2 via repeated diff)
  interior <- 3:(length(t) - 2)
  expected <- -sin(t[interior])
  actual <- d2x[interior]

  expect_true(all(!is.na(actual)))
  expect_equal(actual, expected, tolerance = 1e-3)
})

test_that("central difference is more accurate than forward difference", {
  sr <- 200
  t <- seq(0, 2 * pi, length.out = sr + 1)
  dt <- t[2] - t[1]
  x <- sin(t)

  dx_central <- differentiate(x, dt = dt, method = "central", order = 1)
  dx_forward <- differentiate(x, dt = dt, method = "forward", order = 1)

  # Compare error on interior (avoid boundaries)
  interior <- 5:(length(t) - 5)
  expected <- cos(t[interior])

  err_central <- mean((dx_central[interior] - expected)^2, na.rm = TRUE)
  err_forward <- mean((dx_forward[interior] - expected)^2, na.rm = TRUE)

  expect_true(err_central < err_forward)
})

test_that("differentiate works with matrix input", {
  sr <- 500
  t <- seq(0, 2 * pi, length.out = sr + 1)
  dt <- t[2] - t[1]
  mat <- cbind(sin(t), cos(t))
  colnames(mat) <- c("ch1", "ch2")

  dmat <- differentiate(mat, dt = dt, method = "central", order = 1)

  expect_true(is.matrix(dmat))
  expect_equal(ncol(dmat), 2)
  expect_equal(nrow(dmat), length(t))
  expect_equal(colnames(dmat), c("ch1", "ch2"))

  # ch1 (sin) derivative should be cos, ch2 (cos) derivative should be -sin
  interior <- 2:(length(t) - 1)
  expect_equal(dmat[interior, 1], cos(t[interior]), tolerance = 1e-4)
  expect_equal(dmat[interior, 2], -sin(t[interior]), tolerance = 1e-4)
})

test_that("differentiate propagates NAs", {
  x <- c(1, 2, NA, 4, 5, 6, 7)
  dt <- 1
  dx <- differentiate(x, dt = dt, method = "central", order = 1)

  # Central diff at index 2: (x[3] - x[1]) / (2*dt), x[3]=NA => NA
  expect_true(is.na(dx[2]))
  # Central diff at index 3: (x[4] - x[2]) / (2*dt), both non-NA => NOT NA
  # (central diff does not use x[i] itself)
  expect_false(is.na(dx[3]))
  # Central diff at index 4: (x[5] - x[3]) / (2*dt), x[3]=NA => NA
  expect_true(is.na(dx[4]))
})

test_that("differentiate errors on invalid order", {
  expect_error(differentiate(1:10, dt = 1, order = 0))
  expect_error(differentiate(1:10, dt = 1, order = 4))
})

test_that("differentiate forward method has NA at last element", {
  x <- c(1, 3, 6, 10, 15)
  dx <- differentiate(x, dt = 1, method = "forward", order = 1)
  expect_true(is.na(dx[5]))
  expect_equal(dx[1], 2)  # (3 - 1) / 1
})

test_that("differentiate backward method has NA at first element", {
  x <- c(1, 3, 6, 10, 15)
  dx <- differentiate(x, dt = 1, method = "backward", order = 1)
  expect_true(is.na(dx[1]))
  expect_equal(dx[2], 2)  # (3 - 1) / 1
})


# --- computeVelocity ---

test_that("computeVelocity auto-detects position_x/y/z and creates velocity assays", {
  pe <- make_mocap_markers(n_time = 100, n_markers = 4, sr = 120)
  pe_vel <- computeVelocity(pe)

  expect_s4_class(pe_vel, "PhysioExperiment")
  expect_true("velocity_x" %in% SummarizedExperiment::assayNames(pe_vel))
  expect_true("velocity_y" %in% SummarizedExperiment::assayNames(pe_vel))
  expect_true("velocity_z" %in% SummarizedExperiment::assayNames(pe_vel))

  # Dimensions should match input
  expect_equal(dim(SummarizedExperiment::assay(pe_vel, "velocity_x")),
               dim(SummarizedExperiment::assay(pe, "position_x")))
})

test_that("computeVelocity auto-detects keypoint_x/y and creates velocity_kp assays", {
  pe <- make_keypoints(n_frames = 50, n_keypoints = 5, sr = 30)
  pe_vel <- computeVelocity(pe)

  expect_true("velocity_kp_x" %in% SummarizedExperiment::assayNames(pe_vel))
  expect_true("velocity_kp_y" %in% SummarizedExperiment::assayNames(pe_vel))
})

test_that("computeVelocity uses correct sampling rate", {
  sr <- 100
  n <- 200
  t <- seq(0, (n - 1) / sr, length.out = n)
  marker_names <- c("M1", "M2")

  # Position is linear: x(t) = 5 * t, so velocity should be ~5
  pos_x <- matrix(rep(5 * t, 2), nrow = n, ncol = 2)
  pos_y <- matrix(0, nrow = n, ncol = 2)
  pos_z <- matrix(0, nrow = n, ncol = 2)
  colnames(pos_x) <- colnames(pos_y) <- colnames(pos_z) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names,
      type = rep("marker", 2)
    ),
    samplingRate = sr
  )

  pe_vel <- computeVelocity(pe)
  vx <- SummarizedExperiment::assay(pe_vel, "velocity_x")

  # All interior points should be close to 5
  interior <- 2:(n - 1)
  expect_equal(vx[interior, 1], rep(5, length(interior)), tolerance = 1e-10)
})

test_that("computeVelocity errors when no position assays found", {
  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = matrix(rnorm(100), nrow = 50, ncol = 2)),
    colData = S4Vectors::DataFrame(label = c("a", "b"), type = c("x", "x")),
    samplingRate = 100
  )
  expect_error(computeVelocity(pe), "Cannot auto-detect position assays")
})


# --- computeAcceleration ---

test_that("computeAcceleration auto-detects velocity assays when present", {
  pe <- make_mocap_markers(n_time = 200, n_markers = 3, sr = 100)
  pe <- computeVelocity(pe)
  pe_acc <- computeAcceleration(pe)

  expect_true("accel_x" %in% SummarizedExperiment::assayNames(pe_acc))
  expect_true("accel_y" %in% SummarizedExperiment::assayNames(pe_acc))
  expect_true("accel_z" %in% SummarizedExperiment::assayNames(pe_acc))
})

test_that("computeAcceleration falls back to position assays when no velocity", {
  pe <- make_mocap_markers(n_time = 200, n_markers = 3, sr = 100)
  pe_acc <- computeAcceleration(pe)

  expect_true("accel_x" %in% SummarizedExperiment::assayNames(pe_acc))
  expect_true("accel_y" %in% SummarizedExperiment::assayNames(pe_acc))
  expect_true("accel_z" %in% SummarizedExperiment::assayNames(pe_acc))
})

test_that("computeAcceleration on sin gives -sin (second derivative)", {
  # Use samplingRate consistent with the time axis:
  # t goes from 0 to 2*pi in n steps, so dt = 2*pi/(n-1), sr = 1/dt
  n <- 2001
  freq <- 1 / (2 * pi)  # frequency so that sin(2*pi*freq*t) = sin(t) over t=0..2pi
  sr <- 1000  # samples per second
  dt <- 1 / sr
  t <- seq(0, (n - 1) * dt, length.out = n)
  # Use a sine wave with known frequency: x(t) = sin(omega*t), omega = 2*pi*freq
  omega <- 2
  marker_names <- "M1"

  pos_x <- matrix(sin(omega * t), nrow = n, ncol = 1)
  pos_y <- matrix(0, nrow = n, ncol = 1)
  pos_z <- matrix(0, nrow = n, ncol = 1)
  colnames(pos_x) <- colnames(pos_y) <- colnames(pos_z) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(label = marker_names, type = "marker"),
    samplingRate = sr
  )

  pe_acc <- computeAcceleration(pe)
  ax <- SummarizedExperiment::assay(pe_acc, "accel_x")

  # Second derivative of sin(omega*t) = -omega^2 * sin(omega*t)
  interior <- 3:(n - 2)
  expected <- -omega^2 * sin(omega * t[interior])
  expect_equal(ax[interior, 1], expected, tolerance = 0.05)
})


# --- computeJerk ---

test_that("computeJerk on cubic polynomial gives known constant", {
  # x(t) = t^3  =>  x'(t) = 3t^2  =>  x''(t) = 6t  =>  x'''(t) = 6
  sr <- 500
  n <- 501
  t <- seq(0, 1, length.out = n)
  dt <- t[2] - t[1]
  marker_names <- "M1"

  pos_x <- matrix(t^3, nrow = n, ncol = 1)
  pos_y <- matrix(0, nrow = n, ncol = 1)
  pos_z <- matrix(0, nrow = n, ncol = 1)
  colnames(pos_x) <- colnames(pos_y) <- colnames(pos_z) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(label = marker_names, type = "marker"),
    samplingRate = sr
  )

  pe_jerk <- computeJerk(pe)
  jx <- SummarizedExperiment::assay(pe_jerk, "jerk_x")

  # Deep interior should be close to 6
  interior <- 10:(n - 10)
  expect_equal(jx[interior, 1], rep(6, length(interior)), tolerance = 0.5)
})


# --- computeSpeed ---

test_that("computeSpeed computes correct magnitude from known velocity", {
  n <- 100
  marker_names <- c("M1", "M2")
  sr <- 100

  # Create PE with known velocity: vx=3, vy=4, vz=0 => speed=5
  vel_x <- matrix(3, nrow = n, ncol = 2)
  vel_y <- matrix(4, nrow = n, ncol = 2)
  vel_z <- matrix(0, nrow = n, ncol = 2)
  colnames(vel_x) <- colnames(vel_y) <- colnames(vel_z) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      velocity_x = vel_x,
      velocity_y = vel_y,
      velocity_z = vel_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names,
      type = rep("marker", 2)
    ),
    samplingRate = sr
  )

  pe_sp <- computeSpeed(pe)
  speed <- SummarizedExperiment::assay(pe_sp, "speed")

  expect_equal(dim(speed), c(n, 2))
  expect_equal(speed[, 1], rep(5, n))
  expect_equal(speed[, 2], rep(5, n))
})

test_that("computeSpeed works with 2D keypoint velocity", {
  n <- 50
  kp_names <- c("nose", "neck")

  vel_kp_x <- matrix(1, nrow = n, ncol = 2)
  vel_kp_y <- matrix(1, nrow = n, ncol = 2)
  colnames(vel_kp_x) <- colnames(vel_kp_y) <- kp_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      velocity_kp_x = vel_kp_x,
      velocity_kp_y = vel_kp_y
    ),
    colData = S4Vectors::DataFrame(
      label = kp_names,
      type = rep("keypoint", 2)
    ),
    samplingRate = 30
  )

  pe_sp <- computeSpeed(pe)
  speed <- SummarizedExperiment::assay(pe_sp, "speed")

  expect_equal(as.numeric(speed[1, 1]), sqrt(2))
})

test_that("computeSpeed errors when no velocity assays found", {
  pe <- make_mocap_markers(n_time = 50, n_markers = 2, sr = 100)
  expect_error(computeSpeed(pe), "Cannot auto-detect velocity assays")
})
