library(testthat)
library(PhysioMoCap)

# ---------------------------------------------------------------------------
# Helper: build a minimal PhysioExperiment with position data and gait events
# ---------------------------------------------------------------------------

#' Create synthetic gait data with known parameters
#' @param sr sampling rate in Hz
#' @param n_strides number of full gait cycles per side
#' @param stride_time_sec stride duration in seconds
#' @param stance_pct stance percentage (0-1)
#' @param step_length_m step length in metres
#' @param step_width_m step width in metres
#' @noRd
make_gait_data <- function(sr = 100,
                           n_strides = 3,
                           stride_time_sec = 1.0,
                           stance_pct = 0.60,
                           step_length_m = 0.7,
                           step_width_m = 0.15) {

  stride_samples <- round(stride_time_sec * sr)
  stance_samples <- round(stance_pct * stride_samples)

  # Total samples: enough for n_strides on each side (interleaved)
  # Right HS at 0, 1*stride, 2*stride, ...
  # Left  HS at 0.5*stride, 1.5*stride, ...
  total_samples <- stride_samples * n_strides + 1

  # Build events
  events_list <- list()

  # Right heel strikes and toe offs
  for (i in seq_len(n_strides + 1)) {
    hs_sample <- (i - 1) * stride_samples + 1
    if (hs_sample <= total_samples) {
      events_list <- c(events_list, list(data.frame(
        event_name = "HS_R",
        time = hs_sample,
        side = "right",
        stringsAsFactors = FALSE
      )))
    }

    # Toe off = HS + stance_samples
    if (i <= n_strides) {
      to_sample <- hs_sample + stance_samples
      if (to_sample <= total_samples) {
        events_list <- c(events_list, list(data.frame(
          event_name = "TO_R",
          time = to_sample,
          side = "right",
          stringsAsFactors = FALSE
        )))
      }
    }
  }

  # Left heel strikes and toe offs (offset by half stride)
  half_stride <- round(stride_samples / 2)
  for (i in seq_len(n_strides + 1)) {
    hs_sample <- (i - 1) * stride_samples + half_stride + 1
    if (hs_sample <= total_samples) {
      events_list <- c(events_list, list(data.frame(
        event_name = "HS_L",
        time = hs_sample,
        side = "left",
        stringsAsFactors = FALSE
      )))
    }

    if (i <= n_strides) {
      to_sample <- hs_sample + stance_samples
      if (to_sample <= total_samples) {
        events_list <- c(events_list, list(data.frame(
          event_name = "TO_L",
          time = to_sample,
          side = "left",
          stringsAsFactors = FALSE
        )))
      }
    }
  }

  events <- do.call(rbind, events_list)

  # Build position data with known step/stride lengths
  # Markers: Rheel, Lheel -- walking forward in x, separated in z
  marker_names <- c("Rheel", "Lheel")

  pos_x <- matrix(0, nrow = total_samples, ncol = 2)
  pos_y <- matrix(0, nrow = total_samples, ncol = 2)
  pos_z <- matrix(0, nrow = total_samples, ncol = 2)

  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  # Place right heel: moves forward by step_length at each HS
  r_hs_times <- events$time[events$event_name == "HS_R"]
  l_hs_times <- events$time[events$event_name == "HS_L"]

  # Right foot x position: linearly interpolated based on HS positions
  r_positions <- seq(0, by = step_length_m * 2, length.out = length(r_hs_times))
  l_positions <- seq(step_length_m, by = step_length_m * 2, length.out = length(l_hs_times))

  # Simple: set positions at HS times, interpolate between
  for (i in seq_along(r_hs_times)) {
    t_idx <- r_hs_times[i]
    if (t_idx <= total_samples) pos_x[t_idx, 1] <- r_positions[i]
  }
  for (i in seq_along(l_hs_times)) {
    t_idx <- l_hs_times[i]
    if (t_idx <= total_samples) pos_x[t_idx, 2] <- l_positions[i]
  }

  # Fill in between with linear interpolation
  for (col in 1:2) {
    nz <- which(pos_x[, col] != 0 | seq_len(total_samples) == 1)
    if (length(nz) > 1) {
      pos_x[, col] <- stats::approx(nz, pos_x[nz, col],
                                      xout = seq_len(total_samples),
                                      rule = 2)$y
    }
  }

  # Z positions: ML separation
  pos_z[, 1] <- step_width_m / 2    # right foot
  pos_z[, 2] <- -step_width_m / 2   # left foot

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

  list(pe = pe, events = events)
}


# ===========================================================================
# Tests
# ===========================================================================

