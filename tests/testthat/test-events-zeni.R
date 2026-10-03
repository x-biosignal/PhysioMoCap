library(testthat)
library(PhysioMoCap)
suppressMessages(library(SummarizedExperiment))

# --- Zeni coordinate-method gait-event detection (WS4-05) ---------------------

# Build a synthetic treadmill trial: the sacrum barely translates in the AP
# direction while each foot marker oscillates fore/aft relative to it. Left and
# right feet are half a stride out of phase. The toe leads the heel in the AP
# direction (anatomically anterior) and is slightly phase-shifted so toe-off
# lands near mid/late stance.
.make_zeni_trial <- function(fs = 100, period = 110, n_strides = 7,
                             tail = 40, amp = 0.35, fwd = 1, ap = "x",
                             extra_markers = NULL, seed = 1) {
  set.seed(seed)
  n <- n_strides * period + tail
  t <- 0:(n - 1)
  ph_r <- 2 * pi * t / period
  ph_l <- ph_r + pi
  sac <- 0.02 * sin(2 * pi * t / period * 2)
  rhee <- sac + fwd * amp * cos(ph_r)
  lhee <- sac + fwd * amp * cos(ph_l)
  rtoe <- sac + fwd * (0.18 + amp * cos(ph_r - 0.6))
  ltoe <- sac + fwd * (0.18 + amp * cos(ph_l - 0.6))

  markers <- c("RHEE", "LHEE", "RTOE", "LTOE", "SACR")
  ap_mat <- cbind(rhee, lhee, rtoe, ltoe, sac)
  colnames(ap_mat) <- markers
  small <- function() {
    m <- matrix(stats::rnorm(n * length(markers), 0, 0.01), n, length(markers))
    colnames(m) <- markers
    m
  }
  axes <- list(position_x = small(), position_y = small(), position_z = small())
  axes[[paste0("position_", ap)]] <- ap_mat

  pe <- PhysioCore::PhysioExperiment(
    assays = do.call(S4Vectors::SimpleList, axes),
    colData = S4Vectors::DataFrame(label = markers, type = "marker"),
    samplingRate = fs
  )
  # ground-truth peaks/troughs of the clean relative signals, found with an
  # independent windowed argmax/argmin oracle
  win_extrema <- function(x, period, which_fun) {
    n <- length(x)
    centres <- integer(0)
    k <- 1L
    while (k <= n) {
      hi <- min(k + period - 1L, n)
      seg <- x[k:hi]
      idx <- k - 1L + which_fun(seg)
      # keep only interior extrema (peak detector cannot flag frame 1 or n)
      if (idx > 1L && idx < n) centres <- c(centres, idx)
      k <- hi + 1L
    }
    unique(centres)
  }
  list(pe = pe, n = n, period = period,
       hs_r_gt = win_extrema(amp * cos(ph_r), period, which.max),
       hs_l_gt = win_extrema(amp * cos(ph_l), period, which.max),
       to_r_gt = win_extrema(amp * cos(ph_r - 0.6), period, which.min),
       to_l_gt = win_extrema(amp * cos(ph_l - 0.6), period, which.min))
}

.markers_lr <- list(heel_left = "LHEE", heel_right = "RHEE",
                    toe_left = "LTOE", toe_right = "RTOE")

# nearest-neighbour matching error (frames)
.match_err <- function(detected, truth) {
  vapply(detected, function(d) min(abs(d - truth)), numeric(1))
}

