library(testthat)

.reach_mj_speed <- function(n = 200L) {
  tau <- seq(0, 1, length.out = n)
  30 * tau^2 - 60 * tau^3 + 30 * tau^4
}


test_that("smooth reach matches anchors and outranks a rough reach", {
  fs <- 200
  smooth <- .reach_mj_speed(200)
  rough <- smooth +
    0.15 * max(smooth) * sin(2 * pi * 8 * seq(0, 1, length.out = 200))

  peak <- peakVelocity(.reach_mj_speed(201))
  expect_equal(as.numeric(peak), 1.875, tolerance = 1e-9)
  expect_equal(attr(peak, "index"), 101L)
  expect_equal_golden(sparc(smooth, fs), "sparc_minjerk", tol = 1e-8)
  expect_equal(ldlj(smooth, fs), -log(204.8), tolerance = 3e-2)
  expect_lt(sparc(rough, fs), sparc(smooth, fs))
  expect_lt(ldlj(rough, fs), ldlj(smooth, fs))
})


test_that("movementUnits counts well-separated submovements", {
  n <- 600
  time <- seq(0, 1, length.out = n)
  bump <- function(mu, sd = 0.03) {
    exp(-((time - mu)^2) / (2 * sd^2))
  }

  expect_equal(as.integer(movementUnits(bump(0.5))), 1L)
  expect_equal(
    as.integer(movementUnits(bump(0.2) + bump(0.5) + bump(0.8))), 3L
  )
  expect_equal(as.integer(movementUnits(.reach_mj_speed(200))), 1L)
  expect_equal(
    as.integer(movementUnits(
      bump(0.45, 0.12) + 0.97 * bump(0.55, 0.12)
    )),
    1L
  )
  expect_equal(as.integer(movementUnits(rep(0, 100))), 0L)
})


test_that("movementUnits handles plateaus and minimum peak distance", {
  plateau <- c(0, 1, 1, 0)
  units <- movementUnits(plateau)
  expect_equal(as.integer(units), 1L)
  expect_equal(attr(units, "peaks"), 2L)
  expect_equal(as.integer(movementUnits(seq(0, 1, length.out = 100))), 0L)

  fs <- 1000
  time <- seq(0, 1, length.out = fs + 1L)
  close_peaks <- exp(-((time - 0.45) / 0.01)^2) +
    0.8 * exp(-((time - 0.50) / 0.01)^2)
  separated <- movementUnits(close_peaks)
  merged <- movementUnits(
    close_peaks, fs = fs, min_peak_distance = 0.10
  )
  expect_equal(as.integer(separated), 2L)
  expect_equal(as.integer(merged), 1L)
  expect_equal(length(attr(merged, "peaks")), 1L)
})


test_that("endpointError satisfies the one-dimensional bias-variance identity", {
  error <- endpointError(c(11, 12, 13, 12), target = 10)

  expect_s3_class(error, "reaching_endpoint_error")
  expect_equal(error$constant_error, 2)
  expect_equal(error$constant_error_axiswise, 2)
  expect_equal(error$variable_error, sqrt(0.5))
  expect_equal(error$absolute_error, 2)
  expect_equal(error$rmse, sqrt(4.5))
  expect_equal(error$effective_width, 4.133 * sqrt(0.5))
  expect_equal(
    error$rmse^2,
    error$constant_error^2 + error$variable_error^2
  )
})


test_that("endpointError satisfies the multivariate bias-variance identity", {
  endpoints <- rbind(c(3, 0), c(3, 2), c(5, 0), c(5, 2))
  error <- endpointError(endpoints, target = c(0, 0))

  expect_equal(error$constant_error, sqrt(17))
  expect_equal(error$constant_error_axiswise, c(4, 1))
  expect_equal(error$variable_error, sqrt(2))
  expect_equal(error$absolute_error, mean(sqrt(c(9, 13, 25, 29))))
  expect_equal(error$rmse, sqrt(19))
  expect_equal(
    error$rmse^2,
    error$constant_error^2 + error$variable_error^2
  )

  single <- endpointError(matrix(c(3, 4), nrow = 1), c(0, 0))
  expect_equal(single$variable_error, 0)
  expect_equal(single$constant_error, 5)
  expect_equal(single$rmse, 5)
})