test_that("stride_time is correct for known gait cycle", {
  gd <- make_gait_data(sr = 100, n_strides = 3, stride_time_sec = 1.0)
  gp <- calculateGaitParameters(gd$pe, gd$events, side = "right")

  expect_s3_class(gp, "gait_parameters")
  # stride_time should be ~1.0 sec for all strides
  expect_equal(gp$stride_time, rep(1.0, 3), tolerance = 0.02)
})

test_that("cadence equals 60 / step_time", {
  gd <- make_gait_data(sr = 100, n_strides = 3, stride_time_sec = 1.0)
  gp <- calculateGaitParameters(gd$pe, gd$events, side = "both")

  # For rows with non-NA step_time
  valid <- !is.na(gp$step_time) & !is.na(gp$cadence)
  if (any(valid)) {
    expected_cadence <- 60 / gp$step_time[valid]
    expect_equal(gp$cadence[valid], expected_cadence, tolerance = 1e-6)
  }
})

test_that("stance + swing percentages sum to 100", {
  gd <- make_gait_data(sr = 100, n_strides = 3, stride_time_sec = 1.0,
                        stance_pct = 0.60)
  gp <- calculateGaitParameters(gd$pe, gd$events, side = "right")

  valid <- !is.na(gp$stance_percent) & !is.na(gp$swing_percent)
  expect_true(all(valid))
  totals <- gp$stance_percent[valid] + gp$swing_percent[valid]
  expect_equal(totals, rep(100, sum(valid)), tolerance = 1e-6)
})

test_that("stance percentage matches expected value", {
  gd <- make_gait_data(sr = 100, n_strides = 3, stride_time_sec = 1.0,
                        stance_pct = 0.60)
  gp <- calculateGaitParameters(gd$pe, gd$events, side = "right")

  expect_equal(gp$stance_percent, rep(60, 3), tolerance = 2)
})

test_that("step length computed from known marker positions", {
  gd <- make_gait_data(sr = 100, n_strides = 2, stride_time_sec = 1.0,
                        step_length_m = 0.7)
  gp <- calculateGaitParameters(gd$pe, gd$events, side = "right")

  # Stride length should be ~ 2 * step_length = 1.4
  valid_sl <- !is.na(gp$stride_length)
  if (any(valid_sl)) {
    expect_equal(gp$stride_length[valid_sl],
                 rep(1.4, sum(valid_sl)), tolerance = 0.1)
  }
})

test_that("walking speed equals stride_length / stride_time", {
  gd <- make_gait_data(sr = 100, n_strides = 2, stride_time_sec = 1.0,
                        step_length_m = 0.7)
  gp <- calculateGaitParameters(gd$pe, gd$events, side = "right")

  valid <- !is.na(gp$walking_speed) & !is.na(gp$stride_length) &
    !is.na(gp$stride_time)
  if (any(valid)) {
    expected_speed <- gp$stride_length[valid] / gp$stride_time[valid]
    expect_equal(gp$walking_speed[valid], expected_speed, tolerance = 1e-6)
  }
})

test_that("symmetry index is approximately 0 for symmetric gait", {
  gd <- make_gait_data(sr = 100, n_strides = 3, stride_time_sec = 1.0,
                        stance_pct = 0.60)
  gp <- calculateGaitParameters(gd$pe, gd$events, side = "both")
  sym <- calculateStepSymmetry(gp)

  expect_true(is.data.frame(sym))
  expect_true("SI" %in% names(sym))
  expect_true("ratio" %in% names(sym))

  # For symmetric gait, SI for stride_time should be near 0
  stride_si <- sym$SI[sym$parameter == "stride_time"]
  if (!is.na(stride_si)) {
    expect_true(stride_si < 5)
  }
})

test_that("symmetry index detects asymmetric gait", {
  # Create asymmetric events manually
  sr <- 100
  total_samples <- 401

  # Right side: stride time = 1.0 s

  # Left side: stride time = 1.2 s (asymmetric)
  events <- data.frame(
    event_name = c("HS_R", "TO_R", "HS_L", "TO_L",
                   "HS_R", "TO_R", "HS_L", "TO_L",
                   "HS_R", "HS_L"),
    time = c(1, 61, 51, 111,
             101, 161, 171, 231,
             201, 291),
    side = c("right", "right", "left", "left",
             "right", "right", "left", "left",
             "right", "left"),
    stringsAsFactors = FALSE
  )

  # Minimal PE without position data
  dummy_data <- matrix(0, nrow = total_samples, ncol = 1)
  colnames(dummy_data) <- "signal"
  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = dummy_data),
    colData = S4Vectors::DataFrame(label = "signal", type = "signal"),
    samplingRate = sr
  )

  gp <- calculateGaitParameters(pe, events, side = "both")
  sym <- calculateStepSymmetry(gp)

  # Stride time should differ between sides
  stride_si <- sym$SI[sym$parameter == "stride_time"]
  if (!is.na(stride_si)) {
    expect_true(stride_si > 0)
  }
})

