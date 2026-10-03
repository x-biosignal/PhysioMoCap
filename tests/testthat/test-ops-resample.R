library(testthat)
library(PhysioMoCap)

# --- resampleVector ---

test_that("resampleVector standalone works", {
  x <- sin(seq(0, 2 * pi, length.out = 100))
  y <- resampleVector(x, from_rate = 100, to_rate = 200)
  expect_true(is.numeric(y))
  expect_equal(length(y), 199)
})

test_that("resampleVector errors on invalid target_rate", {
  x <- rnorm(50)
  expect_error(resampleVector(x, from_rate = 100, to_rate = 0))
  expect_error(resampleVector(x, from_rate = 100, to_rate = -10))
  expect_error(resampleVector(x, from_rate = 0, to_rate = 100))
})

test_that("linear interpolation preserves endpoints", {
  x <- seq(0, 10, length.out = 100)
  y <- resampleVector(x, from_rate = 100, to_rate = 200)
  expect_equal(y[1], x[1], tolerance = 1e-10)
  expect_equal(y[length(y)], x[length(x)], tolerance = 1e-10)
})

test_that("spline method produces smooth output", {
  x <- sin(seq(0, 2 * pi, length.out = 50))
  y_linear <- resampleVector(x, from_rate = 50, to_rate = 200, method = "linear")
  y_spline <- resampleVector(x, from_rate = 50, to_rate = 200, method = "spline")

  # Both should have same length
  expect_equal(length(y_linear), length(y_spline))

  # Spline should differ from linear (different interpolation)
  expect_false(identical(y_linear, y_spline))
})

test_that("NA handling: NAs preserved approximately", {
  x <- c(1, 2, NA, 4, 5, NA, 7, 8, 9, 10)
  y <- resampleVector(x, from_rate = 10, to_rate = 20)
  # NAs in input propagate through interpolation; there should be some NAs
  expect_true(any(is.na(y)))
})


# --- resampleSignal ---

test_that("upsample 100Hz to 200Hz doubles frame count", {
  pe <- make_mocap_markers(n_time = 100, n_markers = 3, sr = 100)
  pe2 <- resampleSignal(pe, target_rate = 200)
  n_out <- nrow(SummarizedExperiment::assay(pe2, "position_x"))
  # (100-1)/100 * 200 + 1 = 199
  expect_equal(n_out, 199)
})

test_that("downsample 200Hz to 100Hz halves frame count", {
  pe <- make_mocap_markers(n_time = 201, n_markers = 3, sr = 200)
  pe2 <- resampleSignal(pe, target_rate = 100)
  n_out <- nrow(SummarizedExperiment::assay(pe2, "position_x"))
  # (201-1)/200 * 100 + 1 = 101
  expect_equal(n_out, 101)
})

test_that("samplingRate updated correctly after resample", {
  pe <- make_mocap_markers(n_time = 100, n_markers = 2, sr = 120)
  pe2 <- resampleSignal(pe, target_rate = 60)
  expect_equal(PhysioCore::samplingRate(pe2), 60)
})

test_that("all assays resampled together", {
  pe <- make_mocap_markers(n_time = 100, n_markers = 3, sr = 100)
  pe2 <- resampleSignal(pe, target_rate = 50)

  anames <- SummarizedExperiment::assayNames(pe2)
  expect_true("position_x" %in% anames)
  expect_true("position_y" %in% anames)
  expect_true("position_z" %in% anames)

  # All assays should have the same number of rows
  dims <- vapply(anames, function(nm) {
    nrow(SummarizedExperiment::assay(pe2, nm))
  }, integer(1))
  expect_equal(length(unique(dims)), 1)
})

test_that("metadata$time vector updated after resample", {
  pe <- make_mocap_markers(n_time = 100, n_markers = 2, sr = 100)
  pe2 <- resampleSignal(pe, target_rate = 200)
  time_vec <- S4Vectors::metadata(pe2)[["time"]]
  expect_true(!is.null(time_vec))
  n_out <- nrow(SummarizedExperiment::assay(pe2, "position_x"))
  expect_equal(length(time_vec), n_out)
  expect_equal(time_vec[1], 0)
  # Duration should be (n_out - 1) / target_rate
  expect_equal(time_vec[length(time_vec)], (n_out - 1) / 200, tolerance = 1e-10)
})

test_that("sine wave resampled preserves frequency content", {
  # Create a 5Hz sine wave sampled at 100Hz for 1 second
  sr <- 100
  n <- 101
  t <- seq(0, 1, length.out = n)
  freq <- 5
  sine_data <- matrix(sin(2 * pi * freq * t), ncol = 1)
  colnames(sine_data) <- "signal"

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = sine_data),
    colData = S4Vectors::DataFrame(label = "signal", type = "test"),
    samplingRate = sr
  )

  # Resample to 200Hz
  pe2 <- resampleSignal(pe, target_rate = 200)
  resampled <- SummarizedExperiment::assay(pe2, "raw")[, 1]

  # Check that the resampled signal matches the expected sine wave
  n_out <- length(resampled)
  t_out <- seq(0, 1, length.out = n_out)
  expected <- sin(2 * pi * freq * t_out)
  # Allow some tolerance for interpolation error
  expect_equal(resampled, expected, tolerance = 0.05)
})


# --- synchronizeSignals ---

test_that("synchronizeSignals aligns two PEs", {
  pe1 <- make_mocap_markers(n_time = 100, n_markers = 2, sr = 100)
  pe2 <- make_mocap_markers(n_time = 60, n_markers = 2, sr = 60)

  synced <- synchronizeSignals(list(pe1, pe2))

  # Both should now have the same sampling rate (max = 100)
  expect_equal(PhysioCore::samplingRate(synced[[1]]), 100)
  expect_equal(PhysioCore::samplingRate(synced[[2]]), 100)

  # Both should have the same number of rows
  n1 <- nrow(SummarizedExperiment::assay(synced[[1]], "position_x"))
  n2 <- nrow(SummarizedExperiment::assay(synced[[2]], "position_x"))
  expect_equal(n1, n2)
})
