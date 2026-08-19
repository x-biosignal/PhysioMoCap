library(testthat)

test_that("RFD intervals and peak torque are exact on a linear ramp", {
  sr <- 1000
  slope <- 400
  baseline <- rep(0, 100)
  ramp <- slope * (seq_len(300) / sr)
  plateau <- rep(slope * 300 / sr, 200)
  torque <- c(baseline, ramp, plateau)

  peak <- peakTorque(torque, sampling_rate = sr, mode = "isometric")
  expect_s3_class(peak, "peak_torque")
  expect_equal(peak$peak, 120, tolerance = 1e-9)
  expect_equal(peak$peak_index, 400L)

  rfd <- rateOfForceDevelopment(
    torque, sampling_rate = sr, onset_method = "sd",
    windows_ms = c(50, 100, 200), peak_window_ms = 20
  )
  expect_s3_class(rfd, "rfd")
  expect_equal(rfd$onset_index, 101L)
  expect_equal(rfd$windows$rfd, c(400, 400, 400), tolerance = 4)
  expect_equal(rfd$peak_rfd, 400, tolerance = 4)

  tpt <- timeToPeakTorque(
    torque, sampling_rate = sr, onset_method = "sd"
  )
  expect_equal(tpt$peak_index, 400L)
  expect_equal(tpt$time_from_onset, 0.299, tolerance = 1e-9)
  expect_equal(tpt$time_from_start, 0.399, tolerance = 1e-9)
})


test_that("peak RFD distinguishes a quadratic ramp from interval RFD", {
  sr <- 1000
  acceleration <- 4000
  duration <- 0.200
  baseline <- rep(0, 100)
  time <- seq_len(round(duration * sr)) / sr
  torque <- c(baseline, 0.5 * acceleration * time^2)

  rfd <- rateOfForceDevelopment(
    torque, sampling_rate = sr, onset = 100L,
    windows_ms = 50, peak_window_ms = 20
  )
  expect_equal(rfd$windows$rfd[1L], 0.025 * acceleration,
               tolerance = 1e-6)
  expect_equal(rfd$peak_rfd,
               acceleration * (duration - 0.020 / 2),
               tolerance = 1e-6)
  expect_equal(rfd$peak_rfd_time, 0.289, tolerance = 1e-12)
})


test_that("isokinetic peak search excludes velocity transients", {
  torque <- c(200, 20, 40, 80, 60, 190)
  velocity <- c(20, 100, 99, 101, 100, 30)
  angle <- c(0, 10, 20, 30, 40, 50)

  peak <- peakTorque(
    torque, sampling_rate = 100, mode = "isokinetic",
    angle = angle, angular_velocity = velocity,
    target_velocity = 100, velocity_tol = 0.02,
    at_angle = c(15, 35), gravity = 5
  )

  expect_equal(peak$window, 2:5)
  expect_equal(peak$peak, 75)
  expect_equal(peak$peak_index, 4L)
  expect_equal(peak$peak_angle, 30)
  expect_equal(unname(peak$angle_specific), c(25, 65))
})


test_that("peak torque handles reversed angle limbs and clamped angles", {
  angle <- c(40, 30, 20, 10, 0)
  torque <- c(80, 60, 40, 20, 0)
  expect_warning(
    peak <- peakTorque(
      torque, 100, mode = "isometric", angle = angle,
      at_angle = c(-5, 25, 45)
    ),
    "clamped"
  )
  expect_equal(unname(peak$angle_specific), c(0, 50, 80))
})


test_that("RFD marks unavailable intervals and short peak windows", {
  torque <- c(0, 1, 2)
  expect_warning(
    rfd <- rateOfForceDevelopment(
      torque, sampling_rate = 100, onset = 2L,
      windows_ms = c(10, 50), peak_window_ms = 50
    ),
    "too short"
  )
  expect_equal(rfd$windows$rfd[1L], 100)
  expect_true(is.na(rfd$windows$rfd[2L]))
  expect_true(is.na(rfd$peak_rfd))
})


test_that("angular impulse matches the closed-form triangle area", {
  sr <- 1000
  up <- seq(0, 120, length.out = 301)
  down <- seq(120, 0, length.out = 301)[-1L]
  torque <- c(up, down)
  work <- contractionWork(
    torque, sampling_rate = sr,
    reps = list(rep1 = seq_along(torque))
  )

  expect_s3_class(work, "contraction_work")
  expect_equal(work$angular_impulse[1L], 36, tolerance = 36e-6)
  expect_true(is.na(work$work[1L]))
  expect_equal(attr(work, "sampling_rate"), sr)
})


