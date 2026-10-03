library(testthat)

# Analytic golden fixture: a circular CoP trajectory of radius R at rotational
# frequency f has closed-form Prieto measures:
#   MDIST = RDIST = R;  TOTEX (per rev) = 2*pi*R;  MVELO = 2*pi*R*f;
#   MFREQ = f;  AREA-SW = pi*R^2*f.
make_circle <- function(R = 5, f = 0.25, fs = 200, dur = 40) {
  t <- seq(0, dur, by = 1 / fs)
  list(ap = R * sin(2 * pi * f * t),
       ml = R * cos(2 * pi * f * t),
       R = R, f = f, fs = fs, dur = dur, n = length(t))
}

test_that("swayMetrics matches circular-trajectory analytic values within 2%", {
  cir <- make_circle()
  sm <- swayMetrics(cbind(ml = cir$ml, ap = cir$ap), sampling_rate = cir$fs)

  n_rev <- cir$f * cir$dur
  expect_equal(sm$mean_distance, cir$R, tolerance = 1e-4)
  expect_equal(sm$rms_distance, cir$R, tolerance = 1e-4)
  expect_equal(sm$path_length, 2 * pi * cir$R * n_rev, tolerance = 0.02)
  expect_equal(sm$mean_velocity, 2 * pi * cir$R * cir$f, tolerance = 0.02)
  expect_equal(sm$mean_frequency, cir$f, tolerance = 0.01)
  expect_equal(sm$area_sw, pi * cir$R^2 * cir$f, tolerance = 0.01)
  expect_equal(sm$rms_distance_ap, cir$R / sqrt(2), tolerance = 1e-3)
})

test_that("swayMetrics 95% confidence ellipse area matches chi-square eigen form", {
  cir <- make_circle()
  sm <- swayMetrics(cbind(ml = cir$ml, ap = cir$ap), sampling_rate = cir$fs)

  ap <- cir$ap - mean(cir$ap)
  ml <- cir$ml - mean(cir$ml)
  n <- length(ap)
  S <- matrix(c(mean(ap^2), mean(ap * ml), mean(ap * ml), mean(ml^2)), 2, 2)
  lam <- eigen(S, only.values = TRUE)$values
  # For large n, 2*F_{0.05}[2,n-2] -> chi-square_{0.05,2}; agree within ~0.1%.
  area_chi <- pi * stats::qchisq(0.95, 2) * sqrt(prod(lam))
  expect_equal(sm$area_ce, area_chi, tolerance = 0.01)
  expect_true(sm$area_ce > 0)
})

test_that("path length equals the exact value on a straight diagonal ramp", {
  fs <- 100
  n <- 500
  ap <- seq(0, 3, length.out = n)
  ml <- seq(0, 4, length.out = n)
  sm <- swayMetrics(cbind(ml = ml, ap = ap), sampling_rate = fs, detrend = "none")
  # total straight-line distance from (0,0) to (4,3) = 5
  expect_equal(sm$path_length, 5, tolerance = 1e-8)
  # mean velocity = distance / duration, duration = (n-1)/fs
  expect_equal(sm$mean_velocity, 5 / ((n - 1) / fs), tolerance = 1e-8)
  expect_equal(sm$range_ap, 3, tolerance = 1e-8)
  expect_equal(sm$range_ml, 4, tolerance = 1e-8)
})

test_that("swayMetrics accepts calculateCOP data.frame and ap/ml vectors alike", {
  cir <- make_circle(dur = 20)
  df <- data.frame(cop_x = cir$ml, cop_y = cir$ap)  # calculateCOP convention
  sm_df <- swayMetrics(df, sampling_rate = cir$fs)
  sm_v <- swayMetrics(NULL, sampling_rate = cir$fs, ap = cir$ap, ml = cir$ml)
  expect_equal(sm_df$path_length, sm_v$path_length)
  expect_equal(sm_df$area_ce, sm_v$area_ce)
})

test_that("swayMetrics reuses sampleEntropy and returns finite complexity", {
  set.seed(11)
  n <- 2000
  ap <- cumsum(rnorm(n)) * 0.1
  ml <- cumsum(rnorm(n)) * 0.1
  sm <- swayMetrics(cbind(ml = ml, ap = ap), sampling_rate = 100)
  expect_true(is.finite(sm$sample_entropy_ap))
  expect_true(is.finite(sm$dfa_alpha_ap))
  # entropy = FALSE skips them
  sm2 <- swayMetrics(cbind(ml = ml, ap = ap), sampling_rate = 100, entropy = FALSE)
  expect_true(is.na(sm2$sample_entropy_ap))
})

