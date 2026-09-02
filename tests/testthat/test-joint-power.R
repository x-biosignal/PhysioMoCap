test_that("computeJointPower(split=TRUE) partitions generation and absorption", {
  moment <- c(10, -12, 8, 0)
  omega <- c(2, 1.5, -1, 5)
  sp <- computeJointPower(moment, omega, split = TRUE)

  expect_s3_class(sp, "data.frame")
  expect_named(sp, c("power", "generation", "absorption"))
  expect_equal(sp$power, moment * omega)
  # generation is the non-negative part, absorption the non-positive part
  expect_equal(sp$generation, pmax(moment * omega, 0))
  expect_equal(sp$absorption, pmin(moment * omega, 0))
  # exact reconstruction
  expect_equal(sp$generation + sp$absorption, sp$power)
})

test_that("computeJointPower stays backward compatible and validates split", {
  expect_type(computeJointPower(c(1, 2), c(3, 4)), "double")
  expect_equal(computeJointPower(c(1, 2), c(3, 4)), c(3, 8))
  expect_error(computeJointPower(1, 2, split = NA), "single TRUE or FALSE")
  expect_error(computeJointPower(1, 2, split = c(TRUE, FALSE)), "single TRUE or FALSE")
})

test_that("computeJointPower preserves NA in the split", {
  sp <- computeJointPower(c(1, NA, 3), c(2, 3, -1), split = TRUE)
  expect_true(is.na(sp$power[2]))
  expect_true(is.na(sp$generation[2]))
  expect_true(is.na(sp$absorption[2]))
})

test_that("jointWork obeys the net-work identity to 1e-8", {
  t <- seq(0, 1, length.out = 101)
  power <- 100 * sin(2 * pi * t)
  jw <- jointWork(power, sampling_rate = 100)

  expect_s3_class(jw, "joint_work")
  # concentric (>0) + eccentric (<0) == net integrated work
  expect_equal(jw$concentric_work + jw$eccentric_work, jw$net_work,
               tolerance = 1e-8)
  # a full sine over one period integrates to ~zero net work
  expect_lt(abs(jw$net_work), 1e-8)
  expect_gt(jw$concentric_work, 0)
  expect_lt(jw$eccentric_work, 0)
})

test_that("jointWork matches an analytic trapezoidal reference", {
  # linear ramp of power: 0 W -> 100 W over 1 s at 1000 Hz
  fs <- 1000
  power <- seq(0, 100, length.out = fs + 1)
  jw <- jointWork(power, sampling_rate = fs)
  # trapezoidal integral of a straight line is exact = area of triangle = 50 J
  expect_equal(jw$concentric_work, 50, tolerance = 1e-9)
  expect_equal(jw$eccentric_work, 0)
  expect_equal(jw$net_work, 50, tolerance = 1e-9)
})

test_that("jointWork per-kg normalisation divides by body mass", {
  t <- seq(0, 1, length.out = 101)
  jw <- jointWork(100 * sin(2 * pi * t), sampling_rate = 100, body_mass = 70)
  expect_true(all(c("concentric_work_per_kg", "eccentric_work_per_kg",
                    "net_work_per_kg") %in% names(jw)))
  expect_equal(jw$concentric_work_per_kg, jw$concentric_work / 70)
})

test_that("jointWork splits work across gait cycles / phases", {
  t <- seq(0, 1, length.out = 101)
  power <- 100 * sin(2 * pi * t)      # +ve first half, -ve second half
  jw <- jointWork(power, sampling_rate = 100,
                  windows = list(stance = 1:51, swing = 51:101))
  expect_equal(nrow(jw), 2)
  expect_equal(jw$window, c("stance", "swing"))
  # stance is generation-only, swing is absorption-only
  expect_gt(jw$concentric_work[1], 0)
  expect_lt(abs(jw$eccentric_work[1]), 1e-8)
  expect_lt(jw$eccentric_work[2], 0)
  expect_lt(abs(jw$concentric_work[2]), 1e-8)
  # identity holds per window
  expect_equal(jw$concentric_work + jw$eccentric_work, jw$net_work,
               tolerance = 1e-8)
})

test_that("jointWork validates its arguments", {
  expect_error(jointWork(1:10, sampling_rate = 0), "positive")
  expect_error(jointWork(1:10, sampling_rate = 100, body_mass = -1), "positive")
  expect_error(jointWork(1:10, sampling_rate = 100,
                         windows = list(1:3)), "named list")
  expect_error(jointWork(1:10, sampling_rate = 100,
                         windows = list(a = c(1, 99))), "out-of-range")
})

test_that("labelPowerBursts assigns ankle A1 (absorption) then A2 (push-off)", {
  t <- seq(0, 1, length.out = 101)
  # controlled lowering (negative) then push-off generation (positive)
  ankle <- ifelse(t < 0.4, -50 * sin(pi * t / 0.4),
                  120 * sin(pi * (t - 0.4) / 0.2) * (t < 0.6))
  pb <- labelPowerBursts(ankle, sampling_rate = 100, joint = "ankle")

  expect_s3_class(pb, "power_bursts")
  a1 <- pb[!is.na(pb$label) & pb$label == "A1", ]
  a2 <- pb[!is.na(pb$label) & pb$label == "A2", ]
  expect_equal(nrow(a1), 1)
  expect_equal(nrow(a2), 1)
  # A2 push-off is positive generation; A1 controlled-lowering is negative
  expect_gt(a2$peak_power, 0)
  expect_equal(a2$type, "generation")
  expect_lt(a1$peak_power, 0)
  expect_equal(a1$type, "absorption")
  # A1 precedes A2 in the cycle
  expect_lt(a1$start_pct, a2$start_pct)
})

