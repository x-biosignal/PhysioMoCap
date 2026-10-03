library(testthat)
library(PhysioMoCap)

# --- synthetic iTUG trunk angular velocity -----------------------------------

.gauss <- function(t, mu, s) exp(-((t - mu) / s)^2)

# turn angle = integral(yaw) dt = amp * s * sqrt(pi); solve for a 180 deg (pi) turn
.turn_amp <- function(s) pi / (s * sqrt(pi))

.make_tug <- function(fs = 100, turn1 = 5.0, turn2 = 9.75, s1 = 0.6, s2 = 0.5,
                     standup = 1.0, sitdown = 11.5, total = 13) {
  n <- total * fs
  t <- (0:(n - 1)) / fs
  yaw <- .turn_amp(s1) * .gauss(t, turn1, s1) +
    .turn_amp(s2) * .gauss(t, turn2, s2)
  pitch <- 1.5 * .gauss(t, standup, 0.3) + 1.3 * .gauss(t, sitdown, 0.3)
  list(av = cbind(0.05 * sin(2 * pi * t), pitch, yaw), t = t, fs = fs,
       turn1 = turn1, turn2 = turn2, standup = standup, sitdown = sitdown)
}

test_that("iTUG segments turns at the injected timings with correct duration", {
  d <- .make_tug()
  tug <- instrumentedTUG(d$av, d$fs)
  expect_s3_class(tug, "itug_report")
  expect_equal(nrow(tug$turns), 2)
  # turn centres within tolerance of the injected times
  centres <- (tug$turns$start + tug$turns$end) / 2
  expect_lt(abs(centres[1] - d$turn1), 0.3)
  expect_lt(abs(centres[2] - d$turn2), 0.3)
  # both are ~180 deg turns
  expect_true(all(abs(tug$turns$angle_deg - 180) < 20))
  # turn duration is ~ the injected width (2 * sigma at the +/-1 sigma crossings)
  expect_gt(tug$turns$duration[1], 0.8)
  expect_lt(tug$turns$duration[1], 2.5)
})

test_that("iTUG locates the sit-to-stand and turn-to-sit transitions", {
  d <- .make_tug(standup = 1.2, sitdown = 11.3)
  tug <- instrumentedTUG(d$av, d$fs)
  expect_lt(abs(tug$stand_up_time - 1.2), 0.2)
  expect_lt(abs(tug$sit_down_time - 11.3), 0.2)
  # the phase timeline covers the whole trial and is ordered
  expect_equal(tug$phases$start[1], 0)
  expect_equal(tug$phases$end[nrow(tug$phases)], tug$total_duration,
               tolerance = 1e-6)
  expect_true(all(diff(c(tug$phases$start, tug$total_duration)) >= 0))
  expect_true("turn" %in% tug$phases$phase)
})

test_that("iTUG phase timeline is gap-free with no NA/mislabelled rows", {
  d <- .make_tug()
  tug <- instrumentedTUG(d$av, d$fs)
  # no NA labels, every phase is a known label, contiguous cover [0, total]
  expect_false(anyNA(tug$phases$phase))
  expect_true(all(tug$phases$phase %in%
                    c("sit_to_stand", "walk", "turn", "turn_to_sit")))
  expect_equal(tug$phases$start[-1], head(tug$phases$end, -1))  # contiguous
  expect_equal(tug$phases$start[1], 0)
  expect_equal(tug$phases$end[nrow(tug$phases)], tug$total_duration,
               tolerance = 1e-6)
  expect_true(all(tug$phases$duration > 0))
  # a turn at the very start (NA stand-up) must not mislabel the walk/turn rows
  d2 <- .make_tug(turn1 = 0.4, standup = 0.4)
  tug2 <- instrumentedTUG(d2$av, d2$fs)
  expect_false(anyNA(tug2$phases$phase))
  expect_true(all(tug2$phases$phase %in%
                    c("sit_to_stand", "walk", "turn", "turn_to_sit")))
})

test_that("iTUG handles a trial with no detectable turn", {
  fs <- 100
  still <- cbind(0.01 * sin(seq(0, 10, length.out = 500)), 0, 0)
  tug <- instrumentedTUG(still, fs, turn_threshold = 0.5)
  expect_equal(nrow(tug$turns), 0)
  expect_s3_class(tug, "itug_report")
})

test_that("iTUG respects an explicit threshold and validates input", {
  d <- .make_tug()
  # a very high threshold suppresses the smaller-peak turn detection window
  tug <- instrumentedTUG(d$av, d$fs, turn_threshold = 3.2)
  expect_lte(nrow(tug$turns), 2)
  expect_error(instrumentedTUG(matrix(0, 3, 3), 100), "n >= 5")
  expect_error(instrumentedTUG(matrix(0, 10, 2), 100), "n x 3")
  expect_error(instrumentedTUG(d$av, d$fs, turn_axis = 4), "1, 2 or 3")
})

test_that("plotTUG returns a ggplot", {
  d <- .make_tug()
  p <- plotTUG(instrumentedTUG(d$av, d$fs))
  expect_s3_class(p, "ggplot")
  expect_error(plotTUG(list()), "itug_report")
})