test_that("DFA alpha separates white noise (~0.5) from a random walk (~1.5)", {
  set.seed(7)
  white <- rnorm(4000)
  brown <- cumsum(rnorm(4000))
  a_white <- PhysioMoCap:::.pg_dfa(white)
  a_brown <- PhysioMoCap:::.pg_dfa(brown)
  expect_equal(a_white, 0.5, tolerance = 0.12)
  expect_equal(a_brown, 1.5, tolerance = 0.15)
  expect_true(a_brown > a_white)
})

test_that("time-to-boundary is NA without a base of support and finite with one", {
  cir <- make_circle(R = 2, dur = 20)
  sm0 <- swayMetrics(cbind(ml = cir$ml, ap = cir$ap), sampling_rate = cir$fs)
  expect_true(is.na(sm0$time_to_boundary_ap))
  sm1 <- swayMetrics(cbind(ml = cir$ml, ap = cir$ap), sampling_rate = cir$fs,
                     base_of_support = c(ap = 5, ml = 5))
  expect_true(is.finite(sm1$time_to_boundary_ap))
  expect_true(sm1$time_to_boundary_ap > 0)
})

test_that("swayMetrics$metrics is aligned to the schema_balance metric names", {
  cir <- make_circle(dur = 20)
  sm <- swayMetrics(cbind(ml = cir$ml, ap = cir$ap), sampling_rate = cir$fs)
  expect_true(all(schema_balance$metrics %in% names(sm$metrics)))
  expect_equal(nrow(sm$metrics), 1L)
})

# ---- Sensory Organization Test ---------------------------------------------

test_that("SOT composite and sensory ratios match worked-example arithmetic", {
  sc <- rbind(
    C1 = c(94, 95, 93),
    C2 = c(92, 91, 93),
    C3 = c(88, 90, 89),
    C4 = c(85, 84, 86),
    C5 = c(70, 72, 68),
    C6 = c(65, 66, 64)
  )
  res <- sensoryOrganizationTest(sc)

  cm <- rowMeans(sc)
  # composite = (mean_C1 + mean_C2 + all 12 trials of C3..C6) / 14
  comp_expected <- (cm[["C1"]] + cm[["C2"]] + sum(sc[3:6, ])) / 14
  expect_equal(unname(res$composite), unname(comp_expected))

  expect_equal(unname(res$ratios[["SOM"]]), cm[["C2"]] / cm[["C1"]])
  expect_equal(unname(res$ratios[["VIS"]]), cm[["C4"]] / cm[["C1"]])
  expect_equal(unname(res$ratios[["VEST"]]), cm[["C5"]] / cm[["C1"]])
  expect_equal(unname(res$ratios[["PREF"]]),
               (cm[["C3"]] + cm[["C6"]]) / (cm[["C2"]] + cm[["C5"]]))
})

test_that("SOT converts peak-to-peak sway angle to equilibrium score", {
  # theta_pp of 0 -> EQ 100; theta_pp = theta_limit -> EQ 0
  ang <- matrix(c(0, 6.25, 12.5), nrow = 6, ncol = 3, byrow = FALSE)
  ang[] <- 6.25   # every trial 6.25 deg -> EQ = 100*(12.5-6.25)/12.5 = 50
  res <- sensoryOrganizationTest(sway_angle = ang)
  expect_true(all(abs(res$equilibrium - 50) < 1e-9))
  expect_equal(unname(res$composite), 50)
})

test_that("SOT ragged list (unequal trials) does not score padding as falls", {
  # Different conditions may have different trial counts. Structural padding
  # introduced by rbind must NOT be counted as a fall (0) under fall_as_zero.
  res <- sensoryOrganizationTest(list(
    C1 = c(90, 90, 90),
    C2 = c(80, 80),          # only two trials
    C3 = c(70, 70, 70),
    C4 = c(60, 60, 60),
    C5 = c(50, 50, 50),
    C6 = c(40, 40, 40)
  ))
  expect_equal(unname(res$condition_means[["C2"]]), 80)
  # composite = (90 + 80 + 12 tail trials summing to 660) / (2 + 12)
  expect_equal(unname(res$composite), 830 / 14)
  expect_equal(unname(res$ratios[["SOM"]]), 80 / 90)
  # a genuine fall (explicit NA) is still scored 0
  res2 <- sensoryOrganizationTest(list(
    C1 = c(90, 90), C2 = c(80, NA), C3 = c(70, 70),
    C4 = c(60, 60), C5 = c(50, 50), C6 = c(40, 40)
  ))
  expect_equal(unname(res2$condition_means[["C2"]]), 40)  # (80 + 0) / 2
})

