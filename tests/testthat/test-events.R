library(testthat)
library(PhysioMoCap)

# --- detectEvents ---

test_that("detectEvents works with manual method", {
  set.seed(123)
  grf <- make_gait_grf(n_time = 1000, sr = 1000)
  events <- detectEvents(as.matrix(grf), schema_gait,
                         signals = list(vGRF = grf),
                         method = "manual",
                         sampling_rate = 1000)
  expect_s3_class(events, "detected_events")
  expect_true(nrow(events) > 0)
  expect_true("event" %in% names(events))
  expect_true("index" %in% names(events))
  expect_true("time" %in% names(events))
  expect_true("method" %in% names(events))
  # All should use manual method

  expect_true(all(events$method == "manual"))
})

test_that("detectEvents works with auto method on GRF data", {
  set.seed(42)
  grf <- make_gait_grf(n_time = 1000, sr = 1000)
  events <- detectEvents(as.matrix(grf), schema_gait,
                         signals = list(vGRF = grf),
                         method = "auto",
                         sampling_rate = 1000)
  expect_s3_class(events, "detected_events")
  expect_true(nrow(events) > 0)
  expect_true(all(c("event", "label", "index", "time", "percent",
                     "method", "confidence") %in% names(events)))
})

test_that("detectEvents works with hybrid method", {
  set.seed(99)
  grf <- make_gait_grf(n_time = 500, sr = 500)
  events <- detectEvents(as.matrix(grf), schema_gait,
                         signals = list(vGRF = grf),
                         method = "hybrid",
                         sampling_rate = 500)
  expect_s3_class(events, "detected_events")
  expect_true(nrow(events) > 0)
})

test_that("detectEvents requires sampling_rate for matrix input", {
  grf <- rnorm(100)
  expect_error(
    detectEvents(as.matrix(grf), schema_gait, sampling_rate = NULL),
    "sampling_rate.*required"
  )
})

test_that("detectEvents returns empty data.frame for schema with no events", {
  events <- detectEvents(
    as.matrix(rnorm(100)), schema_balance,
    sampling_rate = 100
  )
  expect_s3_class(events, "detected_events")
  expect_equal(nrow(events), 0)
})

test_that("detectEvents accepts numeric vector input", {
  set.seed(123)
  grf <- make_gait_grf(n_time = 200, sr = 200)
  events <- detectEvents(grf, schema_gait,
                         signals = list(vGRF = grf),
                         method = "manual",
                         sampling_rate = 200)
  expect_s3_class(events, "detected_events")
  expect_true(nrow(events) > 0)
})

test_that("detectEvents rejects invalid input type", {
  expect_error(
    detectEvents("not_valid", schema_gait, sampling_rate = 100),
    "PhysioExperiment.*vector.*matrix"
  )
})

test_that("detectEvents stores attributes", {
  set.seed(1)
  grf <- make_gait_grf(n_time = 500, sr = 500)
  events <- detectEvents(as.matrix(grf), schema_gait,
                         signals = list(vGRF = grf),
                         method = "manual",
                         sampling_rate = 500)
  expect_equal(attr(events, "schema"), "gait")
  expect_equal(attr(events, "sampling_rate"), 500)
  expect_equal(attr(events, "n_samples"), 500)
})


# --- manualEvents ---

test_that("manualEvents creates events from schema with times", {
  events <- manualEvents(schema_gait,
                         times = c(hs1 = 0, ff = 0.12, ms = 0.30,
                                   ho = 0.40, to = 0.60, hs2 = 1.0),
                         sampling_rate = 100, n_samples = 101)
  expect_s3_class(events, "detected_events")
  expect_equal(nrow(events), 6)
  expect_true(all(events$method == "manual"))
  expect_true(all(events$confidence == 1.0))
})

