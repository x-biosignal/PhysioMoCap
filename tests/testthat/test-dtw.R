library(testthat)
library(PhysioMoCap)

# --- dtwDistance ---

test_that("dtwDistance computes valid distance between two waveforms", {
  x <- sin(seq(0, 2 * pi, length.out = 100))
  y <- sin(seq(0.5, 2.5 * pi, length.out = 100))
  result <- dtwDistance(x, y)
  expect_s3_class(result, "dtw_result")
  expect_true(result$distance > 0)
  expect_true(result$normalized_distance > 0)
  expect_true(is.matrix(result$path))
  expect_equal(ncol(result$path), 2)
  expect_equal(colnames(result$path), c("index1", "index2"))
  expect_equal(result$n, 100)
  expect_equal(result$m, 100)
  expect_equal(result$step_pattern, "symmetric2")
})

test_that("dtwDistance returns zero for identical series", {
  x <- sin(seq(0, 2 * pi, length.out = 50))
  result <- dtwDistance(x, x)
  expect_equal(result$distance, 0)
  expect_equal(result$normalized_distance, 0)
})

test_that("dtwDistance works with different step patterns", {
  x <- sin(seq(0, 2 * pi, length.out = 50))
  y <- sin(seq(0.3, 2.3 * pi, length.out = 50))

  r1 <- dtwDistance(x, y, step_pattern = "symmetric1")
  r2 <- dtwDistance(x, y, step_pattern = "symmetric2")
  r3 <- dtwDistance(x, y, step_pattern = "asymmetric")

  expect_s3_class(r1, "dtw_result")
  expect_s3_class(r2, "dtw_result")
  expect_s3_class(r3, "dtw_result")
  expect_true(r1$distance > 0)
  expect_true(r2$distance > 0)
  expect_true(r3$distance > 0)
})

test_that("dtwDistance works with Sakoe-Chiba band constraint", {
  x <- sin(seq(0, 2 * pi, length.out = 50))
  y <- sin(seq(0.3, 2.3 * pi, length.out = 50))
  result <- dtwDistance(x, y, window_size = 10)
  expect_s3_class(result, "dtw_result")
  expect_true(result$distance > 0)
})

test_that("dtwDistance works with different length series", {
  x <- sin(seq(0, 2 * pi, length.out = 80))
  y <- sin(seq(0, 2 * pi, length.out = 100))
  result <- dtwDistance(x, y)
  expect_s3_class(result, "dtw_result")
  expect_equal(result$n, 80)
  expect_equal(result$m, 100)
})

test_that("dtwDistance errors on empty input", {
  expect_error(dtwDistance(numeric(0), 1:10), "cannot be empty")
  expect_error(dtwDistance(1:10, numeric(0)), "cannot be empty")
})

test_that("dtwDistance path starts and ends correctly", {
  x <- rnorm(30)
  y <- rnorm(30)
  result <- dtwDistance(x, y)
  path <- result$path
  # Path should start at (1,1) and end at (n,m)
  expect_equal(path[1, ], c(index1 = 1L, index2 = 1L))
  expect_equal(path[nrow(path), ], c(index1 = 30L, index2 = 30L))
})


# --- dtwDistanceMatrix ---

test_that("dtwDistanceMatrix computes pairwise distances", {
  set.seed(123)
  data <- matrix(rnorm(300), nrow = 100, ncol = 3)
  dm <- dtwDistanceMatrix(data)
  expect_true(inherits(dm, "dist"))
  dm_mat <- as.matrix(dm)
  expect_equal(nrow(dm_mat), 3)
  expect_equal(ncol(dm_mat), 3)
  # Diagonal should be zero
  expect_equal(unname(diag(dm_mat)), c(0, 0, 0))
  # Should be symmetric
  expect_equal(dm_mat[1, 2], dm_mat[2, 1])
  expect_equal(dm_mat[1, 3], dm_mat[3, 1])
  # Off-diagonal should be positive
  expect_true(all(dm_mat[upper.tri(dm_mat)] > 0))
})

test_that("dtwDistanceMatrix rejects invalid input", {
  expect_error(dtwDistanceMatrix("invalid"), "must be a PhysioExperiment or matrix")
})


# --- dtwAverage ---

test_that("dtwAverage computes DBA average", {
  set.seed(123)
  t <- seq(0, 2 * pi, length.out = 50)
  data <- sapply(1:5, function(i) {
    sin(t + rnorm(1, 0, 0.3)) + rnorm(50, 0, 0.1)
  })

  avg <- dtwAverage(data, init = "mean", max_iter = 5)
  expect_true(is.list(avg))
  expect_true("average" %in% names(avg))
  expect_true("iterations" %in% names(avg))
  expect_true("alignments" %in% names(avg))
  expect_equal(length(avg$average), 50)
  expect_equal(length(avg$alignments), 5)
})

test_that("dtwAverage works with medoid initialization", {
  set.seed(42)
  t <- seq(0, 2 * pi, length.out = 30)
  data <- sapply(1:4, function(i) {
    sin(t + i * 0.2) + rnorm(30, 0, 0.05)
  })

  avg <- dtwAverage(data, init = "medoid", max_iter = 3)
  expect_equal(length(avg$average), 30)
  expect_true(avg$iterations <= 3)
})


