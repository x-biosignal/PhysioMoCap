# Quantitative ataxia metrics.

test_that("pathStraightness is 1 for a straight path and < 1 for a curved one", {
  straight <- pathStraightness(cbind(c(0, 1, 2, 3), c(0, 0, 0, 0)))
  expect_equal(straight$straightness, 1)
  expect_equal(straight$index_of_curvature, 1)

  lpath <- pathStraightness(cbind(c(0, 0, 1), c(0, 1, 1)))   # right-angle path
  expect_equal(lpath$path_length, 2)
  expect_equal(lpath$direct_distance, sqrt(2))
  expect_equal(lpath$straightness, sqrt(2) / 2)
  expect_equal(lpath$index_of_curvature, sqrt(2))

  expect_error(pathStraightness(matrix(1, nrow = 1)), "at least two")
})

test_that("limbAtaxiaIndex reports sub-metrics and a reference-based composite", {
  noref <- limbAtaxiaIndex(dysmetria = 3, decomposition = 5)
  expect_s3_class(noref, "limb_ataxia")
  expect_true(is.na(noref$composite))                       # no reference -> NA
  expect_equal(unname(noref$metrics[["dysmetria"]]), 3)

  ref <- data.frame(
    dysmetria     = c(1.0, 1.2, 0.8, 1.1, 0.9),
    decomposition = c(1,   1,   2,   1,   1),
    smoothness    = c(1.5, 1.6, 1.4, 1.5, 1.5),
    irregularity  = c(1.02, 1.01, 1.03, 1.02, 1.00))
  # a clearly-worse-than-healthy case scores well above 0
  worse <- limbAtaxiaIndex(dysmetria = 3, decomposition = 5, smoothness = 4,
                           irregularity = 1.5, reference = ref)
  expect_gt(worse$composite, 1)
  # a case at the reference mean scores ~0
  mid <- limbAtaxiaIndex(dysmetria = mean(ref$dysmetria),
                         decomposition = mean(ref$decomposition),
                         smoothness = mean(ref$smoothness),
                         irregularity = mean(ref$irregularity), reference = ref)
  expect_lt(abs(mid$composite), 1e-8)
})

test_that("gaitAtaxiaIndex combines gait-variability sub-metrics", {
  g <- gaitAtaxiaIndex(step_width_cv = 28, stride_length_cv = 9,
                       stride_time_cv = 6)
  expect_s3_class(g, "gait_ataxia")
  expect_true(is.na(g$composite))
  expect_equal(unname(g$metrics[["step_width_cv"]]), 28)

  ref <- data.frame(step_width_cv = c(8, 10, 9, 11, 7),
                    stride_length_cv = c(3, 4, 3, 5, 4),
                    stride_time_cv = c(2, 3, 2, 3, 2))
  worse <- gaitAtaxiaIndex(step_width_cv = 30, stride_length_cv = 12,
                           stride_time_cv = 8, reference = ref)
  expect_gt(worse$composite, 1)
})