# --- instrumented 10mWT ------------------------------------------------------

test_that("10mWT gait speed matches a constant-speed ground truth", {
  fs <- 100
  v <- 1.2
  t <- seq(0, 10 / v + 1, 1 / fs)
  pos <- pmin(v * t, 10)                    # ramp to 10 m then hold
  wt <- instrumented10mWT(pos, fs)
  expect_s3_class(wt, "walk_test_report")
  expect_equal(wt$gait_speed, v, tolerance = 0.02)
  expect_equal(wt$mid_distance, 6)          # default 2..8 m
})

test_that("10mWT reads the steady-state speed of an accel/decel profile", {
  fs <- 100
  # accelerate over the first 2 m, steady 1.4 m/s in the middle, decelerate
  v_steady <- 1.4
  dt <- 1 / fs
  # piecewise speed profile
  t <- seq(0, 12, dt)
  speed <- pmin(pmax(0, 0.9 * t), v_steady)          # ramp up to 1.4
  speed[t > 9] <- pmax(0, v_steady - 1.0 * (t[t > 9] - 9))  # ramp down
  pos <- cumsum(speed) * dt
  pos <- pmin(pos, 10)
  wt <- instrumented10mWT(pos, fs, mid_start = 3, mid_end = 7)
  expect_equal(wt$gait_speed, v_steady, tolerance = 0.05)
})

test_that("10mWT computes cadence from heel-strike events", {
  fs <- 100
  v <- 1.2
  t <- seq(0, 10 / v + 1, 1 / fs)
  pos <- pmin(v * t, 10)
  events <- round(seq(0.5 * fs, (10 / v) * fs, by = 0.5 * fs))  # 2 steps/s
  wt <- instrumented10mWT(pos, fs, events = events)
  expect_equal(wt$cadence_spm, 120, tolerance = 2)
})

test_that("instrumented10mWT validates the walk and section", {
  fs <- 100
  short <- pmin(1.2 * seq(0, 3, 1 / fs), 4)         # only reaches 4 m
  expect_error(instrumented10mWT(short, fs), "does not span")
  expect_error(instrumented10mWT(pmin(seq(0, 10, 1 / fs), 10), fs,
                                 mid_start = 8, mid_end = 2), "mid_start < mid_end")
  expect_error(instrumented10mWT(1:3, fs), "length >= 5")
})

# --- regression tests for adversarial-review findings (WS4-16) ----------------

test_that("iTUG returns NA transitions (not a self-contradictory time) with no turn", {
  fs <- 100
  t <- seq(0, 10, 1 / fs)
  # flat yaw (no turn) with a single pitch bump: stand-up and sit-down are
  # undefined and must not both collapse onto the one global pitch peak.
  sig <- cbind(0, 1.5 * exp(-((t - 2.5) / 0.3)^2), 0)
  tug <- instrumentedTUG(sig, fs, turn_threshold = 0.5)
  expect_equal(nrow(tug$turns), 0)
  expect_true(is.na(tug$stand_up_time))
  expect_true(is.na(tug$sit_down_time))
  expect_false(anyNA(tug$phases$phase))          # timeline still well-formed
})

test_that("10mWT reads whole-second event TIMES when the unit is given", {
  fs <- 100
  v <- 1.2
  t <- seq(0, 10 / v + 1, 1 / fs)
  pos <- pmin(v * t, 10)
  # heel strikes at 1..8 s: as indices these would collapse into the first 80 ms
  ev <- 1:8
  wt_auto <- instrumented10mWT(pos, fs, events = ev)          # auto -> indices
  wt_sec <- instrumented10mWT(pos, fs, events = ev, events_unit = "seconds")
  # mid-section (2..8 m) spans t in [1.67, 6.67] s -> 5 whole-second strikes
  expect_true(wt_sec$cadence_spm > 0)
  expect_equal(wt_sec$cadence_spm, 5 / wt_sec$mid_time * 60, tolerance = 1e-6)
  # the auto branch reads them as indices (documented behaviour) -> few/none
  expect_lt(wt_auto$cadence_spm, wt_sec$cadence_spm)
})

test_that("10mWT rejects empty / non-finite events and validates scalars", {
  fs <- 100
  pos <- pmin(1.2 * seq(0, 10, 1 / fs), 10)
  expect_error(instrumented10mWT(pos, fs, events = numeric(0)),
               "non-empty finite")
  expect_error(instrumented10mWT(pos, fs, events = c(1, NA, 3)),
               "non-empty finite")
  expect_error(instrumented10mWT(pos, fs, mid_start = c(1, 2)),
               "single .*finite")
})

test_that("iTUG rejects a non-scalar axis rather than a cryptic coercion error", {
  d <- .make_tug()
  expect_error(instrumentedTUG(d$av, d$fs, turn_axis = c(1, 3)),
               "single index")
  expect_error(instrumentedTUG(d$av, d$fs, transition_axis = NA),
               "single index")
})
