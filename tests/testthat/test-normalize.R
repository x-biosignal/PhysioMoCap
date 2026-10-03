library(testthat)
library(PhysioMoCap)

# --- normalizeMovement: cycle method ---

test_that("normalizeMovement cycle method normalizes matrix to target length", {
  data <- matrix(rnorm(500), nrow = 500, ncol = 3)
  normalized <- normalizeMovement(data, method = "cycle", norm_length = 101)
  expect_true(is.matrix(normalized))
  expect_equal(nrow(normalized), 101)
  expect_equal(ncol(normalized), 3)
  expect_equal(attr(normalized, "normalization"), "cycle")
  expect_equal(attr(normalized, "norm_length"), 101L)
})

test_that("normalizeMovement cycle method works on numeric vector", {
  vec <- rnorm(200)
  normalized <- normalizeMovement(vec, method = "cycle", norm_length = 101)
  expect_true(is.numeric(normalized))
  expect_equal(length(normalized), 101)
})

test_that("normalizeMovement cycle method works on list of matrices", {
  trials <- list(
    matrix(rnorm(300), nrow = 100, ncol = 3),
    matrix(rnorm(450), nrow = 150, ncol = 3),
    matrix(rnorm(240), nrow = 80, ncol = 3)
  )
  normalized <- normalizeMovement(trials, method = "cycle", norm_length = 101)
  expect_true(is.list(normalized))
  expect_equal(length(normalized), 3)
  for (m in normalized) {
    expect_equal(nrow(m), 101)
    expect_equal(ncol(m), 3)
  }
})

test_that("normalizeMovement returns same data when already correct length", {
  data <- matrix(rnorm(303), nrow = 101, ncol = 3)
  normalized <- normalizeMovement(data, method = "cycle", norm_length = 101)
  expect_equal(nrow(normalized), 101)
  expect_equal(ncol(normalized), 3)
})


# --- normalizeMovement: phase method ---

test_that("normalizeMovement phase method normalizes segmented_phases", {
  set.seed(42)
  data <- matrix(rnorm(200), nrow = 100, ncol = 2)
  events <- data.frame(
    event = c("hs1", "ff", "ms", "ho", "to", "hs2"),
    label = c("HS1", "FF", "MS", "HO", "TO", "HS2"),
    index = c(1, 13, 31, 41, 61, 100),
    time = c(0, 0.12, 0.30, 0.40, 0.60, 1.0),
    percent = c(0, 12, 30, 40, 60, 100),
    method = rep("manual", 6),
    confidence = rep(1, 6),
    stringsAsFactors = FALSE
  )
  class(events) <- c("detected_events", "data.frame")

  phases <- segmentPhases(data, events, schema_gait)
  normalized <- normalizeMovement(phases, method = "phase", norm_length = 50)
  # Phase normalization on segmented_phases returns a combined matrix
  expect_true(is.matrix(normalized))
  expect_true(!is.null(attr(normalized, "phase_names")))
})


# --- normalizeMovement: landmark method ---

test_that("normalizeMovement landmark method works with events", {
  set.seed(42)
  data <- matrix(rnorm(200), nrow = 100, ncol = 2)
  events <- data.frame(
    event = c("hs1", "ff", "ms", "ho", "to", "hs2"),
    label = c("HS1", "FF", "MS", "HO", "TO", "HS2"),
    index = c(1, 13, 31, 41, 61, 100),
    time = c(0, 0.12, 0.30, 0.40, 0.60, 1.0),
    percent = c(0, 12, 30, 40, 60, 100),
    method = rep("manual", 6),
    confidence = rep(1, 6),
    stringsAsFactors = FALSE
  )
  class(events) <- c("detected_events", "data.frame")

  normalized <- normalizeMovement(data, method = "landmark",
                                   norm_length = 101,
                                   events = events,
                                   landmark_event = "to")
  expect_true(is.matrix(normalized))
  expect_equal(nrow(normalized), 101)
  expect_true(!is.null(attr(normalized, "landmark_position")))
})


