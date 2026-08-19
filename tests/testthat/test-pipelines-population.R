library(testthat)
library(PhysioMoCap)

# --- ACL: limb symmetry index + return-to-sport ------------------------------

test_that("ACL LSI is computed correctly and drives the RTS decision", {
  tests <- data.frame(
    test = c("quad_strength", "single_hop", "triple_hop"),
    involved = c(85, 140, 440), uninvolved = c(100, 150, 440))
  r <- pipelineACLrts(tests, threshold = 90)
  expect_s3_class(r, "acl_rts_report")
  expect_equal(r$lsi$lsi, c(85, 140 / 150 * 100, 100), tolerance = 1e-9)
  expect_equal(r$lsi$pass, c(FALSE, TRUE, TRUE))
  expect_false(r$rts_ready)                       # quad LSI 85 < 90
  expect_equal(r$n_pass, 2)
})

test_that("ACL RTS is ready only when every LSI meets the threshold", {
  ready <- pipelineACLrts(data.frame(test = c("a", "b"),
                                     involved = c(95, 92),
                                     uninvolved = c(100, 100)))
  expect_true(ready$rts_ready)
})

test_that("ACL LSI inverts for lower-is-better tests and accepts a named list", {
  # a timed test where lower is better: involved slower -> LSI < 100
  r <- pipelineACLrts(data.frame(test = "timed_hop", involved = 6.0,
                                 uninvolved = 5.0, higher_better = FALSE))
  expect_equal(r$lsi$lsi, 5 / 6 * 100, tolerance = 1e-9)
  rl <- pipelineACLrts(list(hop = c(90, 100)))
  expect_equal(rl$lsi$lsi, 90)
})

test_that("pipelineACLrts validates its inputs", {
  expect_error(pipelineACLrts(data.frame(a = 1)), "columns test")
  expect_error(pipelineACLrts(data.frame(test = "x", involved = 1,
                                         uninvolved = 0)), "uninvolved > 0")
  expect_error(pipelineACLrts(list(1, 2)), "must be named")
})

# --- Parkinson's: freeze index detects synthetic FOG -------------------------

test_that("the freeze index detects synthetic FOG epochs, not normal gait", {
  set.seed(1)
  fs <- 100
  normal <- sin(2 * pi * 2 * seq(0, 10, 1 / fs))     # 2 Hz locomotor
  fog    <- 0.8 * sin(2 * pi * 6.5 * seq(0, 6, 1 / fs))  # 6.5 Hz freeze band
  rest   <- 0.02 * stats::rnorm(4 * fs)              # near-still
  sig <- c(normal, fog, rest)
  rp <- pipelinePDfog(sig, fs, window_sec = 3, step_sec = 0.5)
  expect_s3_class(rp, "pd_fog_report")
  w <- rp$windows
  # normal segment (t < ~9): no FOG; FOG segment (10.5-15.5 s): FOG flagged
  expect_equal(sum(w$fog & w$time < 9), 0)
  expect_gt(sum(w$fog & w$time > 10.5 & w$time < 15.5), 0)
  expect_equal(sum(w$fog & w$time > 16.5), 0)       # rest not flagged
  # freeze index is far higher during FOG than normal gait
  expect_gt(median(w$freeze_index[w$time > 10.5 & w$time < 15.5]),
            10 * (median(w$freeze_index[w$time < 9]) + 0.1))
})

test_that("pipelinePDfog validates its inputs", {
  expect_error(pipelinePDfog(rnorm(50), 100, window_sec = 4), "one analysis window")
  expect_error(pipelinePDfog(c(1, NA, 3), 100), "finite")
})

# --- Stroke: paretic propulsion ----------------------------------------------

test_that("paretic propulsion Pp matches the propulsive-impulse ratio", {
  fs <- 100
  # constant propulsive force: paretic = 1, non-paretic = 3 -> Pp = 1/4
  pp <- pipelineStrokePropulsion(rep(1, 100), rep(3, 100), fs)
  expect_equal(pp$paretic_propulsion, 0.25, tolerance = 1e-3)
  # only positive (anterior/propulsive) force contributes
  sym <- pipelineStrokePropulsion(c(rep(-2, 50), rep(2, 50)),
                                  c(rep(-2, 50), rep(2, 50)), fs)
  expect_equal(sym$paretic_propulsion, 0.5, tolerance = 1e-9)
})

# --- Amputee: work asymmetry -------------------------------------------------

