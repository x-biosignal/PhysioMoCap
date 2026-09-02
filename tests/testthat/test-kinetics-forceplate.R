library(testthat)
library(PhysioMoCap)


test_that("filterGRF returns same shape for vector and matrix", {
  sr <- 1000
  t <- seq(0, 1, length.out = sr)
  x <- sin(2 * pi * 8 * t) + 0.2 * sin(2 * pi * 120 * t)
  y <- filterGRF(x, sampling_rate = sr, cutoff = 20, method = "moving_average")

  expect_equal(length(y), length(x))

  xmat <- cbind(a = x, b = x * 0.5)
  ymat <- filterGRF(xmat, sampling_rate = sr, cutoff = 20,
                    method = "moving_average")
  expect_true(is.matrix(ymat))
  expect_equal(dim(ymat), dim(xmat))
})


test_that("calculateCOP returns expected values for simple static case", {
  n <- 50
  f <- cbind(Fx = rep(0, n), Fy = rep(0, n), Fz = rep(1000, n))
  m <- cbind(Mx = rep(100, n), My = rep(-200, n), Mz = rep(0, n))

  cop <- calculateCOP(f, m, origin = c(0, 0, 0), min_vertical_force = 20)

  expect_equal(cop$cop_x, rep(0.2, n), tolerance = 1e-8)
  expect_equal(cop$cop_y, rep(0.1, n), tolerance = 1e-8)
  expect_equal(cop$cop_z, rep(0, n), tolerance = 1e-8)
})


test_that("computeLoadingRate detects stance loading", {
  sr <- 1000
  grf <- c(rep(0, 100),
           seq(0, 900, length.out = 120),
           seq(900, 0, length.out = 180),
           rep(0, 100))

  lr <- computeLoadingRate(grf, sampling_rate = sr, threshold = 20,
                           method = "instantaneous")

  expect_s3_class(lr, "data.frame")
  expect_true(nrow(lr) >= 1)
  expect_true(all(lr$loading_rate > 0, na.rm = TRUE))
})


test_that("computeImpulse returns positive impulse during contact", {
  sr <- 1000
  grf <- c(rep(0, 100), rep(600, 300), rep(0, 100))

  imp <- computeImpulse(grf, sampling_rate = sr, threshold = 20)

  expect_s3_class(imp, "data.frame")
  expect_true(nrow(imp) >= 1)
  expect_true(all(imp$impulse > 0, na.rm = TRUE))

  # Rough expected impulse: 600 N * 0.299 s ~= 179.4 N*s
  expect_equal(imp$impulse[1], 179.4, tolerance = 2)
})


test_that("analyzeForcePlate returns complete analysis object", {
  set.seed(1)
  n <- 1000
  f <- cbind(
    Fx = rnorm(n, 0, 5),
    Fy = rnorm(n, 0, 5),
    Fz = c(rep(0, 200), abs(sin(seq(0, pi, length.out = 600))) * 800, rep(0, 200))
  )
  m <- cbind(Mx = rnorm(n, 0, 20), My = rnorm(n, 0, 20), Mz = rnorm(n, 0, 10))

  out <- analyzeForcePlate(
    forces = f,
    moments = m,
    sampling_rate = 1000,
    cutoff = 20,
    threshold = 20,
    filter_method = "moving_average"
  )

  expect_s3_class(out, "forceplate_analysis")
  expect_true(is.data.frame(out$filtered_forces))
  expect_true(is.data.frame(out$loading_rate))
  expect_true(is.data.frame(out$impulse))
  expect_true(is.data.frame(out$summary))
  expect_true("peak_vertical_force" %in% names(out$summary))
})


test_that("analyzeForcePlatePE works with force_x/y/z and moment_x/y/z assays", {
  n <- 500
  sr <- 1000

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      force_x = matrix(0, nrow = n, ncol = 1, dimnames = list(NULL, "fp1")),
      force_y = matrix(0, nrow = n, ncol = 1, dimnames = list(NULL, "fp1")),
      force_z = matrix(c(rep(0, 100), rep(700, 300), rep(0, 100)), nrow = n,
                       ncol = 1, dimnames = list(NULL, "fp1")),
      moment_x = matrix(50, nrow = n, ncol = 1, dimnames = list(NULL, "fp1")),
      moment_y = matrix(-100, nrow = n, ncol = 1, dimnames = list(NULL, "fp1")),
      moment_z = matrix(0, nrow = n, ncol = 1, dimnames = list(NULL, "fp1"))
    ),
    colData = S4Vectors::DataFrame(label = "fp1", type = "forceplate"),
    samplingRate = sr
  )

  out <- analyzeForcePlatePE(pe, threshold = 20, cutoff = 20,
                             filter_method = "moving_average")

  expect_s3_class(out, "forceplate_analysis")
  expect_true(is.data.frame(out$cop))
  expect_true(nrow(out$cop) == n)
})


