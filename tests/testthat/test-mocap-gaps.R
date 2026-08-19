library(testthat)
library(PhysioMoCap)

# --- Helper to create PE with gaps ---

make_pe_with_gaps <- function(n_time = 100, n_markers = 3, sr = 120,
                              gap_ranges = list(list(ch = 1, start = 20, end = 25))) {
  marker_names <- paste0("Marker", seq_len(n_markers))

  pos_x <- matrix(seq_len(n_time * n_markers), nrow = n_time, ncol = n_markers)
  pos_y <- matrix(seq_len(n_time * n_markers) * 2, nrow = n_time, ncol = n_markers)
  pos_z <- matrix(seq_len(n_time * n_markers) * 3, nrow = n_time, ncol = n_markers)

  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  # Introduce gaps

for (gap in gap_ranges) {
    pos_x[gap$start:gap$end, gap$ch] <- NA
    pos_y[gap$start:gap$end, gap$ch] <- NA
    pos_z[gap$start:gap$end, gap$ch] <- NA
  }

  PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names,
      type = rep("marker", n_markers)
    ),
    samplingRate = sr
  )
}

# ============================================================
# detectGaps
# ============================================================

test_that("detectGaps finds correct start, end, and size", {
  pe <- make_pe_with_gaps(
    gap_ranges = list(list(ch = 1, start = 10, end = 15))
  )
  gaps <- detectGaps(pe, assay_name = "position_x")

  expect_s3_class(gaps, "data.frame")
  expect_true(nrow(gaps) >= 1)

  g1 <- gaps[gaps$channel == "Marker1", ]
  expect_equal(nrow(g1), 1)
  expect_equal(g1$start, 10)
  expect_equal(g1$end, 15)
  expect_equal(g1$size, 6)
})

test_that("detectGaps returns empty data.frame when no gaps exist", {
  pe <- make_mocap_markers(n_time = 50, n_markers = 3, sr = 120)
  gaps <- detectGaps(pe, assay_name = "position_x")

  expect_s3_class(gaps, "data.frame")
  expect_equal(nrow(gaps), 0)
  expect_true(all(c("channel", "start", "end", "size") %in% names(gaps)))
})

test_that("detectGaps finds multiple gaps in one channel", {
  pe <- make_pe_with_gaps(
    gap_ranges = list(
      list(ch = 1, start = 5, end = 8),
      list(ch = 1, start = 50, end = 55)
    )
  )
  gaps <- detectGaps(pe, assay_name = "position_x")
  g1 <- gaps[gaps$channel == "Marker1", ]

  expect_equal(nrow(g1), 2)
  expect_equal(g1$start[1], 5)
  expect_equal(g1$end[1], 8)
  expect_equal(g1$size[1], 4)
  expect_equal(g1$start[2], 50)
  expect_equal(g1$end[2], 55)
  expect_equal(g1$size[2], 6)
})

test_that("detectGaps finds gaps across multiple channels", {
  pe <- make_pe_with_gaps(
    n_markers = 3,
    gap_ranges = list(
      list(ch = 1, start = 10, end = 12),
      list(ch = 3, start = 40, end = 45)
    )
  )
  gaps <- detectGaps(pe, assay_name = "position_x")

  affected_channels <- unique(gaps$channel)
  expect_true("Marker1" %in% affected_channels)
  expect_true("Marker3" %in% affected_channels)
})

# ============================================================
# reportGaps
# ============================================================

test_that("reportGaps prints summary and returns stats invisibly", {
  gaps <- data.frame(
    channel = c("M1", "M1", "M2"),
    start = c(10, 50, 20),
    end = c(15, 55, 30),
    size = c(6, 6, 11),
    stringsAsFactors = FALSE
  )

  out <- capture.output(result <- reportGaps(gaps, sampling_rate = 120))
  expect_true(any(grepl("Total gaps", out)))
  expect_true(any(grepl("3", out)))  # 3 total gaps
  expect_equal(result$total_gaps, 3)
  expect_equal(result$total_missing, 23)
})

test_that("reportGaps handles empty gaps", {
  gaps <- data.frame(
    channel = character(0),
    start = integer(0),
    end = integer(0),
    size = integer(0),
    stringsAsFactors = FALSE
  )

  out <- capture.output(result <- reportGaps(gaps, sampling_rate = 120))
  expect_true(any(grepl("No gaps", out)))
  expect_equal(result$total_gaps, 0L)
})

# ============================================================
# fillGapsLinear
# ============================================================

test_that("fillGapsLinear fills interior NAs with correct values", {
  x <- c(1, NA, 3, NA, NA, 6)
  filled <- fillGapsLinear(x)

  expect_equal(filled[1], 1)
  expect_equal(filled[2], 2)
  expect_equal(filled[3], 3)
  expect_equal(filled[4], 4)
  expect_equal(filled[5], 5)
  expect_equal(filled[6], 6)
})