# --- dtwClustering ---

test_that("dtwClustering with hierarchical method works", {
  set.seed(123)
  t <- seq(0, 2 * pi, length.out = 50)

  # Two distinct groups
  group1 <- sapply(1:5, function(i) sin(t) + rnorm(50, 0, 0.1))
  group2 <- sapply(1:5, function(i) cos(t) + rnorm(50, 0, 0.1))
  data <- cbind(group1, group2)

  result <- dtwClustering(data, k = 2, method = "hierarchical")
  expect_s3_class(result, "dtw_clustering")
  expect_equal(length(result$clusters), 10)
  expect_true(all(result$clusters %in% c(1, 2)))
  expect_true(!is.null(result$centers))
  expect_true(!is.null(result$dendrogram))
})

test_that("dtwClustering with kmedoids method works", {
  set.seed(456)
  t <- seq(0, 2 * pi, length.out = 40)

  group1 <- sapply(1:4, function(i) sin(t) + rnorm(40, 0, 0.1))
  group2 <- sapply(1:4, function(i) cos(t) + rnorm(40, 0, 0.1))
  data <- cbind(group1, group2)

  result <- dtwClustering(data, k = 2, method = "kmedoids")
  expect_s3_class(result, "dtw_clustering")
  expect_equal(length(result$clusters), 8)
  expect_true(all(result$clusters %in% c(1, 2)))
  expect_true(!is.null(result$medoid_indices))
})


# --- dtwWarp ---

test_that("dtwWarp warps to query length", {
  x <- sin(seq(0, 2 * pi, length.out = 80))
  y <- sin(seq(0.3, 2.3 * pi, length.out = 100))
  dtw_result <- dtwDistance(x, y)

  warped <- dtwWarp(y, dtw_result, to = "query")
  expect_equal(length(warped), dtw_result$n)
})

test_that("dtwWarp warps to reference length", {
  x <- sin(seq(0, 2 * pi, length.out = 80))
  y <- sin(seq(0.3, 2.3 * pi, length.out = 100))
  dtw_result <- dtwDistance(x, y)

  warped <- dtwWarp(x, dtw_result, to = "reference")
  expect_equal(length(warped), dtw_result$m)
})

test_that("dtwWarp errors on non-dtw_result input", {
  expect_error(dtwWarp(1:10, list(path = matrix(1:4, ncol = 2))),
               "must be from dtwDistance")
})


# --- plotDTW ---

test_that("plotDTW creates alignment plot", {
  skip_if_not_installed("ggplot2")
  x <- sin(seq(0, 2 * pi, length.out = 50))
  y <- sin(seq(0.5, 2.5 * pi, length.out = 50))
  dtw_result <- dtwDistance(x, y)

  p <- plotDTW(dtw_result, type = "alignment")
  expect_s3_class(p, "ggplot")
})

test_that("plotDTW creates cost matrix plot", {
  skip_if_not_installed("ggplot2")
  x <- sin(seq(0, 2 * pi, length.out = 30))
  y <- sin(seq(0.5, 2.5 * pi, length.out = 30))
  dtw_result <- dtwDistance(x, y)

  p <- plotDTW(dtw_result, type = "cost")
  expect_s3_class(p, "ggplot")
})

test_that("plotDTW creates waveform comparison plot", {
  skip_if_not_installed("ggplot2")
  x <- sin(seq(0, 2 * pi, length.out = 50))
  y <- sin(seq(0.5, 2.5 * pi, length.out = 50))
  dtw_result <- dtwDistance(x, y)

  p <- plotDTW(dtw_result, x = x, y = y, type = "waveforms")
  expect_s3_class(p, "ggplot")
})

test_that("plotDTW creates all plots", {
  skip_if_not_installed("ggplot2")
  x <- sin(seq(0, 2 * pi, length.out = 30))
  y <- sin(seq(0.5, 2.5 * pi, length.out = 30))
  dtw_result <- dtwDistance(x, y)

  plots <- plotDTW(dtw_result, x = x, y = y, type = "all")
  expect_true(is.list(plots))
  expect_true("alignment" %in% names(plots))
  expect_true("cost" %in% names(plots))
  expect_true("waveforms" %in% names(plots))
})

test_that("plotDTW errors on non-dtw_result input", {
  expect_error(plotDTW(list()), "must be a dtw_result")
})


# --- print methods ---

test_that("print.dtw_result works", {
  x <- sin(seq(0, 2 * pi, length.out = 50))
  y <- sin(seq(0.5, 2.5 * pi, length.out = 50))
  result <- dtwDistance(x, y)
  expect_output(print(result), "DTW Result")
  expect_output(print(result), "Query length: 50")
  expect_output(print(result), "Reference length: 50")
  expect_output(print(result), "Distance:")
})

test_that("print.dtw_clustering works", {
  set.seed(123)
  t <- seq(0, 2 * pi, length.out = 30)
  data <- sapply(1:6, function(i) sin(t + i * 0.3) + rnorm(30, 0, 0.05))
  result <- dtwClustering(data, k = 2, method = "hierarchical")
  expect_output(print(result), "DTW Clustering Result")
  expect_output(print(result), "Observations: 6")
  expect_output(print(result), "Clusters: 2")
})
