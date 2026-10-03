library(testthat)
library(PhysioMoCap)

# ==============================================================================
# vis-biomech.R tests
# ==============================================================================

test_that("plotGaitCycle creates ggplot from matrix", {
  skip_if_not_installed("ggplot2")
  data <- sapply(1:5, function(i) {
    sin(seq(0, 2 * pi, length.out = 101)) * 30 + rnorm(101, 0, 2)
  })
  p <- plotGaitCycle(data)
  expect_s3_class(p, "ggplot")
})

test_that("plotGaitCycle creates ggplot from list of variable-length trials", {
  skip_if_not_installed("ggplot2")
  trials <- lapply(1:5, function(i) {
    n <- sample(90:110, 1)
    sin(seq(0, 2 * pi, length.out = n)) * 60 + rnorm(n, 0, 3)
  })
  p <- plotGaitCycle(trials, show_mean = TRUE, show_sd = TRUE,
                     ylab = "Knee Flexion (deg)")
  expect_s3_class(p, "ggplot")
})

test_that("plotGaitCycle respects show_individual and show_events flags", {
  skip_if_not_installed("ggplot2")
  data <- sapply(1:3, function(i) rnorm(101))
  p1 <- plotGaitCycle(data, show_individual = FALSE, show_events = FALSE)
  p2 <- plotGaitCycle(data, show_individual = TRUE, show_events = TRUE)
  expect_s3_class(p1, "ggplot")
  expect_s3_class(p2, "ggplot")
})

test_that("plotWaveformComparison creates ggplot with groups", {
  skip_if_not_installed("ggplot2")
  control <- sapply(1:10, function(i) sin(seq(0, 2 * pi, length.out = 101)) * 30 + rnorm(101, 0, 3))
  patient <- sapply(1:10, function(i) sin(seq(0, 2 * pi, length.out = 101)) * 20 + rnorm(101, 0, 3))
  data <- cbind(control, patient)
  groups <- factor(rep(c("Control", "Patient"), each = 10))

  p <- plotWaveformComparison(data, groups, time_axis = 0:100,
                               xlab = "Gait Cycle (%)", ylab = "Knee Angle (deg)")
  expect_s3_class(p, "ggplot")
})

test_that("plotWaveformComparison works with show_individual", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 6), nrow = 101)
  groups <- factor(rep(c("A", "B"), each = 3))
  p <- plotWaveformComparison(data, groups, show_individual = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("plotWaveformComparison validates group length", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 6), nrow = 101)
  groups <- factor(c("A", "B"))  # Wrong length
  expect_error(plotWaveformComparison(data, groups),
               "Length of groups must match")
})

test_that("plotSymmetry creates overlay ggplot", {
  skip_if_not_installed("ggplot2")
  left <- matrix(rnorm(101 * 5), nrow = 101)
  right <- matrix(rnorm(101 * 5), nrow = 101)
  p <- plotSymmetry(left, right, plot_type = "overlay")
  expect_s3_class(p, "ggplot")
})

test_that("plotSymmetry creates scatter ggplot", {
  skip_if_not_installed("ggplot2")
  left <- matrix(rnorm(101 * 5), nrow = 101)
  right <- matrix(rnorm(101 * 5), nrow = 101)
  p <- plotSymmetry(left, right, plot_type = "scatter")
  expect_s3_class(p, "ggplot")
})

test_that("plotSymmetry errors on mismatched dimensions", {
  skip_if_not_installed("ggplot2")
  left <- matrix(rnorm(101 * 5), nrow = 101)
  right <- matrix(rnorm(50 * 5), nrow = 50)
  expect_error(plotSymmetry(left, right),
               "same number of time points")
})

test_that("plotPhasePortrait creates ggplot from vector", {
  skip_if_not_installed("ggplot2")
  t <- seq(0, 2 * pi, length.out = 100)
  angle <- sin(t) * 60
  velocity <- cos(t) * 60 * (2 * pi / 100)
  p <- plotPhasePortrait(angle, velocity)
  expect_s3_class(p, "ggplot")
})

test_that("plotPhasePortrait computes velocity when not provided", {
  skip_if_not_installed("ggplot2")
  t <- seq(0, 2 * pi, length.out = 100)
  angle <- sin(t) * 60
  p <- plotPhasePortrait(angle, sampling_rate = 100)
  expect_s3_class(p, "ggplot")
})

