library(testthat)
library(PhysioMoCap)

# --- segmentParameters tests ---

test_that("segmentParameters returns correct structure for deLeva_male", {
  bsip <- segmentParameters("deLeva_male")

  expect_s3_class(bsip, "data.frame")
  expect_true(all(c("segment", "mass_fraction", "com_proximal_fraction",
                     "proximal_marker", "distal_marker") %in% colnames(bsip)))
  expect_equal(nrow(bsip), 14)
})

test_that("segmentParameters mass fractions sum to approximately 100%", {
  bsip_m <- segmentParameters("deLeva_male")
  bsip_f <- segmentParameters("deLeva_female")
  bsip_w <- segmentParameters("winter")

  expect_equal(sum(bsip_m$mass_fraction), 100, tolerance = 2)
  expect_equal(sum(bsip_f$mass_fraction), 100, tolerance = 2)
  expect_equal(sum(bsip_w$mass_fraction), 100, tolerance = 2)
})

test_that("segmentParameters COM fractions are in [0, 1]", {
  bsip <- segmentParameters("deLeva_male")
  expect_true(all(bsip$com_proximal_fraction >= 0))
  expect_true(all(bsip$com_proximal_fraction <= 1))
})

test_that("segmentParameters female model has different values than male", {
  bsip_m <- segmentParameters("deLeva_male")
  bsip_f <- segmentParameters("deLeva_female")

  expect_equal(bsip_m$segment, bsip_f$segment)
  # Mass fractions should differ
  expect_false(all(bsip_m$mass_fraction == bsip_f$mass_fraction))
  # COM fractions should differ
  expect_false(all(bsip_m$com_proximal_fraction == bsip_f$com_proximal_fraction))
})

test_that("segmentParameters errors on invalid model name", {
  expect_error(segmentParameters("invalid_model"))
})

# --- calculateCOM tests ---

test_that("calculateCOM with all markers at same position returns COM at that position", {
  n_frames <- 10
  bsip <- segmentParameters("deLeva_male")
  all_markers <- unique(c(bsip$proximal_marker, bsip$distal_marker))
  n_markers <- length(all_markers)

  # All markers at position (5, 3, 7)
  pos_x <- matrix(5, nrow = n_frames, ncol = n_markers)
  pos_y <- matrix(3, nrow = n_frames, ncol = n_markers)
  pos_z <- matrix(7, nrow = n_frames, ncol = n_markers)
  colnames(pos_x) <- all_markers
  colnames(pos_y) <- all_markers
  colnames(pos_z) <- all_markers

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = all_markers,
      type = rep("marker", n_markers)
    ),
    samplingRate = 120
  )

  result <- calculateCOM(pe, body_mass = 75)

  com_x <- SummarizedExperiment::assay(result, "com_x")
  com_y <- SummarizedExperiment::assay(result, "com_y")
  com_z <- SummarizedExperiment::assay(result, "com_z")

  # When all markers are at the same point, COM must be at that point
  expect_equal(as.numeric(com_x[, 1]), rep(5, n_frames), tolerance = 1e-10)
  expect_equal(as.numeric(com_y[, 1]), rep(3, n_frames), tolerance = 1e-10)
  expect_equal(as.numeric(com_z[, 1]), rep(7, n_frames), tolerance = 1e-10)
})

test_that("calculateCOM output has com_x, com_y, com_z assays", {
  n_frames <- 5
  bsip <- segmentParameters("deLeva_male")
  all_markers <- unique(c(bsip$proximal_marker, bsip$distal_marker))
  n_markers <- length(all_markers)

  pos_x <- matrix(rnorm(n_frames * n_markers), nrow = n_frames)
  pos_y <- matrix(rnorm(n_frames * n_markers), nrow = n_frames)
  pos_z <- matrix(rnorm(n_frames * n_markers), nrow = n_frames)
  colnames(pos_x) <- all_markers
  colnames(pos_y) <- all_markers
  colnames(pos_z) <- all_markers

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = all_markers,
      type = rep("marker", n_markers)
    ),
    samplingRate = 100
  )

  result <- calculateCOM(pe, body_mass = 70)

  anames <- SummarizedExperiment::assayNames(result)
  expect_true("com_x" %in% anames)
  expect_true("com_y" %in% anames)
  expect_true("com_z" %in% anames)

  expect_equal(ncol(SummarizedExperiment::assay(result, "com_x")), 1)
  expect_equal(colnames(SummarizedExperiment::assay(result, "com_x")), "COM")
  expect_equal(nrow(SummarizedExperiment::assay(result, "com_x")), n_frames)
})

test_that("calculateCOM with uniform body gives COM at centroid", {
  # Create a simple 2-segment model where both segments have equal mass
  # and COM at midpoint. Place proximal/distal markers symmetrically.
  n_frames <- 5
  marker_names <- c("A", "B", "C")

  # Segment 1: A -> B, Segment 2: B -> C
  # A at (0,0,0), B at (1,0,0), C at (2,0,0)
  # With equal mass fraction and COM at midpoint (0.5),
  # seg1 COM at 0.5, seg2 COM at 1.5
  # whole body COM at mean = 1.0
  pos_x <- matrix(c(rep(0, n_frames), rep(1, n_frames), rep(2, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_y <- matrix(0, nrow = n_frames, ncol = 3)
  pos_z <- matrix(0, nrow = n_frames, ncol = 3)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names,
      type = rep("marker", 3)
    ),
    samplingRate = 100
  )

  custom_bsip <- data.frame(
    segment = c("seg1", "seg2"),
    mass_fraction = c(50, 50),
    com_proximal_fraction = c(0.5, 0.5),
    proximal_marker = c("A", "B"),
    distal_marker = c("B", "C"),
    stringsAsFactors = FALSE
  )

  marker_map <- list(
    seg1 = c("A", "B"),
    seg2 = c("B", "C")
  )

  result <- calculateCOM(pe, body_mass = 80, bsip = custom_bsip,
                         marker_map = marker_map)

  com_x <- SummarizedExperiment::assay(result, "com_x")
  expect_equal(as.numeric(com_x[, 1]), rep(1.0, n_frames), tolerance = 1e-10)
})

test_that("calculateCOM errors on missing markers", {
  n_frames <- 5
  marker_names <- c("A", "B")

  pos_x <- matrix(1, nrow = n_frames, ncol = 2)
  pos_y <- matrix(1, nrow = n_frames, ncol = 2)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names,
      type = rep("marker", 2)
    ),
    samplingRate = 100
  )

  # Default BSIP requires markers not present in this minimal PE
  expect_error(calculateCOM(pe, body_mass = 70), "Missing markers")
})