test_that("SOT treats NA trials as falls scored zero", {
  sc <- matrix(90, nrow = 6, ncol = 3)
  sc[5, 2] <- NA  # a fall in condition 5
  res <- sensoryOrganizationTest(sc, fall_as_zero = TRUE)
  expect_equal(res$equilibrium[5, 2], 0)
  expect_true(res$condition_means[["C5"]] < 90)
})

# ---- mCTSIB -----------------------------------------------------------------

test_that("mCTSIB returns condition means and composite", {
  res <- mCTSIB(eyes_open_firm = c(0.4, 0.5),
                eyes_closed_firm = c(0.6, 0.7),
                eyes_open_foam = c(0.9, 1.0),
                eyes_closed_foam = c(1.6, 1.8))
  expect_equal(unname(res$condition_means[["eyes_open_firm"]]), 0.45)
  expect_equal(unname(res$condition_means[["eyes_closed_foam"]]), 1.7)
  expect_equal(res$composite, mean(c(0.45, 0.65, 0.95, 1.7)))
})

test_that("mCTSIB tolerates missing conditions", {
  res <- mCTSIB(eyes_open_firm = c(0.4, 0.5), eyes_closed_firm = c(0.6, 0.7))
  expect_true(is.na(res$condition_means[["eyes_open_foam"]]))
  expect_equal(res$composite, mean(c(0.45, 0.65)))
})

# ---- Limits of Stability ----------------------------------------------------

test_that("LOS straight forward lean gives 100% directional control", {
  fs <- 100
  t <- seq(0, 3, by = 1 / fs)
  lean <- pmin(t / 1.5, 1) * 5           # ramp forward to 5, then hold
  cop <- data.frame(cop_x = rep(0, length(t)), cop_y = lean)
  res <- limitsOfStability(cop, sampling_rate = fs, target = 0,
                           los_distance = 10)
  expect_equal(res$directional_control, 100, tolerance = 1e-6)
  expect_equal(res$max_excursion, 5, tolerance = 1e-6)
  expect_equal(res$max_pct, 50, tolerance = 1e-6)
  expect_true(res$reaction_time >= 0 && res$reaction_time < 1.5)
})

test_that("LOS off-axis wandering lowers directional control below 100", {
  fs <- 100
  t <- seq(0, 3, by = 1 / fs)
  lean <- pmin(t / 1.5, 1) * 5
  cop <- data.frame(cop_x = 2 * sin(2 * pi * 2 * t), cop_y = lean)
  res <- limitsOfStability(cop, sampling_rate = fs, target = 0)
  expect_true(res$directional_control < 100)
  expect_true(res$directional_control > 0)
})

test_that("LOS accepts a direction vector target", {
  fs <- 100
  t <- seq(0, 2, by = 1 / fs)
  # lean toward (ap=1, ml=1) diagonal
  amp <- pmin(t / 1, 1) * 4
  cop <- data.frame(cop_x = amp / sqrt(2), cop_y = amp / sqrt(2))
  res <- limitsOfStability(cop, sampling_rate = fs, target = c(1, 1))
  expect_equal(res$max_excursion, 4, tolerance = 1e-6)
  expect_equal(res$directional_control, 100, tolerance = 1e-6)
})

# ---- stabilogram diffusion --------------------------------------------------

test_that("stabilogramDiffusion recovers positive short-term diffusion on a random walk", {
  set.seed(21)
  n <- 4000
  cop <- data.frame(cop_x = cumsum(rnorm(n)) * 0.05,
                    cop_y = cumsum(rnorm(n)) * 0.05)
  res <- stabilogramDiffusion(cop, sampling_rate = 100)
  expect_s3_class(res, "stabilogram_diffusion")
  expect_true(res$planar$d_short > 0)
  expect_true(is.finite(res$ap$d_short))
  expect_equal(length(res$intervals), length(res$msd_planar))
})

# ---- print methods ----------------------------------------------------------

test_that("print methods run without error", {
  cir <- make_circle(dur = 10)
  sm <- swayMetrics(cbind(ml = cir$ml, ap = cir$ap), sampling_rate = cir$fs)
  expect_output(print(sm), "sway_metrics")
  sot <- sensoryOrganizationTest(matrix(90, 6, 3))
  expect_output(print(sot), "sot_result")
  mc <- mCTSIB(eyes_open_firm = c(0.4, 0.5))
  expect_output(print(mc), "mctsib_result")
  los <- limitsOfStability(data.frame(cop_x = 0:10, cop_y = 0:10),
                           sampling_rate = 10, target = 45)
  expect_output(print(los), "los_result")
})