test_that("endpointError bias-variance identity holds on arbitrary 3D data", {
  set.seed(22)
  endpoints <- matrix(rnorm(300), ncol = 3)
  target <- c(0.5, -1, 2)
  error <- endpointError(endpoints, target)

  expect_equal(
    error$rmse^2,
    error$constant_error^2 + error$variable_error^2,
    tolerance = 1e-12
  )
})


test_that("temporal kinematics recover designed threshold crossings", {
  fs <- 100
  speed <- numeric(100)
  speed[21:80] <- c(
    seq(0, 1, length.out = 30),
    seq(1, 0, length.out = 30)
  )

  movement_time <- movementTime(speed, fs)
  peak <- peakVelocity(speed)
  expect_equal(as.numeric(movement_time), (78 - 23) / fs)
  expect_equal(attr(movement_time, "onset"), 23L)
  expect_equal(attr(movement_time, "offset"), 78L)
  expect_equal(as.numeric(peak), 1)
  expect_equal(attr(peak, "index"), 50L)
  expect_equal(timeToPeakVelocity(speed, fs), (50 - 23) / fs)
  expect_equal(
    timeToPeakVelocity(.reach_mj_speed(201), fs = 200, normalize = TRUE),
    0.5,
    tolerance = 1e-9
  )
})


test_that("temporal kinematics report absent and one-sample movements", {
  absent <- movementTime(rep(0, 20), fs = 100)
  expect_true(is.na(absent))
  expect_true(is.na(attr(absent, "onset")))
  expect_true(is.na(timeToPeakVelocity(rep(0, 20), fs = 100)))

  impulse <- c(0, 0, 1, 0)
  expect_equal(as.numeric(movementTime(impulse, 100)), 0)
  expect_true(is.na(timeToPeakVelocity(impulse, 100, normalize = TRUE)))
})


test_that("trunkCompensation recovers transport split and signed rotation", {
  n <- 50
  hand <- cbind(seq(0, 0.40, length.out = n), rep(0, n), rep(0, n))
  trunk <- cbind(seq(0, 0.10, length.out = n), rep(0, n), rep(0, n))
  theta <- seq(0, pi / 6, length.out = n)
  shoulder_r <- cbind(
    -0.15 * sin(theta), 0.15 * cos(theta), rep(0, n)
  )
  shoulder_l <- cbind(
    0.15 * sin(theta), -0.15 * cos(theta), rep(0, n)
  )

  result <- trunkCompensation(
    trunk, hand, shoulder_r = shoulder_r, shoulder_l = shoulder_l
  )
  expect_s3_class(result, "trunk_compensation")
  expect_equal(result$hand_transport, 0.40, tolerance = 1e-9)
  expect_equal(result$trunk_displacement, 0.10, tolerance = 1e-9)
  expect_equal(result$arm_transport, 0.30, tolerance = 1e-9)
  expect_equal(result$trunk_contribution, 0.25, tolerance = 1e-9)
  expect_equal(result$trunk_rotation, 30, tolerance = 1e-6)
  expect_equal(
    abs(result$trunk_rotation),
    vectorAngle(
      shoulder_r[n, ] - shoulder_l[n, ],
      shoulder_r[1, ] - shoulder_l[1, ]
    ),
    tolerance = 1e-6
  )
})


test_that("trunkCompensation handles frame and transport degeneracies", {
  stationary_hand <- matrix(0, 5, 3)
  moving_trunk <- cbind(0:4, 0, 0)
  expect_error(
    trunkCompensation(moving_trunk, stationary_hand),
    "zero length"
  )
  result <- trunkCompensation(
    moving_trunk, stationary_hand, reach_axis = c(1, 0, 0)
  )
  expect_true(is.na(result$trunk_contribution))
  expect_error(
    trunkCompensation(
      moving_trunk, stationary_hand, shoulder_r = matrix(0, 5, 3),
      reach_axis = c(1, 0, 0)
    ),
    "supplied together"
  )
  expect_error(
    trunkCompensation(
      moving_trunk, stationary_hand, reach_axis = c(1, 0, 0),
      vertical_axis = 4
    ),
    "vertical_axis"
  )

  hand <- cbind(0:4, 0, 0)
  shoulder_r <- cbind(0.01, 0, 1:5)
  shoulder_l <- matrix(0, 5, 3)
  expect_warning(
    trunkCompensation(
      matrix(0, 5, 3), hand,
      shoulder_r = shoulder_r, shoulder_l = shoulder_l,
      vertical_axis = 3
    ),
    "verify vertical_axis"
  )
})


