library(testthat)
library(PhysioMoCap)

# ===========================================================================
# Helper: create smooth trajectory data with known marker positions
# ===========================================================================

.make_tracking_pe <- function(n_frames = 20, n_markers = 3, sr = 100,
                              permute = FALSE, swap_at = NULL) {
  # Create smooth linear trajectories for each marker
  t_vec <- seq(0, (n_frames - 1) / sr, length.out = n_frames)

  # Each marker has a distinct linear trajectory
  base_x <- seq(100, 200, length.out = n_markers)
  base_y <- seq(200, 300, length.out = n_markers)
  base_z <- seq(300, 400, length.out = n_markers)

  pos_x <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_y <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_z <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)

  for (m in seq_len(n_markers)) {
    pos_x[, m] <- base_x[m] + t_vec * (m * 10)
    pos_y[, m] <- base_y[m] + t_vec * (m * 5)
    pos_z[, m] <- base_z[m] + t_vec * (m * 3)
  }

  # Optionally permute each frame randomly (simulating Venus3D behaviour)
  if (permute) {
    set.seed(42)
    for (t in seq_len(n_frames)) {
      perm <- sample(n_markers)
      pos_x[t, ] <- pos_x[t, perm]
      pos_y[t, ] <- pos_y[t, perm]
      pos_z[t, ] <- pos_z[t, perm]
    }
  }

  # Optionally introduce a swap at a specific frame
  if (!is.null(swap_at) && swap_at >= 1 && swap_at <= n_frames && n_markers >= 2) {
    for (t in swap_at:n_frames) {
      # Swap markers 1 and 2
      tmp <- pos_x[t, 1]; pos_x[t, 1] <- pos_x[t, 2]; pos_x[t, 2] <- tmp
      tmp <- pos_y[t, 1]; pos_y[t, 1] <- pos_y[t, 2]; pos_y[t, 2] <- tmp
      tmp <- pos_z[t, 1]; pos_z[t, 1] <- pos_z[t, 2]; pos_z[t, 2] <- tmp
    }
  }

  mnames <- paste0("M", seq_len(n_markers))
  colnames(pos_x) <- mnames
  colnames(pos_y) <- mnames
  colnames(pos_z) <- mnames

  PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = mnames,
      type = rep("marker", n_markers)
    ),
    samplingRate = sr
  )
}


# ===========================================================================
# trackMarkers — identity (no permutation)
# ===========================================================================

test_that("trackMarkers with identity permutation returns same data", {
  pe <- .make_tracking_pe(n_frames = 10, n_markers = 3)
  pe_tracked <- trackMarkers(pe, method = "greedy")

  px_in <- SummarizedExperiment::assay(pe, "position_x")
  px_out <- SummarizedExperiment::assay(pe_tracked, "position_x")

  expect_equal(px_out, px_in, tolerance = 1e-10)
})

test_that("trackMarkers stores tracking metadata", {
  pe <- .make_tracking_pe(n_frames = 10, n_markers = 3)
  pe_tracked <- trackMarkers(pe, method = "greedy")

  md <- S4Vectors::metadata(pe_tracked)
  expect_true("tracking" %in% names(md))
  expect_true("assignment" %in% names(md$tracking))
  expect_true("cost" %in% names(md$tracking))
  expect_true("method" %in% names(md$tracking))
})


# ===========================================================================
# trackMarkers — known single swap
# ===========================================================================

test_that("trackMarkers resolves a known single swap", {
  # Create data with a swap at frame 5
  pe_clean <- .make_tracking_pe(n_frames = 10, n_markers = 3)
  pe_swapped <- .make_tracking_pe(n_frames = 10, n_markers = 3, swap_at = 5)

  pe_tracked <- trackMarkers(pe_swapped, method = "greedy")

  px_clean <- SummarizedExperiment::assay(pe_clean, "position_x")
  px_tracked <- SummarizedExperiment::assay(pe_tracked, "position_x")

  # After tracking, the trajectories should match the clean data
  expect_equal(px_tracked, px_clean, tolerance = 1e-6)
})


# ===========================================================================
# trackMarkers — random permutations
# ===========================================================================

test_that("trackMarkers with random permutations produces smooth trajectories", {
  pe_permuted <- .make_tracking_pe(n_frames = 50, n_markers = 3, permute = TRUE)
  pe_tracked <- trackMarkers(pe_permuted, method = "greedy")

  px <- SummarizedExperiment::assay(pe_tracked, "position_x")

  # Smoothness: frame-to-frame velocity variance should be small
  vel <- apply(px, 2, diff)
  vel_var <- apply(vel, 2, var, na.rm = TRUE)

  # With smooth linear trajectories, variance of velocity should be near zero
  # (since velocity is constant for a linear trajectory)
  for (m in seq_len(ncol(px))) {
    expect_true(vel_var[m] < 1.0,
                info = paste("Marker", m, "velocity variance too high:", vel_var[m]))
  }
})


# ===========================================================================
# trackMarkers — NA markers
# ===========================================================================

