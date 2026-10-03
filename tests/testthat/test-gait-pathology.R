library(testthat)
library(PhysioMoCap)

# --- controllable synthetic waveforms (n = 101, 0-100% cycle) -----------------

.pct <- seq(0, 100, length.out = 101)

# knee flexion: small loading bump in stance, a swing bump peaking at ~72%
.mk_knee <- function(peak) {
  k <- 5 + 12 * exp(-((.pct - 15) / 8)^2)               # loading response
  swing <- .pct >= 60
  k[swing] <- peak * exp(-((.pct[swing] - 72) / 9)^2)   # swing peak == `peak`
  k
}
# ankle power: negative in early stance, an A2 push-off burst peaking ~50%
.mk_ankle <- function(a2) {
  p <- -0.6 * exp(-((.pct - 15) / 8)^2)
  push <- .pct > 40 & .pct < 62
  p[push] <- a2 * sin(pi * (.pct[push] - 40) / 22)
  p
}
# ML foot position: ~zero baseline in stance, a lateral swing bump
.mk_footml <- function(excursion) {
  f <- rep(0, 101)
  swing <- .pct >= 60
  f[swing] <- excursion * sin(pi * (.pct[swing] - 60) / 40)
  f
}
# pelvic obliquity: ~zero, a sustained contralateral drop during stance
.mk_pelvis <- function(drop) {
  p <- rep(0, 101)
  st <- .pct >= 10 & .pct <= 50
  p[st] <- drop
  p
}

# --- specificity: normal gait is not flagged ---------------------------------

test_that("normal gait is not flagged by any detector (specificity)", {
  expect_false(detectStiffKnee(.mk_knee(60))$flagged)
  expect_false(detectPushOffDeficit(.mk_ankle(3.5))$flagged)
  expect_false(detectCircumduction(.mk_footml(0.02))$flagged)
  expect_false(detectTrendelenburg(.mk_pelvis(3))$flagged)

  vars <- list(knee_flexion = .mk_knee(60), ankle_power = .mk_ankle(3.5),
               foot_ml = .mk_footml(0.02), pelvic_obliquity = .mk_pelvis(3))
  cls <- classifyGaitPatterns(vars)
  expect_false(any(cls$flagged))
})

# --- sensitivity: each injected deviation is flagged -------------------------

test_that("each injected deviation is flagged", {
  expect_true(detectStiffKnee(.mk_knee(25))$flagged)         # peak 25 < 45
  expect_true(detectPushOffDeficit(.mk_ankle(1.0))$flagged)  # A2 1.0 < 2.0
  expect_true(detectCircumduction(.mk_footml(0.10))$flagged) # 0.10 > 0.04
  expect_true(detectTrendelenburg(.mk_pelvis(12))$flagged)   # 12 > 5
})

# --- severity scales monotonically with deviation magnitude ------------------

test_that("stiff-knee severity increases as swing knee flexion falls", {
  sev <- vapply(c(60, 45, 30, 15),
                function(p) detectStiffKnee(.mk_knee(p))$severity, numeric(1))
  expect_true(all(diff(sev) > 0))
})

test_that("push-off-deficit severity increases as A2 power falls", {
  sev <- vapply(c(3.5, 2.5, 1.5, 0.5),
                function(a) detectPushOffDeficit(.mk_ankle(a))$severity,
                numeric(1))
  expect_true(all(diff(sev) > 0))
})

test_that("circumduction severity increases with lateral excursion", {
  sev <- vapply(c(0.02, 0.06, 0.10, 0.14),
                function(e) detectCircumduction(.mk_footml(e))$severity,
                numeric(1))
  expect_true(all(diff(sev) > 0))
})

test_that("Trendelenburg severity increases with pelvic drop", {
  sev <- vapply(c(3, 7, 11, 15),
                function(d) detectTrendelenburg(.mk_pelvis(d))$severity,
                numeric(1))
  expect_true(all(diff(sev) > 0))
})

# --- detector details --------------------------------------------------------