test_that("plotPhasePortrait works with matrix input and groups", {
  skip_if_not_installed("ggplot2")
  angle <- matrix(rnorm(100 * 4), nrow = 100)
  groups <- c("A", "A", "B", "B")
  p <- plotPhasePortrait(angle, groups = groups, normalize = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("plotEffectSizeForest creates ggplot", {
  skip_if_not_installed("ggplot2")
  effects <- c(Hip = 0.8, Knee = 1.2, Ankle = 0.3)
  ci_lower <- c(0.4, 0.8, -0.1)
  ci_upper <- c(1.2, 1.6, 0.7)
  p <- plotEffectSizeForest(effects, ci_lower, ci_upper)
  expect_s3_class(p, "ggplot")
})

test_that("plotEffectSizeForest supports sorting", {
  skip_if_not_installed("ggplot2")
  effects <- c(Hip = 0.8, Knee = 1.2, Ankle = 0.3)
  ci_lower <- c(0.4, 0.8, -0.1)
  ci_upper <- c(1.2, 1.6, 0.7)
  p1 <- plotEffectSizeForest(effects, ci_lower, ci_upper, sort_by = "effect")
  p2 <- plotEffectSizeForest(effects, ci_lower, ci_upper, sort_by = "name")
  expect_s3_class(p1, "ggplot")
  expect_s3_class(p2, "ggplot")
})

test_that("plotCorrelationMatrix creates ggplot from data.frame", {
  skip_if_not_installed("ggplot2")
  data <- data.frame(
    Hip = rnorm(100),
    Knee = rnorm(100),
    Ankle = rnorm(100)
  )
  data$Knee <- data$Hip * 0.7 + rnorm(100, 0, 0.5)
  p <- plotCorrelationMatrix(data)
  expect_s3_class(p, "ggplot")
})

test_that("plotCorrelationMatrix works with pre-computed correlation matrix", {
  skip_if_not_installed("ggplot2")
  cor_mat <- matrix(c(1, 0.7, 0.3, 0.7, 1, 0.5, 0.3, 0.5, 1), nrow = 3)
  rownames(cor_mat) <- colnames(cor_mat) <- c("Hip", "Knee", "Ankle")
  p <- plotCorrelationMatrix(cor_mat, cluster = FALSE, show_values = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("plotSpaghetti creates ggplot from matrix", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 10), nrow = 101)
  p <- plotSpaghetti(data, highlight_mean = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("plotSpaghetti works without mean highlight", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 5), nrow = 101)
  p <- plotSpaghetti(data, highlight_mean = FALSE, title = "Test Plot")
  expect_s3_class(p, "ggplot")
})

# ==============================================================================
# vis-movement.R tests
# ==============================================================================

test_that("plotCycle creates ggplot with schema", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 10), nrow = 101)
  p <- plotCycle(data, schema = schema_gait)
  expect_s3_class(p, "ggplot")
})

test_that("plotCycle creates ggplot without schema", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 10), nrow = 101)
  p <- plotCycle(data)
  expect_s3_class(p, "ggplot")
})

test_that("plotCycle works with show_individual and show_ci", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 5), nrow = 101)
  p <- plotCycle(data, show_individual = TRUE, show_ci = TRUE, show_sd = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("plotCycle works with vector input", {
  skip_if_not_installed("ggplot2")
  data <- rnorm(101)
  p <- plotCycle(data, show_sd = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("plotGroupComparison creates ggplot", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 20), nrow = 101)
  groups <- factor(rep(c("Control", "Patient"), each = 10))
  p <- plotGroupComparison(data, groups, schema = schema_gait)
  expect_s3_class(p, "ggplot")
})

test_that("plotGroupComparison validates group length", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 10), nrow = 101)
  groups <- factor(c("A", "B"))
  expect_error(plotGroupComparison(data, groups),
               "groups length must match")
})

test_that("plotGroupComparison works with show_individual", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 6), nrow = 101)
  groups <- factor(rep(c("A", "B"), each = 3))
  p <- plotGroupComparison(data, groups, show_individual = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("plotTrajectory creates ggplot", {
  skip_if_not_installed("ggplot2")
  t <- seq(0, 2 * pi, length.out = 200)
  x_pos <- sin(t) + rnorm(200, 0, 0.1)
  y_pos <- cos(t) + rnorm(200, 0, 0.1)
  p <- plotTrajectory(x_pos, y_pos, title = "Balance CoP")
  expect_s3_class(p, "ggplot")
})

test_that("plotTrajectory works with balance schema defaults", {
  skip_if_not_installed("ggplot2")
  x_pos <- rnorm(100)
  y_pos <- rnorm(100)
  p <- plotTrajectory(x_pos, y_pos, schema = schema_balance)
  expect_s3_class(p, "ggplot")
})

test_that("plotTrajectory validates matching x and y lengths", {
  skip_if_not_installed("ggplot2")
  expect_error(plotTrajectory(1:10, 1:5),
               "x and y must have the same length")
})

test_that("plotTrajectory respects show_path and show_points options", {
  skip_if_not_installed("ggplot2")
  x_pos <- rnorm(50)
  y_pos <- rnorm(50)
  p <- plotTrajectory(x_pos, y_pos, show_path = FALSE, show_points = TRUE,
                       show_ellipse = FALSE, show_start_end = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("plotMultiPanel creates faceted ggplot", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 4), nrow = 101)
  colnames(data) <- c("Hip", "Knee", "Ankle", "Pelvis")
  p <- plotMultiPanel(data, channels = 1:3)
  expect_s3_class(p, "ggplot")
})

test_that("plotMultiPanel uses schema defaults", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 4), nrow = 101)
  colnames(data) <- c("Hip", "Knee", "Ankle", "Pelvis")
  p <- plotMultiPanel(data, schema = schema_gait, channels = c("Hip", "Knee"))
  expect_s3_class(p, "ggplot")
})

test_that(".extractPlotData handles matrix input", {
  skip_if_not_installed("ggplot2")
  data <- matrix(rnorm(101 * 5), nrow = 101)
  result <- PhysioMoCap:::.extractPlotData(data)
  expect_true(is.matrix(result))
  expect_equal(dim(result), c(101, 5))
})

test_that(".extractPlotData handles vector input", {
  skip_if_not_installed("ggplot2")
  data <- rnorm(101)
  result <- PhysioMoCap:::.extractPlotData(data)
  expect_true(is.matrix(result))
  expect_equal(ncol(result), 1)
})

test_that(".extractPlotData handles 3D array input", {
  skip_if_not_installed("ggplot2")
  data <- array(rnorm(101 * 3 * 5), dim = c(101, 3, 5))
  result <- PhysioMoCap:::.extractPlotData(data, channel = 2)
  expect_true(is.matrix(result))
  expect_equal(dim(result), c(101, 5))
})