# --- normalizeMovement: absolute method ---

test_that("normalizeMovement absolute method returns data unchanged", {
  data <- matrix(rnorm(300), nrow = 100, ncol = 3)
  normalized <- normalizeMovement(data, method = "absolute")
  expect_equal(nrow(normalized), 100)
  expect_equal(ncol(normalized), 3)
})


# --- normalizeMovement: dtw method ---

test_that("normalizeMovement dtw method aligns list of trials", {
  set.seed(123)
  trials <- list(
    matrix(sin(seq(0, 2*pi, length.out = 50)), ncol = 1),
    matrix(sin(seq(0.3, 2.3*pi, length.out = 60)), ncol = 1),
    matrix(sin(seq(0.1, 2.1*pi, length.out = 55)), ncol = 1)
  )
  normalized <- normalizeMovement(trials, method = "dtw", norm_length = 50)
  expect_true(is.list(normalized))
  expect_equal(length(normalized), 3)
})


# --- normalizedTimeAxis ---

test_that("normalizedTimeAxis returns correct percent axis", {
  t_pct <- normalizedTimeAxis(101, method = "cycle", unit = "percent")
  expect_equal(length(t_pct), 101)
  expect_equal(t_pct[1], 0)
  expect_equal(t_pct[101], 100)
})

test_that("normalizedTimeAxis returns correct normalized axis", {
  t_norm <- normalizedTimeAxis(101, method = "cycle", unit = "normalized")
  expect_equal(length(t_norm), 101)
  expect_equal(t_norm[1], 0)
  expect_equal(t_norm[101], 1)
})

test_that("normalizedTimeAxis returns correct degrees axis", {
  t_deg <- normalizedTimeAxis(361, method = "cycle", unit = "degrees")
  expect_equal(length(t_deg), 361)
  expect_equal(t_deg[1], 0)
  expect_equal(t_deg[361], 360)
})


# --- batchNormalize ---

test_that("batchNormalize normalizes multiple trials to 3D array", {
  set.seed(99)
  trials <- list(
    matrix(rnorm(300), nrow = 100, ncol = 3),
    matrix(rnorm(450), nrow = 150, ncol = 3),
    matrix(rnorm(360), nrow = 120, ncol = 3)
  )
  result <- batchNormalize(trials, method = "cycle", norm_length = 101)
  expect_true(is.array(result))
  expect_equal(dim(result), c(101, 3, 3))
})

test_that("batchNormalize handles single trial", {
  set.seed(99)
  trials <- list(matrix(rnorm(300), nrow = 100, ncol = 3))
  result <- batchNormalize(trials, method = "cycle", norm_length = 101)
  expect_true(is.array(result))
  expect_equal(dim(result), c(101, 3, 1))
})

test_that("batchNormalize preserves column names", {
  mat <- matrix(rnorm(300), nrow = 100, ncol = 3)
  colnames(mat) <- c("hip", "knee", "ankle")
  trials <- list(mat, mat)
  result <- batchNormalize(trials, method = "cycle", norm_length = 101)
  expect_equal(dimnames(result)[[2]], c("hip", "knee", "ankle"))
})


# --- Internal functions ---

test_that(".normalizeMatrix interpolates correctly", {
  mat <- matrix(1:20, nrow = 10, ncol = 2)
  result <- PhysioMoCap:::.normalizeMatrix(mat, 5)
  expect_equal(nrow(result), 5)
  expect_equal(ncol(result), 2)
  # First and last values should be preserved by linear interpolation
  expect_equal(result[1, 1], 1)
  expect_equal(result[5, 1], 10)
})

test_that(".normalizeVector interpolates correctly", {
  vec <- seq(0, 10, length.out = 100)
  result <- PhysioMoCap:::.normalizeVector(vec, 11)
  expect_equal(length(result), 11)
  expect_equal(result[1], 0)
  expect_equal(result[11], 10)
})
