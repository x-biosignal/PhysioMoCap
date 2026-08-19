library(testthat)
library(PhysioMoCap)


test_that("rectifyEMG supports fullwave and halfwave", {
  x <- c(-2, -1, 0, 1, 2)

  full <- rectifyEMG(x, method = "fullwave")
  half <- rectifyEMG(x, method = "halfwave")

  expect_equal(full, c(2, 1, 0, 1, 2))
  expect_equal(half, c(0, 0, 0, 1, 2))
})


test_that("computeRMSEnvelope returns non-negative output", {
  set.seed(1)
  x <- rnorm(500)
  env <- computeRMSEnvelope(x, window_samples = 25)

  expect_equal(length(env), length(x))
  expect_true(all(env[is.finite(env)] >= 0))
})


test_that("normalizeEMG peak and mvc normalization work", {
  x <- matrix(c(1, 2, 3, 4, 2, 4, 6, 8), ncol = 2)

  n_peak <- normalizeEMG(x, method = "peak", scale_percent = FALSE)
  expect_equal(apply(n_peak, 2, max, na.rm = TRUE), c(1, 1), tolerance = 1e-12)

  n_mvc <- normalizeEMG(x, method = "mvc", mvc = c(4, 8), scale_percent = TRUE)
  expect_equal(max(n_mvc[, 1], na.rm = TRUE), 100)
  expect_equal(max(n_mvc[, 2], na.rm = TRUE), 100)
})


test_that("alignEMGtoMoCap produces target length", {
  set.seed(2)
  emg <- matrix(rnorm(4000), ncol = 4)

  aligned <- alignEMGtoMoCap(
    emg = emg,
    emg_sampling_rate = 1000,
    mocap_length = 400,
    mocap_sampling_rate = 100
  )

  expect_true(is.matrix(aligned))
  expect_equal(dim(aligned), c(400, 4))
})


test_that("processEMG returns expected components", {
  set.seed(3)
  emg <- matrix(rnorm(3000), ncol = 3)

  out <- processEMG(
    x = emg,
    sampling_rate = 1000,
    bandpass = c(20, 450),
    envelope_cutoff = 8,
    rms_window_ms = 40,
    mvc = c(1.2, 1.5, 2.0),
    filter_method = "moving_average"
  )

  expect_true(is.list(out))
  expect_true(all(c("filtered", "rectified", "envelope", "normalized") %in% names(out)))
  expect_equal(dim(out$filtered), dim(emg))
  expect_equal(dim(out$rectified), dim(emg))
  expect_equal(dim(out$envelope), dim(emg))
  expect_equal(dim(out$normalized), dim(emg))
})


test_that("integrateEMGMoCap combines motion and EMG features", {
  set.seed(4)
  mocap <- matrix(rnorm(1000), nrow = 200, ncol = 5)
  colnames(mocap) <- paste0("marker", 1:5)

  emg <- matrix(rnorm(6000), nrow = 2000, ncol = 3)
  colnames(emg) <- c("ta", "gm", "rf")

  out <- integrateEMGMoCap(
    mocap = mocap,
    emg = emg,
    mocap_sampling_rate = 100,
    emg_sampling_rate = 1000,
    process = TRUE,
    rms_window_ms = 50,
    envelope_cutoff = 6,
    filter_method = "moving_average"
  )

  expect_true(is.list(out))
  expect_true(all(c("mocap", "emg_aligned", "combined") %in% names(out)))
  expect_equal(nrow(out$emg_aligned), nrow(mocap))
  expect_equal(nrow(out$combined), nrow(mocap))
  expect_true("time" %in% names(out$combined))
  expect_true(any(grepl("^mocap_", names(out$combined))))
  expect_true(any(grepl("^emg_", names(out$combined))))
})
