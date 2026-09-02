library(testthat)
library(PhysioMoCap)

# --- segmentPhases ---

test_that("segmentPhases segments matrix data with gait schema", {
  set.seed(123)
  data <- matrix(rnorm(200), nrow = 100, ncol = 2)
  events <- data.frame(
    event = c("hs1", "ff", "ms", "ho", "to", "hs2"),
    label = c("Heel Strike", "Foot Flat", "Midstance",
              "Heel Off", "Toe Off", "Heel Strike 2"),
    index = c(1, 13, 31, 41, 61, 100),
    time = c(0, 0.12, 0.30, 0.40, 0.60, 1.0),
    percent = c(0, 12, 30, 40, 60, 100),
    method = rep("manual", 6),
    confidence = rep(1, 6),
    stringsAsFactors = FALSE
  )
  class(events) <- c("detected_events", "data.frame")
  attr(events, "sampling_rate") <- 100

  phases <- segmentPhases(data, events, schema_gait)
  expect_s3_class(phases, "segmented_phases")
  expect_true(hasValidPhases(phases))
  expect_equal(phases$n_samples, 100)
  expect_equal(phases$n_channels, 2)
  expect_true(length(phases$phases) >= 2)
})

test_that("segmentPhases segments numeric vector input", {
  set.seed(42)
  vec <- rnorm(100)
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
  attr(events, "sampling_rate") <- 100

  phases <- segmentPhases(vec, events, schema_gait)
  expect_s3_class(phases, "segmented_phases")
  expect_equal(phases$n_channels, 1)
})

test_that("segmentPhases includes subphases when requested", {
  set.seed(1)
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

  phases <- segmentPhases(data, events, schema_gait, include_subphases = TRUE)
  expect_s3_class(phases, "segmented_phases")

  # Stance phase should have subphases (loading, midstance, propulsion)
  if ("stance" %in% names(phases$phases)) {
    expect_true(length(phases$phases$stance$subphases) > 0)
  }
})

test_that("segmentPhases rejects invalid input types", {
  events <- data.frame(
    event = "hs1", label = "HS", index = 1, time = 0,
    percent = 0, method = "manual", confidence = 1,
    stringsAsFactors = FALSE
  )
  class(events) <- c("detected_events", "data.frame")
  expect_error(segmentPhases("invalid", events, schema_gait),
               "must be a PhysioExperiment or matrix")
})

test_that("segmentPhases validates inputs", {
  data <- matrix(rnorm(100), nrow = 50, ncol = 2)
  expect_error(segmentPhases(data, data.frame(), "not_a_schema"))
})


# --- extractPhase ---

test_that("extractPhase extracts a named phase", {
  set.seed(10)
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
  stance_data <- extractPhase(phases, "stance")
  expect_true(is.matrix(stance_data))
  expect_equal(ncol(stance_data), 2)
  # Stance goes from index 1 to 61 (hs1 to to)
  expect_equal(nrow(stance_data), 61)
})

test_that("extractPhase errors on unknown phase", {
  set.seed(10)
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
  expect_error(extractPhase(phases, "nonexistent"), "not found")
})


# --- phaseTiming ---

test_that("phaseTiming returns data.frame with timing info", {
  set.seed(10)
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
  timing <- phaseTiming(phases, as_percent = TRUE)
  expect_true(is.data.frame(timing))
  expect_true("phase" %in% names(timing))
  expect_true("start" %in% names(timing))
  expect_true("end" %in% names(timing))
  expect_true("duration" %in% names(timing))
  expect_true(all(timing$start >= 0))
  expect_true(all(timing$end <= 100))
})

test_that("phaseTiming returns seconds when requested", {
  set.seed(10)
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
  timing <- phaseTiming(phases, as_percent = FALSE)
  expect_true(is.data.frame(timing))
  # Seconds should be small values for 100 samples at 1000 Hz
  expect_true(all(timing$duration >= 0))
})


# --- phaseDurations ---

test_that("phaseDurations returns named numeric vector", {
  set.seed(10)
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

  dur_pct <- phaseDurations(phases, unit = "percent")
  expect_true(is.numeric(dur_pct))
  expect_true(length(dur_pct) > 0)
  expect_true(!is.null(names(dur_pct)))

  dur_sec <- phaseDurations(phases, unit = "seconds")
  expect_true(is.numeric(dur_sec))
  expect_true(all(dur_sec > 0))

  dur_samp <- phaseDurations(phases, unit = "samples")
  expect_true(is.numeric(dur_samp))
  expect_true(all(dur_samp > 0))
})


# --- phaseRatios ---

test_that("phaseRatios computes ratios relative to total", {
  set.seed(10)
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
  ratios <- phaseRatios(phases, reference = "total")
  expect_true(is.numeric(ratios))
  expect_true(abs(sum(ratios) - 1.0) < 0.01)
})

test_that("phaseRatios errors on unknown reference", {
  set.seed(10)
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
  expect_error(phaseRatios(phases, reference = "nonexistent"),
               "Unknown reference")
})


# --- getPhaseData ---

test_that("getPhaseData returns named list of matrices", {
  set.seed(10)
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
  phase_data <- getPhaseData(phases, include_subphases = FALSE)
  expect_true(is.list(phase_data))
  expect_true(length(phase_data) > 0)
  expect_true(all(vapply(phase_data, is.matrix, logical(1))))
})


# --- hasValidPhases ---

test_that("hasValidPhases returns TRUE for valid phases", {
  set.seed(10)
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
  expect_true(hasValidPhases(phases))
})


# --- combineTrials ---

test_that("combineTrials combines multiple segmented_phases", {
  set.seed(10)
  make_trial <- function() {
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
    segmentPhases(data, events, schema_gait)
  }

  trial1 <- make_trial()
  trial2 <- make_trial()
  combined <- combineTrials(trial1, trial2, labels = c("T1", "T2"))
  expect_s3_class(combined, "multi_trial_phases")
  expect_equal(combined$n_trials, 2)
  expect_equal(names(combined$trials), c("T1", "T2"))
})

test_that("combineTrials errors on non-segmented_phases input", {
  expect_error(combineTrials(list(a = 1), labels = c("bad")),
               "not a segmented_phases object")
})


# --- print methods ---

test_that("print.segmented_phases works", {
  set.seed(10)
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
  expect_output(print(phases), "Segmented Phases")
  expect_output(print(phases), "Gait Cycle")
})

test_that("print.multi_trial_phases works", {
  set.seed(10)
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
  combined <- combineTrials(phases, phases)
  expect_output(print(combined), "Multi-Trial Segmented Phases")
})