test_that("labelPowerBursts labels hip H1-H3 and knee K1-K4 by sign and timing", {
  t <- seq(0, 1, length.out = 101)
  hip <- ifelse(t < 0.2, 40 * sin(pi * t / 0.2),
         ifelse(t < 0.5, -30 * sin(pi * (t - 0.2) / 0.3),
         ifelse(t < 0.75, 60 * sin(pi * (t - 0.5) / 0.25), 0)))
  hp <- labelPowerBursts(hip, sampling_rate = 100, joint = "hip")
  expect_equal(hp$label, c("H1", "H2", "H3"))
  expect_equal(hp$type, c("generation", "absorption", "generation"))

  knee <- ifelse(t < 0.15, -25 * sin(pi * t / 0.15),
          ifelse(t < 0.3, 15 * sin(pi * (t - 0.15) / 0.15),
          ifelse(t < 0.5, -20 * sin(pi * (t - 0.3) / 0.2),
          ifelse(t > 0.7 & t < 1, -30 * sin(pi * (t - 0.7) / 0.3), 0))))
  kp <- labelPowerBursts(knee, sampling_rate = 100, joint = "knee")
  expect_equal(kp$label, c("K1", "K2", "K3", "K4"))
  expect_equal(kp$type, c("absorption", "generation", "absorption", "absorption"))
})

test_that("labelPowerBursts burst work sums to jointWork totals", {
  t <- seq(0, 1, length.out = 101)
  ankle <- ifelse(t < 0.4, -50 * sin(pi * t / 0.4),
                  120 * sin(pi * (t - 0.4) / 0.2) * (t < 0.6))
  pb <- labelPowerBursts(ankle, sampling_rate = 100, joint = "ankle",
                         body_mass = 70)
  jw <- jointWork(ankle, sampling_rate = 100)
  # sum of positive-burst work == concentric; negative-burst work == eccentric
  gen <- sum(pb$work[pb$type == "generation"])
  abso <- sum(pb$work[pb$type == "absorption"])
  expect_equal(gen, jw$concentric_work, tolerance = 1e-8)
  expect_equal(abso, jw$eccentric_work, tolerance = 1e-8)
  expect_true("work_per_kg" %in% names(pb))
})

# --- regression tests for adversarial-review findings (WS4-04) ---

test_that("labelPowerBursts returns an empty table (no crash) for no-burst power", {
  # all-zero (joint held still), single zero, all-NA -> zero detected bursts
  for (p in list(rep(0, 10), 0, as.numeric(c(NA, NA, NA)))) {
    pb <- suppressWarnings(labelPowerBursts(p, sampling_rate = 1, joint = "ankle",
                                            body_mass = 70))
    expect_s3_class(pb, "power_bursts")
    expect_equal(nrow(pb), 0)
    expect_true(all(c("label", "joint", "type", "start_pct", "end_pct",
                      "peak_power", "work", "work_per_kg") %in% names(pb)))
  }
})

test_that("labelPowerBursts warns on NA in power", {
  expect_warning(labelPowerBursts(c(1, 2, NA, 3, 4), sampling_rate = 1,
                                  joint = "ankle"), "NA")
})

test_that("jointWork warns on NA and rejects duplicated/unsorted window indices", {
  expect_warning(jointWork(c(1, 2, NA, 4), sampling_rate = 1), "NA")
  expect_error(jointWork(c(10, 20, 30, 40), sampling_rate = 1,
                         windows = list(w = c(1, 1, 2))),
               "increasing and unique")
  expect_error(jointWork(c(10, 20, 30, 40), sampling_rate = 1,
                         windows = list(w = c(3, 1, 2))),
               "increasing and unique")
  # adjacent windows sharing a boundary index are allowed (different windows)
  expect_silent(jointWork(1:10, sampling_rate = 1,
                          windows = list(a = 1:5, b = 5:10)))
})

test_that("burst labelling uses the true cycle length, not the burst span", {
  # activity concentrated late in the cycle: a lone ankle push-off at ~50-60%.
  # With span-relative normalisation this would look like it fills the cycle and
  # could be mislabelled; with true-cycle fraction it is correctly A2 (~0.50).
  t <- seq(0, 1, length.out = 101)
  ankle <- ifelse(t >= 0.4 & t < 0.6, 120 * sin(pi * (t - 0.4) / 0.2), 0)
  pb <- labelPowerBursts(ankle, sampling_rate = 100, joint = "ankle")
  expect_equal(nrow(pb), 1)
  expect_equal(pb$label, "A2")
  expect_equal(pb$type, "generation")
})

test_that("a lone late knee absorption burst is labelled K4, not K1", {
  # terminal-swing hamstring absorption only (no early K1/K2/K3 bursts).
  t <- seq(0, 1, length.out = 101)
  knee <- ifelse(t > 0.75, -30 * sin(pi * (t - 0.75) / 0.25), 0)
  pb <- labelPowerBursts(knee, sampling_rate = 100, joint = "knee")
  expect_equal(nrow(pb), 1)
  expect_equal(pb$label, "K4")
  expect_equal(pb$type, "absorption")
})