test_that("detectForcePlateContacts returns per-plate contact table", {
  v <- cbind(
    fp1 = c(rep(0, 100), rep(600, 150), rep(0, 100)),
    fp2 = c(rep(0, 200), rep(800, 80), rep(0, 70))
  )

  contacts <- detectForcePlateContacts(v, threshold = 20, sampling_rate = 1000)
  expect_s3_class(contacts, "data.frame")
  expect_true(all(c("plate", "onset", "offset", "duration_samples", "peak_force") %in%
                    names(contacts)))
  expect_true(any(contacts$plate == "fp1"))
  expect_true(any(contacts$plate == "fp2"))
})


test_that("analyzeForcePlatePE supports plate_index = 'auto'", {
  n <- 500
  sr <- 1000

  fz <- cbind(
    fp1 = c(rep(0, 150), rep(200, 200), rep(0, 150)),
    fp2 = c(rep(0, 100), rep(900, 300), rep(0, 100))
  )

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      force_x = matrix(0, nrow = n, ncol = 2),
      force_y = matrix(0, nrow = n, ncol = 2),
      force_z = fz,
      moment_x = matrix(0, nrow = n, ncol = 2),
      moment_y = matrix(0, nrow = n, ncol = 2),
      moment_z = matrix(0, nrow = n, ncol = 2)
    ),
    colData = S4Vectors::DataFrame(
      label = c("fp1", "fp2"),
      type = rep("forceplate", 2)
    ),
    samplingRate = sr
  )

  out <- analyzeForcePlatePE(pe, plate_index = "auto", threshold = 20,
                             cutoff = 20, filter_method = "moving_average")

  expect_s3_class(out, "forceplate_analysis")
  expect_equal(out$selected_plate, 2L)
  expect_true(out$summary$peak_vertical_force > 500)
})


test_that("analyzeForcePlatePE supports plate_index = 'all'", {
  n <- 400
  sr <- 1000

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      force_x = matrix(0, nrow = n, ncol = 2),
      force_y = matrix(0, nrow = n, ncol = 2),
      force_z = cbind(
        fp1 = c(rep(0, 100), rep(500, 200), rep(0, 100)),
        fp2 = c(rep(0, 150), rep(700, 100), rep(0, 150))
      )
    ),
    colData = S4Vectors::DataFrame(
      label = c("fp1", "fp2"),
      type = rep("forceplate", 2)
    ),
    samplingRate = sr
  )

  out <- analyzeForcePlatePE(pe, plate_index = "all", threshold = 20,
                             cutoff = 20, filter_method = "moving_average")

  expect_s3_class(out, "forceplate_analysis_multi")
  expect_true(is.list(out$analyses))
  expect_equal(length(out$analyses), 2)
  expect_s3_class(out$summary, "data.frame")
  expect_true(all(c("plate", "peak_vertical_force") %in% names(out$summary)))
  expect_invisible(print(out))
})


test_that("grfLandmarks extracts loading peak, mid-stance trough, and push-off peak", {
  # a synthetic double-humped stance curve (101 pts, body-weight units)
  g <- 1.1 * sin(seq(0, pi, length.out = 101))^0.5
  g[46:56] <- g[46:56] * 0.68        # carve a mid-stance trough

  lm <- grfLandmarks(g)

  expect_named(lm, c("peak1", "trough", "peak2"))
  expect_true(is.numeric(lm) && length(lm) == 3)
  expect_true(lm["peak1"] > lm["trough"])   # loading peak above the trough
  expect_true(lm["peak2"] > lm["trough"])   # push-off peak above the trough
  # landmarks are the extrema within their windows
  expect_equal(unname(lm["peak1"]), max(g[5:40]))
  expect_equal(unname(lm["trough"]), min(g[30:60]))
  expect_equal(unname(lm["peak2"]), max(g[45:80]))
})

test_that("grfLandmarks honours custom windows and validates input", {
  g <- 1.1 * sin(seq(0, pi, length.out = 101))^0.5

  lm <- grfLandmarks(g, loading_window = 10:30, midstance_window = 40:60,
                     pushoff_window = 70:90)
  expect_equal(unname(lm["peak1"]), max(g[10:30]))
  expect_equal(unname(lm["peak2"]), max(g[70:90]))

  expect_error(grfLandmarks("not numeric"), "numeric vector")
  expect_error(grfLandmarks(g, loading_window = 0:5), "loading_window")
  expect_error(grfLandmarks(g, pushoff_window = 95:110), "pushoff_window")
})

test_that("grfLandmarks accepts a curves-x-time matrix (ensemble-mean landmarks)", {
  g <- 1.1 * sin(seq(0, pi, length.out = 101))^0.5
  g[46:56] <- g[46:56] * 0.68
  M <- rbind(g, g * 1.02, g * 0.98)      # 3 curves; mean == g

  lm_mat <- grfLandmarks(M)
  lm_vec <- grfLandmarks(colMeans(M))
  expect_equal(lm_mat, lm_vec)           # matrix path == landmarks of the mean curve
  expect_named(lm_mat, c("peak1", "trough", "peak2"))
})