test_that("manualEvents creates events from indices", {
  events <- manualEvents(schema_gait,
                         indices = c(hs1 = 1L, ff = 13L, ms = 31L,
                                     ho = 41L, to = 61L, hs2 = 101L),
                         sampling_rate = 100, n_samples = 101)
  expect_s3_class(events, "detected_events")
  expect_equal(nrow(events), 6)
  expect_equal(events$index[events$event == "hs1"], 1L)
  expect_equal(events$index[events$event == "hs2"], 101L)
})

test_that("manualEvents falls back to typical_timing for missing events", {
  # Only specify some events, others should get typical timing
  events <- manualEvents(schema_gait,
                         times = c(hs1 = 0, to = 0.60),
                         sampling_rate = 1000, n_samples = 1001)
  expect_s3_class(events, "detected_events")
  expect_equal(nrow(events), 6)  # All 6 gait events
  # Specified events have confidence 1.0, typical timing events also get 1.0
  # (because they are resolved from typical_timing as fallback in manualEvents)
})

test_that("manualEvents requires sampling_rate when using times", {
  expect_error(
    manualEvents(schema_gait,
                 times = c(hs1 = 0, to = 0.6),
                 n_samples = 100),
    "sampling_rate required"
  )
})

test_that("manualEvents requires times or indices", {
  expect_error(
    manualEvents(schema_gait, n_samples = 100, sampling_rate = 100)
  )
})


# --- print.detected_events ---

test_that("print.detected_events works", {
  events <- manualEvents(schema_gait,
                         times = c(hs1 = 0, to = 0.6, hs2 = 1.0),
                         sampling_rate = 100, n_samples = 101)
  expect_output(print(events), "Detected Events")
  expect_output(print(events), "Schema: gait")
})

test_that("print.detected_events handles empty events", {
  events <- detectEvents(as.matrix(rnorm(100)), schema_balance,
                         sampling_rate = 100)
  expect_output(print(events), "No events detected")
})


# --- Internal detection methods ---

test_that("threshold detection finds rising crossings", {
  signal <- c(rep(0, 50), seq(0, 100, length.out = 50))
  result <- PhysioMoCap:::.detectThreshold(signal, threshold = 50,
                                            direction = "rising", sr = 100)
  expect_true(!is.na(result$index))
  expect_true(result$index > 50)
  expect_true(result$confidence > 0)
})

test_that("threshold detection finds falling crossings", {
  signal <- c(rep(100, 50), seq(100, 0, length.out = 50))
  result <- PhysioMoCap:::.detectThreshold(signal, threshold = 50,
                                            direction = "falling", sr = 100)
  expect_true(!is.na(result$index))
  expect_true(result$confidence > 0)
})

test_that("peak detection finds global max", {
  signal <- c(seq(0, 100, length.out = 50), seq(100, 0, length.out = 50))
  result <- PhysioMoCap:::.detectPeak(signal, type = "max", sr = 100)
  expect_equal(result$index, 50L)
  expect_true(result$confidence > 0)
})

test_that("peak detection finds global min", {
  signal <- c(seq(100, 0, length.out = 50), seq(0, 100, length.out = 50))
  result <- PhysioMoCap:::.detectPeak(signal, type = "min", sr = 100)
  expect_equal(result$index, 50L)
})

test_that("zero crossing detection works", {
  signal <- seq(-1, 1, length.out = 100)
  result <- PhysioMoCap:::.detectZeroCrossing(signal, direction = "rising",
                                               sr = 100)
  expect_true(!is.na(result$index))
  expect_true(result$index >= 49 && result$index <= 51)
})

test_that("angle detection works", {
  signal <- seq(0, 360, length.out = 361)
  result <- PhysioMoCap:::.detectAngle(signal, value = 180, sr = 100)
  expect_equal(result$index, 181L)
  expect_true(result$confidence > 0.5)
})

test_that("velocity threshold detection works", {
  # Signal with increasing velocity
  signal <- cumsum(c(rep(0, 50), rep(1, 50)))
  result <- PhysioMoCap:::.detectVelocityThreshold(signal, threshold = 50,
                                                     direction = "rising",
                                                     sr = 100)
  # The velocity jumps at index 51, so detection should find it
  expect_true(!is.na(result$index))
})