test_that("amputee work-asymmetry index reflects the positive-work difference", {
  fs <- 100
  # intact generates 3x the prosthetic positive work -> (3-1)/(3+1) = 0.5
  am <- pipelineAmputee(rep(1, 101), rep(3, 101), fs)
  expect_s3_class(am, "amputee_report")
  expect_equal(am$work_asymmetry_index, 0.5, tolerance = 1e-3)
  # symmetric limbs -> 0
  sym <- pipelineAmputee(sin(2 * pi * seq(0, 1, length.out = 101)),
                         sin(2 * pi * seq(0, 1, length.out = 101)), fs)
  expect_equal(sym$work_asymmetry_index, 0, tolerance = 1e-9)
})

# --- Cerebral palsy: GDI + pathology -----------------------------------------

test_that("pipelineCPgait produces a GDI report with pathology flags", {
  skip_if_not_installed("PhysioGaitNorm")
  norm <- PhysioGaitNorm::loadGaitNorm("adult_reference", cycle = 51)
  kin <- norm$mean[norm$variables, , drop = FALSE]
  kin["knee_flexion", ] <- kin["knee_flexion", ] * 0.4   # stiff knee
  cp <- pipelineCPgait(kin, norm = norm, gmfcs = "III")
  expect_s3_class(cp, "cp_gait_report")
  expect_true(is.finite(cp$gdi))
  expect_true(cp$gdi_category %in% c("unimpaired", "mild", "moderate",
                                     "marked", "severe"))
  expect_identical(cp$gmfcs, "III")
  expect_true("stiff_knee" %in% cp$pathology$pattern[cp$pathology$flagged])
  expect_error(pipelineCPgait(kin, norm = norm, gmfcs = "VII"), "GMFCS level")
})

# --- report printing ---------------------------------------------------------

test_that("each pipeline report prints", {
  expect_output(print(pipelineACLrts(list(a = c(95, 100)))), "acl_rts_report")
  expect_output(print(pipelineStrokePropulsion(rep(1, 50), rep(1, 50), 100)),
                "stroke_propulsion_report")
  expect_output(print(pipelineAmputee(rep(1, 50), rep(2, 50), 100)),
                "amputee_report")
  fs <- 100
  rp <- pipelinePDfog(sin(2 * pi * 2 * seq(0, 8, 1 / fs)), fs, window_sec = 3)
  expect_output(print(rp), "pd_fog_report")
})

# --- regression tests for adversarial-review findings (WS4-14) ----------------

test_that("low-amplitude FOG is detected alongside a loud walking bout", {
  fs <- 100
  loud_walk <- 5 * sin(2 * pi * 2 * seq(0, 10, 1 / fs))
  quiet_fog <- 0.3 * sin(2 * pi * 6.5 * seq(0, 6, 1 / fs))
  rp <- pipelinePDfog(c(loud_walk, quiet_fog), fs, window_sec = 3,
                      step_sec = 0.5)
  w <- rp$windows
  expect_gt(sum(w$fog & w$time > 10.5), 0)        # quiet FOG not masked
  expect_equal(sum(w$fog & w$time < 9), 0)        # loud normal walk not flagged
})

test_that("pipelineAmputee reports mass-normalised work when body_mass is given", {
  raw <- pipelineAmputee(rep(1, 101), rep(3, 101), 100)
  perkg <- pipelineAmputee(rep(1, 101), rep(3, 101), 100, body_mass = 70)
  expect_gt(raw$positive_work_intact, perkg$positive_work_intact)
  expect_equal(perkg$positive_work_intact, raw$positive_work_intact / 70,
               tolerance = 1e-9)
  # the asymmetry index (a ratio) is unchanged
  expect_equal(raw$work_asymmetry_index, perkg$work_asymmetry_index)
})

test_that("pipelineAmputee rejects non-finite power traces cleanly", {
  expect_error(pipelineAmputee(c(1, NA, 3), rep(1, 3), 100), "finite")
})

test_that("pipelinePDfog validates the analysis bands and windows", {
  expect_error(pipelinePDfog(stats::rnorm(500), 100, freeze_band = c(8, 3)),
               "freeze_band")
  expect_error(pipelinePDfog(stats::rnorm(500), 100, window_sec = -1),
               "window_sec")
})

test_that("ACL LSI guards degenerate lower-is-better and malformed inputs", {
  expect_error(
    pipelineACLrts(data.frame(test = "t", involved = 0, uninvolved = 5,
                              higher_better = FALSE)),
    "lower-is-better")
  expect_error(pipelineACLrts(list(a = 5)), "pair")
})