test_that("trackMarkers handles NA markers (marker dropout)", {
  pe <- .make_tracking_pe(n_frames = 10, n_markers = 3)

  # Introduce NAs in marker 2 at frames 4-6
  px <- SummarizedExperiment::assay(pe, "position_x")
  py <- SummarizedExperiment::assay(pe, "position_y")
  pz <- SummarizedExperiment::assay(pe, "position_z")
  px[4:6, 2] <- NA
  py[4:6, 2] <- NA
  pz[4:6, 2] <- NA
  SummarizedExperiment::assay(pe, "position_x") <- px
  SummarizedExperiment::assay(pe, "position_y") <- py
  SummarizedExperiment::assay(pe, "position_z") <- pz

  pe_tracked <- trackMarkers(pe, method = "greedy")

  px_out <- SummarizedExperiment::assay(pe_tracked, "position_x")

  # Markers 1 and 3 should still be tracked correctly
  expect_false(any(is.na(px_out[, 1])))
  expect_false(any(is.na(px_out[, 3])))
})


# ===========================================================================
# trackMarkers — max_distance
# ===========================================================================

test_that("trackMarkers max_distance sets distant assignments to NA", {
  pe <- .make_tracking_pe(n_frames = 10, n_markers = 3)

  # Introduce a large jump in marker 1 at frame 5
  px <- SummarizedExperiment::assay(pe, "position_x")
  px[5, 1] <- px[5, 1] + 10000
  SummarizedExperiment::assay(pe, "position_x") <- px

  pe_tracked <- trackMarkers(pe, method = "greedy", max_distance = 100)
  px_out <- SummarizedExperiment::assay(pe_tracked, "position_x")

  # The jump frame should result in NA for that marker
  expect_true(is.na(px_out[5, 1]))
})


# ===========================================================================
# trackMarkers — use_prediction
# ===========================================================================

test_that("trackMarkers use_prediction improves tracking with fast linear motion", {
  # Create data with fast linear motion
  n_frames <- 30
  n_markers <- 2
  sr <- 100

  pos_x <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_y <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_z <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)

  # Marker 1: fast rightward, Marker 2: fast leftward
  for (t in seq_len(n_frames)) {
    pos_x[t, 1] <- t * 50      # fast right
    pos_y[t, 1] <- 100
    pos_z[t, 1] <- 100
    pos_x[t, 2] <- 1500 - t * 50  # fast left
    pos_y[t, 2] <- 100
    pos_z[t, 2] <- 100
  }

  # They cross around frame 15
  mnames <- c("M1", "M2")
  colnames(pos_x) <- mnames
  colnames(pos_y) <- mnames
  colnames(pos_z) <- mnames

  # Permute frames to simulate Venus3D
  set.seed(123)
  for (t in seq_len(n_frames)) {
    perm <- sample(n_markers)
    pos_x[t, ] <- pos_x[t, perm]
    pos_y[t, ] <- pos_y[t, perm]
    pos_z[t, ] <- pos_z[t, perm]
  }

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(label = mnames, type = rep("marker", 2)),
    samplingRate = sr
  )

  pe_pred <- trackMarkers(pe, method = "greedy", use_prediction = TRUE)
  px_pred <- SummarizedExperiment::assay(pe_pred, "position_x")

  # With prediction, marker 1 should be consistently increasing
  diffs <- diff(px_pred[, 1])
  # Most diffs should be positive (rightward motion)
  expect_true(sum(diffs > 0, na.rm = TRUE) > n_frames * 0.7)
})


# ===========================================================================
# trackMarkers — single frame (edge case)
# ===========================================================================

test_that("trackMarkers returns unchanged PE with 1 frame", {
  pe <- .make_tracking_pe(n_frames = 1, n_markers = 3)
  pe_tracked <- trackMarkers(pe, method = "greedy")

  px_in <- SummarizedExperiment::assay(pe, "position_x")
  px_out <- SummarizedExperiment::assay(pe_tracked, "position_x")
  expect_equal(px_out, px_in)
})


# ===========================================================================
# detectSwaps — basic detection
# ===========================================================================

test_that("detectSwaps detects a known swap", {
  pe <- .make_tracking_pe(n_frames = 50, n_markers = 3, sr = 100, swap_at = 25)
  swaps <- detectSwaps(pe)

  expect_s3_class(swaps, "data.frame")
  expect_true(nrow(swaps) >= 1)
  expect_true("frame" %in% colnames(swaps))
  expect_true("marker_a" %in% colnames(swaps))
  expect_true("marker_b" %in% colnames(swaps))
  expect_true("confidence" %in% colnames(swaps))

  # The swap should be at or near frame 25
  expect_true(any(swaps$frame >= 24 & swaps$frame <= 26))
})

test_that("detectSwaps returns empty data.frame when no swaps", {
  pe <- .make_tracking_pe(n_frames = 50, n_markers = 3)
  swaps <- detectSwaps(pe)

  expect_s3_class(swaps, "data.frame")
  expect_equal(nrow(swaps), 0)
  expect_true(all(c("frame", "marker_a", "marker_b", "velocity_a",
                     "velocity_b", "confidence") %in% colnames(swaps)))
})