test_that("fillGapsLinear leaves leading and trailing NAs", {
  x <- c(NA, NA, 3, 4, 5, NA)
  filled <- fillGapsLinear(x)

  expect_true(is.na(filled[1]))
  expect_true(is.na(filled[2]))
  expect_equal(filled[3], 3)
  expect_equal(filled[5], 5)
  expect_true(is.na(filled[6]))
})

test_that("fillGapsLinear returns unchanged vector if fewer than 2 valid points", {
  x <- c(NA, NA, 5, NA, NA)
  filled <- fillGapsLinear(x)
  # Only 1 valid point, should return as-is
  expect_equal(filled, x)
})

# ============================================================
# fillGapsSpline
# ============================================================

test_that("fillGapsSpline fills gaps smoothly", {
  # Create a smooth signal with a gap
  t <- seq(0, 2 * pi, length.out = 100)
  x <- sin(t)
  gap_idx <- 40:50
  x_gapped <- x
  x_gapped[gap_idx] <- NA

  filled <- fillGapsSpline(x_gapped)

  # The filled values should be close to the original
  expect_true(all(!is.na(filled[gap_idx])))
  max_error <- max(abs(filled[gap_idx] - x[gap_idx]))
  expect_true(max_error < 0.5)
})

test_that("fillGapsSpline produces no discontinuities at gap edges", {
  t <- seq(0, 2 * pi, length.out = 200)
  x <- sin(t)
  gap_start <- 80
  gap_end <- 90
  x_gapped <- x
  x_gapped[gap_start:gap_end] <- NA

  filled <- fillGapsSpline(x_gapped)

  # Check continuity at edges: difference between filled and adjacent should be small
  diff_left <- abs(filled[gap_start] - filled[gap_start - 1])
  diff_right <- abs(filled[gap_end] - filled[gap_end + 1])

  # Differences at boundaries should be similar to typical step size
  typical_step <- mean(abs(diff(x)))
  expect_true(diff_left < 10 * typical_step)
  expect_true(diff_right < 10 * typical_step)
})

test_that("fillGapsSpline falls back to linear with fewer than 4 valid points", {
  x <- c(1, NA, 3, NA, 5)
  filled <- fillGapsSpline(x)
  # With only 3 valid points, should use linear
  expect_equal(filled[1], 1)
  expect_equal(filled[2], 2)
  expect_equal(filled[3], 3)
  expect_equal(filled[4], 4)
  expect_equal(filled[5], 5)
})

# ============================================================
# fillGaps (main function)
# ============================================================

test_that("fillGaps fills NAs in multiple position assays", {
  pe <- make_pe_with_gaps(
    gap_ranges = list(list(ch = 1, start = 20, end = 25))
  )

  pe_filled <- fillGaps(pe, method = "linear", max_gap = 50)

  # Check position_x is filled
  mat_x <- SummarizedExperiment::assay(pe_filled, "position_x")
  expect_true(!any(is.na(mat_x[20:25, 1])))

  # Check position_y is also filled
  mat_y <- SummarizedExperiment::assay(pe_filled, "position_y")
  expect_true(!any(is.na(mat_y[20:25, 1])))

  # Check position_z is also filled
  mat_z <- SummarizedExperiment::assay(pe_filled, "position_z")
  expect_true(!any(is.na(mat_z[20:25, 1])))
})

test_that("fillGaps leaves gaps larger than max_gap as NA", {
  pe <- make_pe_with_gaps(
    n_time = 200,
    gap_ranges = list(
      list(ch = 1, start = 10, end = 15),   # size = 6: should be filled
      list(ch = 1, start = 50, end = 110)   # size = 61: should NOT be filled
    )
  )

  pe_filled <- fillGaps(pe, method = "linear", max_gap = 50)
  mat <- SummarizedExperiment::assay(pe_filled, "position_x")

  # Small gap filled
  expect_true(!any(is.na(mat[10:15, 1])))

  # Large gap remains NA
  expect_true(all(is.na(mat[50:110, 1])))
})

test_that("fillGaps with spline method fills correctly", {
  pe <- make_pe_with_gaps(
    gap_ranges = list(list(ch = 1, start = 30, end = 35))
  )

  pe_filled <- fillGaps(pe, method = "spline", max_gap = 50)
  mat <- SummarizedExperiment::assay(pe_filled, "position_x")

  expect_true(!any(is.na(mat[30:35, 1])))
})

