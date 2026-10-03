# Instrumented spasticity (Tardieu).

# a fast passive stretch that rises quickly to `catch` deg, then decelerates
.mk_stretch <- function(catch, rise, fs = 200, total = 0.8) {
  t <- seq(0, total, by = 1 / fs)
  ifelse(t <= rise, catch * t / rise, catch + 8 * (t - rise) / (total - rise))
}

test_that("tardieuStretch finds the velocity-arrest catch angle (R1)", {
  fs <- 200
  st <- tardieuStretch(.mk_stretch(25, 0.25, fs), sampling_rate = fs,
                       onset = "velocity")
  expect_s3_class(st, "tardieu_stretch")
  expect_equal(st$catch_angle, 25, tolerance = 2)
  expect_gt(st$peak_velocity, 50)
})

test_that("tardieuStretch finds the EMG reflex-onset catch angle", {
  fs <- 200; t <- seq(0, 0.6, by = 1 / fs)
  angle <- ifelse(t <= 0.25, 25 * t / 0.25, 25 + 5 * (t - 0.25) / 0.35)
  set.seed(1)
  emg <- rnorm(length(t), 0, 0.02)
  burst <- t >= 0.25 & t <= 0.42
  emg[burst] <- emg[burst] + sin(2 * pi * 80 * t[burst])   # reflex burst at catch
  st <- tardieuStretch(angle, emg = emg, sampling_rate = fs, onset = "emg",
                       baseline_sec = 0.15, threshold_sd = 4)
  expect_equal(st$catch_angle, 25, tolerance = 2)
  expect_true(is.finite(st$reflex_latency_ms))

  expect_error(tardieuStretch(angle, sampling_rate = fs, onset = "emg"),
               "needs an 'emg'")
})

test_that("tardieuScore gives R1, R2 and the dynamic component", {
  fs <- 200; t <- seq(0, 0.6, by = 1 / fs)
  fast <- ifelse(t <= 0.25, 25 * t / 0.25, 25 + 5 * (t - 0.25) / 0.35)
  slow <- 40 * t / 0.6                                       # full ROM, no catch
  sc <- tardieuScore(tardieuStretch(fast, sampling_rate = fs, onset = "velocity"),
                     slow)
  expect_s3_class(sc, "tardieu_score")
  expect_equal(sc$R1, 25, tolerance = 2)
  expect_equal(sc$R2, 40, tolerance = 1)
  expect_equal(sc$dynamic_component, sc$R2 - sc$R1)
})

test_that("reflexThreshold: catch angle falls as stretch velocity rises", {
  fs <- 200
  st <- lapply(list(c(30, 0.5), c(25, 0.35), c(20, 0.22), c(15, 0.13)),
               function(p) tardieuStretch(.mk_stretch(p[1], p[2], fs),
                                          sampling_rate = fs, onset = "velocity"))
  rt <- reflexThreshold(st)
  expect_s3_class(rt, "reflex_threshold")
  expect_lt(rt$slope, 0)                                     # velocity-dependent
  expect_error(reflexThreshold(st[1]), ">= 2")
})