test_that("reachingKinematics runs end-to-end without mutating its input", {
  set.seed(1)
  pe <- make_mocap_markers(n_time = 200, n_markers = 3, sr = 200)
  speed <- .reach_mj_speed(200)
  position <- cumsum(speed) / 200
  SummarizedExperiment::assay(pe, "position_x")[, 1] <- position
  SummarizedExperiment::assay(pe, "position_y")[, 1] <- 0
  SummarizedExperiment::assay(pe, "position_z")[, 1] <- 0
  original_assays <- SummarizedExperiment::assayNames(pe)

  report <- reachingKinematics(
    pe, marker = "Marker1", target = c(tail(position, 1), 0, 0)
  )

  expect_s3_class(report, "reaching_kinematics")
  expect_equal(report$n_movement_units, 1L)
  expect_lt(report$sparc, 0)
  expect_lt(report$ldlj, 0)
  expect_true(is.finite(report$endpoint_rmse))
  expect_equal(report$marker, "Marker1")
  expect_equal(SummarizedExperiment::assayNames(pe), original_assays)
  expect_output(print(report), "reaching")
})


test_that("reachingKinematics can include trunk transport", {
  pe <- make_mocap_markers(n_time = 201, n_markers = 2, sr = 200)
  speed <- .reach_mj_speed(201)
  hand <- cumsum(speed) / 200
  trunk <- 0.25 * hand
  SummarizedExperiment::assay(pe, "position_x")[, 1] <- hand
  SummarizedExperiment::assay(pe, "position_x")[, 2] <- trunk
  for (axis in c("position_y", "position_z")) {
    SummarizedExperiment::assay(pe, axis)[, 1:2] <- 0
  }

  report <- reachingKinematics(
    pe, marker = "Marker1", trunk_marker = "Marker2"
  )
  expect_s3_class(report$trunk, "trunk_compensation")
  expect_equal(report$trunk$trunk_contribution, 0.25, tolerance = 1e-10)
  expect_equal(
    report$trunk$arm_transport,
    0.75 * report$trunk$hand_transport,
    tolerance = 1e-10
  )
})


test_that("reaching inputs reject malformed values", {
  expect_error(endpointError(c(1, NA), 0), "finite")
  expect_error(endpointError(matrix(1:6, 2, 3), c(0, 0)), "matching")
  expect_error(movementUnits(c(0, -1, 0)), "non-negative")
  expect_error(
    movementUnits(c(0, 1, 0), min_peak_distance = 0.1),
    "sampling frequency"
  )
  expect_error(movementTime(c(0, 1, 0), fs = Inf), "finite")
  expect_error(timeToPeakVelocity(c(0, 1, 0), 100, normalize = NA), "TRUE")

  pe <- make_mocap_markers(n_time = 20, n_markers = 2, sr = 100)
  expect_error(reachingKinematics(pe, marker = "missing"), "identify")
  expect_error(
    reachingKinematics(
      pe, marker = "Marker1", shoulder_markers = c("Marker1", "Marker2")
    ),
    "trunk_marker"
  )
})


test_that("reaching print methods report their classes", {
  endpoint <- endpointError(c(1, 2), 0)
  hand <- cbind(0:3, 0, 0)
  trunk <- cbind(seq(0, 1, length.out = 4), 0, 0)
  compensation <- trunkCompensation(trunk, hand)

  expect_output(print(endpoint), "reaching_endpoint_error")
  expect_output(print(compensation), "trunk_compensation")
})