test_that("fillGaps handles specific assay_names argument", {
  pe <- make_pe_with_gaps(
    gap_ranges = list(list(ch = 1, start = 20, end = 25))
  )

  # Only fill position_x
  pe_filled <- fillGaps(pe, method = "linear", max_gap = 50,
                         assay_names = "position_x")

  mat_x <- SummarizedExperiment::assay(pe_filled, "position_x")
  mat_y <- SummarizedExperiment::assay(pe_filled, "position_y")

  # position_x should be filled
  expect_true(!any(is.na(mat_x[20:25, 1])))

  # position_y should still have gaps (not requested)
  expect_true(any(is.na(mat_y[20:25, 1])))
})

test_that("fillGaps returns PhysioExperiment", {
  pe <- make_pe_with_gaps(
    gap_ranges = list(list(ch = 1, start = 20, end = 25))
  )
  pe_filled <- fillGaps(pe, method = "linear", max_gap = 50)

  expect_true(inherits(pe_filled, "PhysioExperiment"))
})

# ============================================================
# Edge cases
# ============================================================

test_that("fillGaps handles gap at start of channel", {
  marker_names <- c("M1")
  pos_x <- matrix(seq_len(50), nrow = 50, ncol = 1)
  colnames(pos_x) <- marker_names
  pos_x[1:5, 1] <- NA

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = pos_x),
    colData = S4Vectors::DataFrame(label = marker_names, type = "marker"),
    samplingRate = 120
  )

  pe_filled <- fillGaps(pe, method = "linear", max_gap = 50,
                         assay_names = "position_x")
  mat <- SummarizedExperiment::assay(pe_filled, "position_x")

  # Leading NAs remain (linear interp rule=1 does not extrapolate)
  expect_true(all(is.na(mat[1:5, 1])))
  # Rest should be intact
  expect_true(!any(is.na(mat[6:50, 1])))
})

test_that("fillGaps handles gap at end of channel", {
  marker_names <- c("M1")
  pos_x <- matrix(seq_len(50), nrow = 50, ncol = 1)
  colnames(pos_x) <- marker_names
  pos_x[46:50, 1] <- NA

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = pos_x),
    colData = S4Vectors::DataFrame(label = marker_names, type = "marker"),
    samplingRate = 120
  )

  pe_filled <- fillGaps(pe, method = "linear", max_gap = 50,
                         assay_names = "position_x")
  mat <- SummarizedExperiment::assay(pe_filled, "position_x")

  # Trailing NAs remain (linear interp rule=1 does not extrapolate)
  expect_true(all(is.na(mat[46:50, 1])))
  # Rest should be intact
  expect_true(!any(is.na(mat[1:45, 1])))
})

test_that("fillGaps handles all-NA channel gracefully", {
  marker_names <- c("M1", "M2")
  pos_x <- matrix(seq_len(100), nrow = 50, ncol = 2)
  colnames(pos_x) <- marker_names
  pos_x[, 1] <- NA  # All-NA channel

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = pos_x),
    colData = S4Vectors::DataFrame(label = marker_names, type = rep("marker", 2)),
    samplingRate = 120
  )

  # Should not error
  pe_filled <- fillGaps(pe, method = "linear", max_gap = 50,
                         assay_names = "position_x")
  mat <- SummarizedExperiment::assay(pe_filled, "position_x")

  # All-NA channel remains all-NA (nothing to interpolate from)
  expect_true(all(is.na(mat[, 1])))
  # Other channel should be unchanged (no NAs originally)
  expect_true(!any(is.na(mat[, 2])))
})

test_that("detectGaps correctly handles gap at start of data", {
  marker_names <- c("M1")
  pos_x <- matrix(seq_len(30), nrow = 30, ncol = 1)
  colnames(pos_x) <- marker_names
  pos_x[1:5, 1] <- NA

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = pos_x),
    colData = S4Vectors::DataFrame(label = marker_names, type = "marker"),
    samplingRate = 120
  )

  gaps <- detectGaps(pe, assay_name = "position_x")
  expect_equal(nrow(gaps), 1)
  expect_equal(gaps$start, 1)
  expect_equal(gaps$end, 5)
  expect_equal(gaps$size, 5)
})

test_that("detectGaps correctly handles gap at end of data", {
  marker_names <- c("M1")
  pos_x <- matrix(seq_len(30), nrow = 30, ncol = 1)
  colnames(pos_x) <- marker_names
  pos_x[26:30, 1] <- NA

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = pos_x),
    colData = S4Vectors::DataFrame(label = marker_names, type = "marker"),
    samplingRate = 120
  )

  gaps <- detectGaps(pe, assay_name = "position_x")
  expect_equal(nrow(gaps), 1)
  expect_equal(gaps$start, 26)
  expect_equal(gaps$end, 30)
  expect_equal(gaps$size, 5)
})