test_that("calculateCOM errors on invalid body_mass", {
  pe <- make_mocap_markers(n_time = 10, n_markers = 3, sr = 100)

  expect_error(calculateCOM(pe, body_mass = -10), "positive numeric scalar")
  expect_error(calculateCOM(pe, body_mass = 0), "positive numeric scalar")
  expect_error(calculateCOM(pe, body_mass = "seventy"), "positive numeric scalar")
})

test_that("calculateCOM works with 2D data (no position_z)", {
  n_frames <- 5
  marker_names <- c("A", "B", "C")

  pos_x <- matrix(c(rep(0, n_frames), rep(1, n_frames), rep(2, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_y <- matrix(c(rep(0, n_frames), rep(1, n_frames), rep(0, n_frames)),
                  nrow = n_frames, ncol = 3)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names,
      type = rep("marker", 3)
    ),
    samplingRate = 60
  )

  custom_bsip <- data.frame(
    segment = c("seg1", "seg2"),
    mass_fraction = c(50, 50),
    com_proximal_fraction = c(0.5, 0.5),
    proximal_marker = c("A", "B"),
    distal_marker = c("B", "C"),
    stringsAsFactors = FALSE
  )
  marker_map <- list(seg1 = c("A", "B"), seg2 = c("B", "C"))

  result <- calculateCOM(pe, body_mass = 70, bsip = custom_bsip,
                         marker_map = marker_map)

  anames <- SummarizedExperiment::assayNames(result)
  expect_true("com_x" %in% anames)
  expect_true("com_y" %in% anames)
  expect_false("com_z" %in% anames)
})

# --- calculateSegmentCOM tests ---

test_that("calculateSegmentCOM returns correct per-segment COMs", {
  n_frames <- 5
  marker_names <- c("A", "B", "C")

  # A at (0,0,0), B at (10,0,0), C at (10,10,0)
  pos_x <- matrix(c(rep(0, n_frames), rep(10, n_frames), rep(10, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_y <- matrix(c(rep(0, n_frames), rep(0, n_frames), rep(10, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_z <- matrix(0, nrow = n_frames, ncol = 3)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x, position_y = pos_y, position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names, type = rep("marker", 3)
    ),
    samplingRate = 100
  )

  seg_coms <- calculateSegmentCOM(
    pe,
    proximal_markers = c("A", "B"),
    distal_markers = c("B", "C"),
    com_fractions = c(0.5, 0.5)
  )

  expect_type(seg_coms, "list")
  expect_equal(length(seg_coms), 2)

  # Segment A->B at fraction 0.5: COM at (5, 0, 0)
  expect_equal(as.numeric(seg_coms[[1]][1, ]), c(5, 0, 0), tolerance = 1e-10)
  # Segment B->C at fraction 0.5: COM at (10, 5, 0)
  expect_equal(as.numeric(seg_coms[[2]][1, ]), c(10, 5, 0), tolerance = 1e-10)
})

# --- symmetryIndex tests ---

test_that("symmetryIndex: perfect symmetry returns 0", {
  si <- symmetryIndex(10, 10)
  expect_equal(si, 0, tolerance = 1e-10)

  # Vector version
  si_vec <- symmetryIndex(c(10, 20, 30), c(10, 20, 30))
  expect_equal(si_vec, c(0, 0, 0), tolerance = 1e-10)
})

test_that("symmetryIndex: known asymmetry (L=10, R=8 gives SI ~22.2%)", {
  si <- symmetryIndex(10, 8)
  expected <- abs(10 - 8) / (0.5 * (10 + 8)) * 100  # 22.222...
  expect_equal(si, expected, tolerance = 0.1)
  expect_equal(si, 200 / 9, tolerance = 1e-10)
})

test_that("symmetryIndex ratio method returns L/R", {
  si <- symmetryIndex(10, 8, method = "ratio")
  expect_equal(si, 10 / 8, tolerance = 1e-10)

  # Perfect symmetry with ratio
  si2 <- symmetryIndex(10, 10, method = "ratio")
  expect_equal(si2, 1.0, tolerance = 1e-10)
})

test_that("symmetryIndex works with matrices (row-wise)", {
  left <- matrix(c(10, 20), nrow = 2, ncol = 1)
  right <- matrix(c(10, 10), nrow = 2, ncol = 1)
  si <- symmetryIndex(left, right)

  expect_equal(length(si), 2)
  expect_equal(si[1], 0, tolerance = 1e-10)  # 10 vs 10
  expect_true(si[2] > 0)  # 20 vs 10, asymmetric
})

test_that("symmetryIndex handles zero values gracefully", {
  # Both zero: should return 0 (not NaN)
  si <- symmetryIndex(0, 0)
  expect_equal(si, 0)

  # Ratio with zero denominator: should return NA
  si_ratio <- symmetryIndex(10, 0, method = "ratio")
  expect_true(is.na(si_ratio))
})