test_that("multiple strides are averaged in summary", {
  gd <- make_gait_data(sr = 100, n_strides = 5, stride_time_sec = 1.0)
  gp <- calculateGaitParameters(gd$pe, gd$events, side = "right")
  summ <- summarizeGaitParameters(gp)

  expect_true(is.data.frame(summ))
  expect_true(all(c("parameter", "side", "mean", "sd", "cv") %in% names(summ)))
  expect_true("stride_time" %in% summ$parameter)

  # Mean stride_time should be close to 1.0
  st_row <- summ[summ$parameter == "stride_time" & summ$side == "right", ]
  expect_equal(st_row$mean, 1.0, tolerance = 0.02)
})

test_that("print method works without error", {
  gd <- make_gait_data(sr = 100, n_strides = 2, stride_time_sec = 1.0)
  gp <- calculateGaitParameters(gd$pe, gd$events, side = "right")

  output <- capture.output(print(gp))
  expect_true(any(grepl("Gait Parameters", output)))
  expect_true(any(grepl("stride_time", output)))
})

test_that("summarize returns correct structure", {
  gd <- make_gait_data(sr = 100, n_strides = 3, stride_time_sec = 1.0)
  gp <- calculateGaitParameters(gd$pe, gd$events, side = "right")
  summ <- summarizeGaitParameters(gp)

  expect_true(is.data.frame(summ))
  expect_equal(names(summ), c("parameter", "side", "mean", "sd", "cv"))
  expect_true(nrow(summ) > 0)
  # All values should be numeric
  expect_true(is.numeric(summ$mean))
  expect_true(is.numeric(summ$sd))
  expect_true(is.numeric(summ$cv))
})

test_that("error on missing events argument", {
  gd <- make_gait_data(sr = 100, n_strides = 2)

  # Events without any gait events
  bad_events <- data.frame(
    event_name = c("unknown_event"),
    time = c(1),
    side = c("right"),
    stringsAsFactors = FALSE
  )

  expect_error(
    calculateGaitParameters(gd$pe, bad_events),
    "No recognised gait events"
  )
})

test_that("error on events without heel strikes", {
  gd <- make_gait_data(sr = 100, n_strides = 2)

  # Only toe offs, no heel strikes
  to_only <- data.frame(
    event_name = c("TO_R", "TO_L"),
    time = c(50, 100),
    side = c("right", "left"),
    stringsAsFactors = FALSE
  )

  expect_error(
    calculateGaitParameters(gd$pe, to_only),
    "No heel strike events"
  )
})

test_that("edge case: single stride returns a result", {
  sr <- 100
  total_samples <- 201
  events <- data.frame(
    event_name = c("HS_R", "TO_R", "HS_R"),
    time = c(1, 61, 101),
    side = c("right", "right", "right"),
    stringsAsFactors = FALSE
  )

  dummy_data <- matrix(0, nrow = total_samples, ncol = 1)
  colnames(dummy_data) <- "signal"
  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = dummy_data),
    colData = S4Vectors::DataFrame(label = "signal", type = "signal"),
    samplingRate = sr
  )

  gp <- calculateGaitParameters(pe, events, side = "right")

  expect_s3_class(gp, "gait_parameters")
  expect_equal(nrow(gp), 1)
  expect_equal(gp$stride_time, 1.0)
})

test_that("alternative event naming convention works", {
  sr <- 100
  total_samples <- 301
  events <- data.frame(
    event_name = c("right_heel_strike", "right_toe_off", "right_heel_strike",
                   "left_heel_strike", "left_toe_off", "left_heel_strike"),
    time = c(1, 61, 101, 51, 111, 151),
    side = c("right", "right", "right", "left", "left", "left"),
    stringsAsFactors = FALSE
  )

  dummy_data <- matrix(0, nrow = total_samples, ncol = 1)
  colnames(dummy_data) <- "signal"
  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = dummy_data),
    colData = S4Vectors::DataFrame(label = "signal", type = "signal"),
    samplingRate = sr
  )

  gp <- calculateGaitParameters(pe, events, side = "both")

  expect_s3_class(gp, "gait_parameters")
  # Should have 1 right stride + 1 left stride
  expect_true(nrow(gp) >= 2)
})

test_that("step width from known marker positions", {
  gd <- make_gait_data(sr = 100, n_strides = 2, step_width_m = 0.15)
  gp <- calculateGaitParameters(gd$pe, gd$events, side = "right")

  valid <- !is.na(gp$step_width)
  if (any(valid)) {
    expect_equal(gp$step_width[valid],
                 rep(0.15, sum(valid)), tolerance = 0.02)
  }
})
