library(testthat)
library(PhysioMoCap)


test_that("demoMoCapData returns beginner demo bundle", {
  d <- demoMoCapData(n_frames = 240, sampling_rate = 120,
                     n_markers = 8, emg_sampling_rate = 1000, seed = 1)

  expect_true(is.list(d))
  expect_true(all(c("mocap", "grf", "forces", "joints", "joint_angles", "emg",
                    "sampling_rate", "emg_sampling_rate") %in% names(d)))

  expect_s4_class(d$mocap, "PhysioExperiment")
  expect_true(is.numeric(d$grf))
  expect_equal(length(d$grf), 240)
  expect_true(is.matrix(d$forces))
  expect_equal(nrow(d$forces), 240)
  expect_true(all(c("force_x", "force_y", "force_z") %in% colnames(d$forces)))

  expect_s3_class(d$joints, "data.frame")
  expect_true(all(c("ankle_x", "ankle_y", "knee_x", "knee_y", "hip_x", "hip_y") %in%
                    names(d$joints)))

  expect_s3_class(d$joint_angles, "data.frame")
  expect_true(all(c("ankle", "knee", "hip") %in% names(d$joint_angles)))

  expect_true(is.matrix(d$emg))
  expect_equal(ncol(d$emg), 4)
})


test_that("readMoCapAuto detects TRC and CSV formats", {
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if_not(nzchar(trc_file), "sample.trc not available")

  pe_trc <- readMoCapAuto(trc_file)
  expect_s4_class(pe_trc, "PhysioExperiment")
  expect_true(all(c("position_x", "position_y", "position_z") %in%
                    SummarizedExperiment::assayNames(pe_trc)))

  tmp <- tempfile(fileext = ".csv")
  write.csv(
    data.frame(
      Time = seq(0, 0.09, by = 0.01),
      Hip_x = seq(0, 0.9, by = 0.1),
      Hip_y = seq(1, 1.9, by = 0.1),
      Hip_z = seq(2, 2.9, by = 0.1)
    ),
    tmp,
    row.names = FALSE
  )

  pe_csv <- readMoCapAuto(tmp)
  expect_s4_class(pe_csv, "PhysioExperiment")
  expect_true(all(c("position_x", "position_y", "position_z") %in%
                    SummarizedExperiment::assayNames(pe_csv)))
})


test_that("assessMoCapReadiness returns score/check structure", {
  demo <- demoMoCapData(seed = 10)
  rep <- assessMoCapReadiness(demo$mocap)

  expect_s3_class(rep, "mocap_readiness")
  expect_true(is.numeric(rep$score))
  expect_true(rep$score >= 0 && rep$score <= 100)
  expect_s3_class(rep$checks, "data.frame")
  expect_true(all(c("category", "check", "pass", "value", "recommendation") %in%
                    names(rep$checks)))

  expect_invisible(print(rep))
})


test_that("quickStartMoCap runs demo end-to-end and returns expected outputs", {
  qs <- quickStartMoCap(n_frames = 200, sampling_rate = 100,
                        emg_sampling_rate = 1000, seed = 2)

  expect_s3_class(qs, "mocap_quickstart")
  expect_true(all(c("source", "data", "readiness", "velocity", "acceleration",
                    "forceplate", "inverse_dynamics", "emg", "notes") %in% names(qs)))

  expect_equal(qs$source, "demo")
  expect_s3_class(qs$readiness, "mocap_readiness")
  expect_s4_class(qs$velocity, "PhysioExperiment")
  expect_s4_class(qs$acceleration, "PhysioExperiment")
  expect_s3_class(qs$forceplate, "forceplate_analysis")
  expect_s3_class(qs$inverse_dynamics, "data.frame")

  expect_true(is.list(qs$emg))
  expect_true(all(c("processed", "aligned") %in% names(qs$emg)))
  expect_true(is.matrix(qs$emg$aligned))

  expect_true(is.data.frame(qs$forceplate$summary))
  expect_true("peak_vertical_force" %in% names(qs$forceplate$summary))
})


test_that("quickStartMoCap supports object input and reports skipped modules", {
  demo <- demoMoCapData(seed = 4)
  qs <- quickStartMoCap(
    mocap = demo$mocap,
    sampling_rate = demo$sampling_rate,
    forces = NULL,
    joints = NULL,
    joint_angles = NULL,
    emg = NULL
  )

  expect_s3_class(qs, "mocap_quickstart")
  expect_equal(qs$source, "object")
  expect_s4_class(qs$velocity, "PhysioExperiment")
  expect_s4_class(qs$acceleration, "PhysioExperiment")
  expect_null(qs$forceplate)
  expect_null(qs$inverse_dynamics)
  expect_null(qs$emg$processed)
  expect_true(length(qs$notes) >= 1)
})


test_that("quickStartMoCap supports path input", {
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if_not(nzchar(trc_file), "sample.trc not available")

  qs <- quickStartMoCap(path = trc_file)
  expect_s3_class(qs, "mocap_quickstart")
  expect_match(qs$source, "^file:")
  expect_s3_class(qs$readiness, "mocap_readiness")
})


test_that("print.mocap_quickstart prints without error", {
  qs <- quickStartMoCap(seed = 3)
  expect_invisible(print(qs))
})