test_that("detectStiffKnee flags a delayed (late) peak even if tall", {
  k <- rep(5, 101)
  k[.pct >= 60] <- 60 * exp(-((.pct[.pct >= 60] - 92) / 6)^2)  # peak at 92%
  f <- detectStiffKnee(k)
  expect_true(f$flagged)
  expect_gt(f$peak_pct, 80)
})

test_that("detectCircumduction and detectTrendelenburg honour the sign", {
  # a lateral swing in the negative direction, flagged only with lateral_sign=-1
  fneg <- .mk_footml(-0.10)
  expect_false(detectCircumduction(fneg)$flagged)
  expect_true(detectCircumduction(fneg, lateral_sign = -1)$flagged)
  expect_error(detectCircumduction(.mk_footml(0.1), lateral_sign = 0), "\\+1 or -1")
})

# --- library + classifier ----------------------------------------------------

test_that("gaitPatternLibrary lists the supported patterns", {
  lib <- gaitPatternLibrary()
  expect_s3_class(lib, "gait_pattern_library")
  expect_setequal(lib$pattern, c("stiff_knee", "push_off_deficit",
                                 "circumduction", "trendelenburg"))
  expect_true(all(c("variable", "detector", "threshold", "description",
                    "reference") %in% names(lib)))
})

test_that("classifyGaitPatterns evaluates only the supplied variables", {
  cls <- classifyGaitPatterns(list(knee_flexion = .mk_knee(20),
                                   ankle_power = .mk_ankle(0.5)))
  expect_s3_class(cls, "gait_pattern_classification")
  expect_setequal(cls$pattern, c("stiff_knee", "push_off_deficit"))
  expect_true(all(cls$flagged))
  expect_error(classifyGaitPatterns(list(foo = 1:100)), "no recognised")
})

test_that("classifyGaitPatterns forwards per-pattern params", {
  # tighten the stiff-knee threshold so a peak of 50 is flagged
  vars <- list(knee_flexion = .mk_knee(50))
  base <- classifyGaitPatterns(vars)
  tuned <- classifyGaitPatterns(vars, params = list(stiff_knee =
                                                      list(threshold = 55)))
  expect_false(base$flagged[base$pattern == "stiff_knee"])
  expect_true(tuned$flagged[tuned$pattern == "stiff_knee"])
})

# --- validation + print ------------------------------------------------------

test_that("detectors validate their waveforms", {
  expect_error(detectStiffKnee(1:3), "length >= 5")
  expect_error(detectPushOffDeficit(c(1, 2, NA, 4, 5)), "finite")
})

test_that("print methods work", {
  expect_output(print(detectStiffKnee(.mk_knee(20))), "gait_pattern_flag")
  expect_output(print(gaitPatternLibrary()), "pattern library")
  expect_output(print(classifyGaitPatterns(list(knee_flexion = .mk_knee(20)))),
                "classification")
})

# --- regression tests for adversarial-review findings (WS4-13) ----------------

test_that("a delay-flagged stiff knee is graded, and severity rises with delay", {
  mk_delayed <- function(peak_pct) {
    k <- rep(5, 101)
    sw <- .pct >= 60
    k[sw] <- 60 * exp(-((.pct[sw] - peak_pct) / 5)^2)  # tall (60) but late
    k
  }
  f <- detectStiffKnee(mk_delayed(90))
  expect_true(f$flagged)
  expect_gt(f$severity, 0)                              # not silently 0
  sev <- vapply(c(78, 84, 90, 98),
                function(p) detectStiffKnee(mk_delayed(p))$severity, numeric(1))
  expect_true(all(diff(sev) >= 0) && sev[4] > sev[1])
})

test_that("degenerate parameters give a finite [0,1] severity, never NaN", {
  expect_true(is.finite(detectPushOffDeficit(rep(0, 101),
                                             normal_peak = 0)$severity))
  expect_equal(detectCircumduction(rep(0, 101), severe = 0)$severity, 0)
  expect_equal(detectTrendelenburg(rep(0, 101), severe = 0)$severity, 0)
  # a whole classification stays numeric (no NaN poisoning mean/any)
  cls <- classifyGaitPatterns(
    list(foot_ml = rep(0, 101)),
    params = list(circumduction = list(severe = 0)))
  expect_false(any(is.nan(cls$severity)))
})