test_that("detectEventsZeni finds IC/TO within +/-2 frames of ground truth", {
  tr <- .make_zeni_trial()
  ev <- detectEventsZeni(tr$pe, markers = .markers_lr, reference = "SACR")

  expect_s3_class(ev, "detected_events")
  expect_equal(attr(ev, "ap_axis"), "x")
  expect_equal(attr(ev, "direction"), 1)

  hs_r <- ev$index[ev$event == "right_heel_strike"]
  to_r <- ev$index[ev$event == "right_toe_off"]
  hs_l <- ev$index[ev$event == "left_heel_strike"]
  to_l <- ev$index[ev$event == "left_toe_off"]

  expect_true(all(.match_err(hs_r, tr$hs_r_gt) <= 2))
  expect_true(all(.match_err(to_r, tr$to_r_gt) <= 2))
  expect_true(all(.match_err(hs_l, tr$hs_l_gt) <= 2))
  expect_true(all(.match_err(to_l, tr$to_l_gt) <= 2))
})

test_that("detectEventsZeni assigns L/R correctly across >=5 strides per side", {
  tr <- .make_zeni_trial()
  ev <- detectEventsZeni(tr$pe, markers = .markers_lr, reference = "SACR")

  hs_r <- sort(ev$index[ev$event == "right_heel_strike"])
  hs_l <- sort(ev$index[ev$event == "left_heel_strike"])
  expect_gte(length(hs_r), 5)
  expect_gte(length(hs_l), 5)
  # every row carries an explicit side; names match the side
  expect_true(all(ev$side[grepl("^right", ev$event)] == "right"))
  expect_true(all(ev$side[grepl("^left", ev$event)] == "left"))
  # left heel strikes fall roughly midway between consecutive right heel strikes
  # (about half a stride offset)
  offset <- vapply(hs_l, function(l) {
    before <- hs_r[hs_r < l]
    if (length(before) == 0) return(NA_real_)
    (l - before[length(before)]) / tr$period
  }, numeric(1))
  offset <- offset[is.finite(offset)]
  expect_true(all(abs(offset - 0.5) < 0.15))
})

test_that("detectEvents(method = 'zeni') delegates and tags the schema", {
  tr <- .make_zeni_trial()
  ev <- detectEvents(tr$pe, schema_gait, method = "zeni",
                     markers = .markers_lr, reference = "SACR")
  expect_s3_class(ev, "detected_events")
  expect_equal(attr(ev, "schema"), schema_gait$task_type)
  expect_true(all(c("right_heel_strike", "left_heel_strike",
                    "right_toe_off", "left_toe_off") %in% ev$event))
})

test_that("Zeni events feed calculateGaitParameters", {
  tr <- .make_zeni_trial()
  ev <- detectEventsZeni(tr$pe, markers = .markers_lr, reference = "SACR")
  gp <- calculateGaitParameters(tr$pe, ev)
  expect_s3_class(gp, "data.frame")
  expect_true(nrow(gp) >= 5)
  expect_true(all(c("side", "stride", "stride_time") %in% names(gp)))
  # detected stride time should be close to the true period (1.1 s)
  expect_true(median(gp$stride_time, na.rm = TRUE) > 1.0 &&
                median(gp$stride_time, na.rm = TRUE) < 1.2)
})

test_that("detectEventsZeni auto-detects the AP axis when it is not x", {
  tr <- .make_zeni_trial(ap = "y")
  ev <- detectEventsZeni(tr$pe, markers = .markers_lr, reference = "SACR")
  expect_equal(attr(ev, "ap_axis"), "y")
  expect_true(all(.match_err(ev$index[ev$event == "right_heel_strike"],
                             tr$hs_r_gt) <= 2))
})

test_that("detectEventsZeni auto-detects a reversed progression direction", {
  tr <- .make_zeni_trial(fwd = -1)
  ev <- detectEventsZeni(tr$pe, markers = .markers_lr, reference = "SACR")
  expect_equal(attr(ev, "direction"), -1)
  # ground truth is orientation-independent (heel most-anterior = same frames)
  expect_true(all(.match_err(ev$index[ev$event == "right_heel_strike"],
                             tr$hs_r_gt) <= 2))
})

test_that("explicit ap_axis and direction override auto-detection", {
  tr <- .make_zeni_trial()
  ev <- detectEventsZeni(tr$pe, markers = .markers_lr, reference = "SACR",
                         ap_axis = "x", direction = 1)
  expect_equal(attr(ev, "ap_axis"), "x")
  expect_equal(attr(ev, "direction"), 1)
  expect_gte(sum(ev$event == "right_heel_strike"), 5)
})