test_that("angle and velocity work match a constant-torque identity", {
  sr <- 100
  torque <- rep(10, 101)
  angle <- seq(0, 90, length.out = 101)
  velocity <- rep(90, 101)
  reps <- list(rep1 = seq_along(torque))

  by_angle <- contractionWork(
    torque, sr, angle = angle, reps = reps, body_mass = 50
  )
  by_velocity <- contractionWork(
    torque, sr, angular_velocity = velocity, reps = reps
  )
  expected_work <- 10 * pi / 2

  expect_equal(by_angle$work, expected_work, tolerance = 1e-12)
  expect_equal(by_velocity$work, expected_work, tolerance = 1e-12)
  expect_equal(by_angle$angular_impulse, 10, tolerance = 1e-12)
  expect_equal(by_angle$work_per_kg, expected_work / 50, tolerance = 1e-12)
  expect_equal(by_angle$angular_impulse_per_kg, 0.2, tolerance = 1e-12)
})


test_that("work integration respects gaps in a strictly increasing rep", {
  torque <- rep(10, 101)
  angle <- seq(0, 90, length.out = 101)
  velocity <- rep(90, 101)
  reps <- list(sparse = seq(1, 101, by = 10))

  by_angle <- contractionWork(torque, 100, angle = angle, reps = reps)
  by_velocity <- contractionWork(
    torque, 100, angular_velocity = velocity, reps = reps
  )

  expect_equal(by_angle$angular_impulse, 10, tolerance = 1e-12)
  expect_equal(by_angle$work, 10 * pi / 2, tolerance = 1e-12)
  expect_equal(by_velocity$work, 10 * pi / 2, tolerance = 1e-12)
})


test_that("automatic repetition segmentation reuses impulse contacts", {
  torque <- c(rep(0, 10), rep(20, 20), rep(0, 10),
              rep(30, 20), rep(0, 10))
  work <- contractionWork(torque, sampling_rate = 100, onset_threshold = 7.5)

  expect_equal(work$rep, c("rep1", "rep2"))
  expect_equal(work$onset_index, c(11L, 41L))
  expect_equal(work$offset_index, c(30L, 60L))
})


test_that("H:Q conventional and functional ratios are exact", {
  extension <- hamstringQuadRatio(
    quad_con = 200, ham_con = 120, ham_ecc = 150, quad_ecc = 220,
    movement = "extension"
  )
  flexion <- hamstringQuadRatio(
    quad_con = 200, ham_con = 120, ham_ecc = 150, quad_ecc = 220,
    movement = "flexion"
  )

  expect_s3_class(extension, "hq_ratio")
  expect_equal(extension$conventional, 0.60, tolerance = 1e-9)
  expect_equal(extension$functional, 0.75, tolerance = 1e-9)
  expect_equal(flexion$functional, 120 / 220, tolerance = 1e-9)
  expect_true(is.na(hamstringQuadRatio(200, 120)$functional))
  expect_equal(extension$peaks,
               c(quad_con = 200, ham_con = 120,
                 ham_ecc = 150, quad_ecc = 220))
})


test_that("EMG-normalised H:Q preserves an amplitude ratio", {
  base <- sin(2 * pi * 100 * (seq_len(2000) - 1) / 1000)
  result <- hamstringQuadRatio(
    200, 120, emg_ham = 40 * base, emg_quad = 80 * base,
    emg_sampling_rate = 1000
  )
  expect_equal(result$emg_ratio, 0.5, tolerance = 1e-6)
})


test_that("dynamometry inputs reject ambiguous or non-finite values", {
  expect_error(peakTorque(c(1, NA), 100), "finite")
  expect_error(peakTorque(1:3, 100, at_angle = 1), "angle must be supplied")
  expect_error(
    peakTorque(1:3, 100, angular_velocity = 1:2),
    "same length"
  )
  expect_error(
    rateOfForceDevelopment(1:3, 100, onset = 1.5),
    "integer sample"
  )
  expect_error(
    contractionWork(1:3, 100, reps = list(rep1 = c(1, 3, 2))),
    "strictly increasing"
  )
  expect_error(hamstringQuadRatio(0, 1), "must be positive")
  expect_error(
    hamstringQuadRatio(2, 1, emg_ham = 1:100),
    "supplied together"
  )
})


test_that("dynamometry print methods report their classes", {
  peak <- peakTorque(1:10, 100, mode = "isometric")
  rfd <- rateOfForceDevelopment(0:10, 100, onset = 1L, windows_ms = 10)
  work <- contractionWork(1:10, 100, reps = list(rep1 = 1:10))
  ratio <- hamstringQuadRatio(2, 1)

  expect_output(print(peak), "peak_torque")
  expect_output(print(rfd), "<rfd>")
  expect_output(print(work), "contraction_work")
  expect_output(print(ratio), "hq_ratio")
})