# ===========================================================================
# correctSwaps
# ===========================================================================

test_that("correctSwaps fixes a known swap", {
  pe_clean <- .make_tracking_pe(n_frames = 50, n_markers = 3, sr = 100)
  pe_swapped <- .make_tracking_pe(n_frames = 50, n_markers = 3, sr = 100,
                                   swap_at = 25)

  swaps <- detectSwaps(pe_swapped)
  skip_if(nrow(swaps) == 0, "No swaps detected — cannot test correctSwaps")

  pe_fixed <- correctSwaps(pe_swapped, swaps, min_confidence = 0)

  px_clean <- SummarizedExperiment::assay(pe_clean, "position_x")
  px_fixed <- SummarizedExperiment::assay(pe_fixed, "position_x")

  # After correction, trajectories should be smooth again
  vel_fixed <- apply(px_fixed, 2, diff)
  vel_var_fixed <- apply(vel_fixed, 2, var, na.rm = TRUE)

  vel_clean <- apply(px_clean, 2, diff)
  vel_var_clean <- apply(vel_clean, 2, var, na.rm = TRUE)

  # Variance should be much closer to clean than to swapped
  for (m in seq_len(ncol(px_fixed))) {
    expect_true(vel_var_fixed[m] < vel_var_clean[m] * 10,
                info = paste("Marker", m, "still too noisy after correction"))
  }
})

test_that("correctSwaps with empty swaps returns PE unchanged", {
  pe <- .make_tracking_pe(n_frames = 20, n_markers = 3)
  empty_swaps <- data.frame(
    frame = integer(0),
    marker_a = character(0),
    marker_b = character(0),
    velocity_a = numeric(0),
    velocity_b = numeric(0),
    confidence = numeric(0),
    stringsAsFactors = FALSE
  )

  pe_fixed <- correctSwaps(pe, empty_swaps)
  px_in <- SummarizedExperiment::assay(pe, "position_x")
  px_out <- SummarizedExperiment::assay(pe_fixed, "position_x")
  expect_equal(px_out, px_in)
})

test_that("correctSwaps respects min_confidence", {
  pe_swapped <- .make_tracking_pe(n_frames = 50, n_markers = 3, swap_at = 25)

  swaps <- detectSwaps(pe_swapped)
  skip_if(nrow(swaps) == 0, "No swaps detected")

  # Set min_confidence very high — should skip all swaps
  pe_uncorrected <- correctSwaps(pe_swapped, swaps, min_confidence = 1.1)
  px_swapped <- SummarizedExperiment::assay(pe_swapped, "position_x")
  px_uncorrected <- SummarizedExperiment::assay(pe_uncorrected, "position_x")
  expect_equal(px_uncorrected, px_swapped)
})


# ===========================================================================
# Internal helper tests
# ===========================================================================

test_that(".euclidean_cost_matrix computes correct distances", {
  ref <- matrix(c(0, 0, 0, 3, 4, 0), nrow = 2, byrow = TRUE)
  cur <- matrix(c(0, 0, 0, 1, 0, 0), nrow = 2, byrow = TRUE)

  cost <- PhysioMoCap:::.euclidean_cost_matrix(ref, cur)

  expect_equal(nrow(cost), 2)
  expect_equal(ncol(cost), 2)
  # Distance from (0,0,0) to (0,0,0) = 0
  expect_equal(cost[1, 1], 0)
  # Distance from (0,0,0) to (1,0,0) = 1
  expect_equal(cost[1, 2], 1)
  # Distance from (3,4,0) to (0,0,0) = 5
  expect_equal(cost[2, 1], 5)
  # Distance from (3,4,0) to (1,0,0) = sqrt(4+16) = sqrt(20)
  expect_equal(cost[2, 2], sqrt(20))
})

test_that(".pad_cost_matrix creates correct square matrix", {
  cost <- matrix(c(1, 2, 3, 4, 5, 6), nrow = 2, ncol = 3)
  padded <- PhysioMoCap:::.pad_cost_matrix(cost, 3)

  expect_equal(dim(padded), c(3, 3))
  expect_equal(padded[1:2, 1:3], cost)
  expect_equal(padded[3, 1], 1e12)
  expect_equal(padded[3, 2], 1e12)
  expect_equal(padded[3, 3], 1e12)
})

test_that(".greedy_assignment produces valid assignment", {
  cost <- matrix(c(1, 10, 10, 1), nrow = 2, ncol = 2)
  assignment <- PhysioMoCap:::.greedy_assignment(cost)

  expect_equal(length(assignment), 2)
  expect_equal(sort(assignment), c(1L, 2L))
  # Optimal: row 1 -> col 1, row 2 -> col 2
  expect_equal(assignment, c(1L, 2L))
})

test_that(".greedy_assignment handles 3x3 matrix", {
  # Identity-like cost: diagonal is cheapest
  cost <- matrix(100, nrow = 3, ncol = 3)
  diag(cost) <- 1
  assignment <- PhysioMoCap:::.greedy_assignment(cost)

  expect_equal(assignment, c(1L, 2L, 3L))
})