test_that("reference = 'com' works with a full marker set", {
  bsip <- segmentParameters("deLeva_male")
  need <- unique(unlist(lapply(seq_len(nrow(bsip)), function(i) {
    c(bsip$proximal_marker[i], bsip$distal_marker[i])
  })))
  tr <- .make_zeni_trial()
  # augment the trial PE with the (near-stationary) markers the COM map needs
  extra <- setdiff(need, c("RHEE", "LHEE", "RTOE", "LTOE"))
  n <- tr$n
  set.seed(2)
  addcols <- function(mat) {
    add <- matrix(stats::rnorm(n * length(extra), 0, 0.01), n, length(extra))
    colnames(add) <- extra
    cbind(mat, add)
  }
  px <- addcols(SummarizedExperiment::assay(tr$pe, "position_x"))
  py <- addcols(SummarizedExperiment::assay(tr$pe, "position_y"))
  pz <- addcols(SummarizedExperiment::assay(tr$pe, "position_z"))
  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = px, position_y = py,
                                   position_z = pz),
    colData = S4Vectors::DataFrame(label = colnames(px), type = "marker"),
    samplingRate = 100
  )
  ev <- detectEventsZeni(pe, markers = .markers_lr, reference = "com",
                         body_mass = 70)
  expect_s3_class(ev, "detected_events")
  expect_gte(sum(ev$event == "right_heel_strike"), 5)
  expect_error(
    detectEventsZeni(pe, markers = .markers_lr, reference = "com"),
    "body_mass")
})

test_that("detectEventsZeni validates its inputs", {
  tr <- .make_zeni_trial()
  expect_error(
    detectEventsZeni(tr$pe, markers = .markers_lr, reference = "NOPE"),
    "not found")
  expect_error(
    detectEventsZeni(tr$pe, markers = list(), reference = "SACR"),
    "No sides")
  expect_error(
    detectEventsZeni(tr$pe,
                     markers = list(heel_right = "ZZZ", toe_right = "RTOE"),
                     reference = "SACR"),
    "not found")
  expect_error(
    detectEvents(matrix(1, 5, 1), schema_gait, method = "zeni",
                 sampling_rate = 100),
    "requires a PhysioExperiment")
})

# --- regression tests for adversarial-review findings (WS4-05) ---

test_that("AP-axis auto-detect works from a toe-only marker set", {
  tr <- .make_zeni_trial(ap = "y")
  ev <- expect_silent(
    detectEventsZeni(tr$pe,
                     markers = list(toe_left = "LTOE", toe_right = "RTOE"),
                     reference = "SACR"))
  expect_equal(attr(ev, "ap_axis"), "y")
  expect_true(all(.match_err(ev$index[ev$event == "right_toe_off"],
                             tr$to_r_gt) <= 2))
  # no heel events when only toes were supplied
  expect_equal(sum(grepl("heel_strike", ev$event)), 0)
})

test_that("a bad numeric ap_axis gives a clean error, not negative indexing", {
  tr <- .make_zeni_trial()
  expect_error(
    detectEventsZeni(tr$pe, markers = .markers_lr, reference = "SACR",
                     ap_axis = -1),
    "ap_axis must be")
  expect_error(
    detectEventsZeni(tr$pe, markers = .markers_lr, reference = "SACR",
                     ap_axis = 9),
    "ap_axis must be")
})

test_that("an empty detected_events frame errors clearly in gait parameters", {
  tr <- .make_zeni_trial()
  empty <- detectEventsZeni(tr$pe, markers = .markers_lr, reference = "SACR")
  empty <- empty[0, , drop = FALSE]
  class(empty) <- c("detected_events", "data.frame")
  expect_error(calculateGaitParameters(tr$pe, empty), "No gait events")
})
