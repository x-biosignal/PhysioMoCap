library(testthat)
library(PhysioMoCap)

# ===========================================================================
# Helper: create mock wide-format data frame (mimics c3dr::c3d_data output)
# ===========================================================================

make_mock_c3d_wide <- function(n_frames = 10, marker_names = c("RASI", "LASI", "SACR")) {
  n_markers <- length(marker_names)
  df <- data.frame(matrix(NA_real_, nrow = n_frames, ncol = n_markers * 3))

  col_names <- character(0)
  for (m in marker_names) {
    col_names <- c(col_names, paste0(m, "_x"), paste0(m, "_y"), paste0(m, "_z"))
  }
  colnames(df) <- col_names

  # Fill with synthetic data
  set.seed(42)
  for (i in seq_len(ncol(df))) {
    df[[i]] <- rnorm(n_frames, mean = 100 * i, sd = 5)
  }
  df
}


# ===========================================================================
# Tests for .parse_c3d_wide (internal parsing, no c3dr needed)
# ===========================================================================

test_that(".parse_c3d_wide extracts correct marker names", {
  wide_df <- make_mock_c3d_wide(n_frames = 5, marker_names = c("M1", "M2", "M3"))
  result <- PhysioMoCap:::.parse_c3d_wide(wide_df)

  expect_equal(result$marker_names, c("M1", "M2", "M3"))
})

test_that(".parse_c3d_wide returns correct matrix dimensions", {
  wide_df <- make_mock_c3d_wide(n_frames = 20, marker_names = c("A", "B"))
  result <- PhysioMoCap:::.parse_c3d_wide(wide_df)

  expect_equal(dim(result$pos_x), c(20, 2))
  expect_equal(dim(result$pos_y), c(20, 2))
  expect_equal(dim(result$pos_z), c(20, 2))
})

test_that(".parse_c3d_wide assigns correct column names to matrices", {
  markers <- c("RASI", "LASI")
  wide_df <- make_mock_c3d_wide(n_frames = 5, marker_names = markers)
  result <- PhysioMoCap:::.parse_c3d_wide(wide_df)

  expect_equal(colnames(result$pos_x), markers)
  expect_equal(colnames(result$pos_y), markers)
  expect_equal(colnames(result$pos_z), markers)
})

test_that(".parse_c3d_wide preserves coordinate values", {
  wide_df <- data.frame(
    M1_x = c(1.0, 4.0),
    M1_y = c(2.0, 5.0),
    M1_z = c(3.0, 6.0),
    M2_x = c(10.0, 40.0),
    M2_y = c(20.0, 50.0),
    M2_z = c(30.0, 60.0)
  )
  result <- PhysioMoCap:::.parse_c3d_wide(wide_df)

  expect_equal(unname(result$pos_x[1, "M1"]), 1.0)
  expect_equal(unname(result$pos_y[1, "M1"]), 2.0)
  expect_equal(unname(result$pos_z[1, "M1"]), 3.0)
  expect_equal(unname(result$pos_x[2, "M2"]), 40.0)
  expect_equal(unname(result$pos_y[2, "M2"]), 50.0)
  expect_equal(unname(result$pos_z[2, "M2"]), 60.0)
})

test_that(".parse_c3d_wide handles single marker", {
  wide_df <- data.frame(
    SOLO_x = c(100.0, 200.0, 300.0),
    SOLO_y = c(110.0, 210.0, 310.0),
    SOLO_z = c(120.0, 220.0, 320.0)
  )
  result <- PhysioMoCap:::.parse_c3d_wide(wide_df)

  expect_equal(result$marker_names, "SOLO")
  expect_equal(dim(result$pos_x), c(3, 1))
})

test_that(".parse_c3d_wide errors on missing Y columns", {
  wide_df <- data.frame(
    M1_x = c(1.0, 2.0),
    M1_z = c(3.0, 4.0)
  )
  expect_error(
    PhysioMoCap:::.parse_c3d_wide(wide_df),
    "Missing Y coordinates"
  )
})

test_that(".parse_c3d_wide errors on empty data", {
  wide_df <- data.frame(col1 = c(1.0, 2.0), col2 = c(3.0, 4.0))
  expect_error(
    PhysioMoCap:::.parse_c3d_wide(wide_df),
    "No marker data found"
  )
})


# ===========================================================================
# Integration tests (require c3dr)
# ===========================================================================

test_that("readC3D returns PhysioExperiment with correct assays", {
  skip_if_not_installed("c3dr")
  c3d_file <- c3dr::c3d_example()

  pe <- readC3D(c3d_file)

  expect_s4_class(pe, "PhysioExperiment")
  assay_names <- SummarizedExperiment::assayNames(pe)
  expect_true("position_x" %in% assay_names)
  expect_true("position_y" %in% assay_names)
  expect_true("position_z" %in% assay_names)
})

test_that("readC3D returns correct dimensions", {
  skip_if_not_installed("c3dr")
  c3d_file <- c3dr::c3d_example()

  pe <- readC3D(c3d_file)

  # Example file has 340 frames and 55 markers
  px <- SummarizedExperiment::assay(pe, "position_x")
  expect_equal(nrow(px), 340)
  expect_equal(ncol(px), 55)
  expect_equal(PhysioCore::nChannels(pe), 55)
})

test_that("readC3D extracts marker names from POINT:LABELS", {
  skip_if_not_installed("c3dr")
  c3d_file <- c3dr::c3d_example()

  pe <- readC3D(c3d_file)

  marker_labels <- PhysioCore::channelNames(pe)
  # Verify first few known markers from the example file
  expect_true("L_IAS" %in% marker_labels)
  expect_true("R_IAS" %in% marker_labels)
  expect_true("CV7" %in% marker_labels)
})

test_that("readC3D parses sampling rate from POINT:RATE", {
  skip_if_not_installed("c3dr")
  c3d_file <- c3dr::c3d_example()

  pe <- readC3D(c3d_file)

  # Example file has POINT:RATE = 200

  expect_equal(PhysioCore::samplingRate(pe), 200)
})

test_that("readC3D colData has label, type, and body_segment columns", {
  skip_if_not_installed("c3dr")
  c3d_file <- c3dr::c3d_example()

  pe <- readC3D(c3d_file)

  cd <- SummarizedExperiment::colData(pe)
  expect_true("label" %in% colnames(cd))
  expect_true("type" %in% colnames(cd))
  expect_true("body_segment" %in% colnames(cd))
  expect_true(all(cd$type == "marker"))
  expect_true(all(is.na(cd$body_segment)))
})

test_that("readC3D metadata contains c3d_parameters, source_file, time", {
  skip_if_not_installed("c3dr")
  c3d_file <- c3dr::c3d_example()

  pe <- readC3D(c3d_file)

  md <- S4Vectors::metadata(pe)
  expect_true("c3d_parameters" %in% names(md))
  expect_true("source_file" %in% names(md))
  expect_true("time" %in% names(md))
  expect_equal(length(md$time), 340)
  expect_equal(md$time[1], 0.0)
  # Time at frame 2 should be 1/200 = 0.005
  expect_equal(md$time[2], 1 / 200, tolerance = 1e-10)
})

test_that("readC3D include_analog stores analog data in metadata", {
  skip_if_not_installed("c3dr")
  c3d_file <- c3dr::c3d_example()

  pe_no_analog <- readC3D(c3d_file, include_analog = FALSE)
  pe_with_analog <- readC3D(c3d_file, include_analog = TRUE)

  md_no <- S4Vectors::metadata(pe_no_analog)
  md_yes <- S4Vectors::metadata(pe_with_analog)

  expect_null(md_no[["analog_data"]])
  expect_true(!is.null(md_yes[["analog_data"]]))
  expect_s3_class(md_yes[["analog_data"]], "data.frame")
  # Example file has 69 analog channels, 3400 rows (340 frames * 10 subframes)
  expect_equal(nrow(md_yes[["analog_data"]]), 3400)
  expect_equal(ncol(md_yes[["analog_data"]]), 69)
})

test_that("readC3D errors on missing file", {
  expect_error(readC3D("/nonexistent/path.c3d"))
})

test_that("readC3D errors when c3dr is not available", {
  # We can only test the error message text, not the actual missing package

  # scenario since c3dr is installed. This test verifies the function signature.
  skip_if_not_installed("c3dr")
  expect_true(is.function(readC3D))
  expect_equal(names(formals(readC3D)), c("path", "include_analog"))
  expect_equal(formals(readC3D)$include_analog, FALSE)
})

# ===========================================================================
# writeC3D tests (DMIO-13)
# ===========================================================================

test_that("writeC3D requires marker position assays", {
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = matrix(rnorm(20), 10, 2)),
    colData = S4Vectors::DataFrame(label = c("a", "b")), samplingRate = 100)
  expect_error(writeC3D(pe, tempfile(fileext = ".c3d")),
               "position_x")
})

test_that("readC3D -> writeC3D -> readC3D reproduces markers and rate ratio", {
  skip_if_not_installed("c3dr")
  pe <- readC3D(c3dr::c3d_example(), include_analog = TRUE)
  out <- tempfile(fileext = ".c3d")
  writeC3D(pe, out)
  expect_true(file.exists(out))

  pe2 <- readC3D(out, include_analog = TRUE)
  # marker XYZ within 1e-4
  for (a in c("position_x", "position_y", "position_z")) {
    expect_lt(max(abs(SummarizedExperiment::assay(pe, a) -
                      SummarizedExperiment::assay(pe2, a))), 1e-4)
  }
  # marker labels preserved
  expect_equal(colnames(SummarizedExperiment::assay(pe2, "position_x")),
               colnames(SummarizedExperiment::assay(pe, "position_x")))
  # point/analog rate ratio preserved
  ratio1 <- S4Vectors::metadata(pe)$c3d_parameters$ANALOG$RATE /
    S4Vectors::metadata(pe)$c3d_parameters$POINT$RATE
  ratio2 <- S4Vectors::metadata(pe2)$c3d_parameters$ANALOG$RATE /
    S4Vectors::metadata(pe2)$c3d_parameters$POINT$RATE
  expect_equal(ratio2, ratio1)
  expect_equal(samplingRate(pe2), samplingRate(pe))
})

test_that("writeC3D writes a valid marker-only file when analog is absent", {
  skip_if_not_installed("c3dr")
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if(trc_file == "", message = "sample.trc not found")
  pe <- readTRC(trc_file)
  out <- tempfile(fileext = ".c3d")
  writeC3D(pe, out, include_analog = FALSE)
  pe2 <- readC3D(out)
  expect_lt(max(abs(SummarizedExperiment::assay(pe, "position_x") -
                    SummarizedExperiment::assay(pe2, "position_x"))), 1e-4)
  expect_equal(colnames(SummarizedExperiment::assay(pe2, "position_x")),
               colnames(SummarizedExperiment::assay(pe, "position_x")))
})

test_that("writeC3D errors on non-integer point/analog frame ratio", {
  skip_if_not_installed("c3dr")
  pe <- readC3D(c3dr::c3d_example(), include_analog = TRUE)
  # corrupt the analog block to a non-multiple row count
  md <- S4Vectors::metadata(pe)
  md$analog_data <- md$analog_data[1:(nrow(md$analog_data) - 1), , drop = FALSE]
  S4Vectors::metadata(pe) <- md
  expect_error(writeC3D(pe, tempfile(fileext = ".c3d")),
               "integer multiple")
})

test_that("writeC3D accepts a MultiRatePhysioExperiment and preserves the rate ratio", {
  skip_if_not_installed("c3dr")
  mk <- PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = matrix(rnorm(10), 5, 2),
      position_y = matrix(rnorm(10), 5, 2),
      position_z = matrix(rnorm(10), 5, 2)),
    colData = S4Vectors::DataFrame(label = c("RASI", "LASI")),
    samplingRate = 100)
  an <- PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = matrix(rnorm(20), 10, 2)),
    colData = S4Vectors::DataFrame(label = c("Fx", "Fy")), samplingRate = 200)
  mr <- PhysioCore::MultiRatePhysioExperiment(recording = mk, analog = an,
                                              offsets = c(analog = 0))
  out <- tempfile(fileext = ".c3d")
  writeC3D(mr, out)
  pe2 <- readC3D(out, include_analog = TRUE)

  expect_lt(max(abs(SummarizedExperiment::assay(mk, "position_x") -
                    SummarizedExperiment::assay(pe2, "position_x"))), 1e-4)
  # analog stream (200 Hz) is 2x the marker stream (100 Hz)
  ratio <- S4Vectors::metadata(pe2)$c3d_parameters$ANALOG$RATE /
    S4Vectors::metadata(pe2)$c3d_parameters$POINT$RATE
  expect_equal(ratio, 2)
  expect_equal(nrow(S4Vectors::metadata(pe2)$analog_data), 10)
})

# ---- regression tests for adversarial-review findings (DMIO-13) -------------

test_that("writeC3D derives a self-consistent analog rate (stale rate is ignored)", {
  skip_if_not_installed("c3dr")
  pe <- readC3D(c3dr::c3d_example(), include_analog = TRUE)
  # corrupt the declared ANALOG:RATE so it disagrees with the row count
  md <- S4Vectors::metadata(pe)
  md$c3d_parameters$ANALOG$RATE <- 999
  S4Vectors::metadata(pe) <- md
  out <- tempfile(fileext = ".c3d")
  writeC3D(pe, out)
  pe2 <- readC3D(out, include_analog = TRUE)
  # the written file must stay self-consistent: analog block not truncated,
  # rate ratio equals the true subframe count (10), not 999 / 200
  expect_equal(nrow(S4Vectors::metadata(pe2)$analog_data),
               nrow(S4Vectors::metadata(pe)$analog_data))
  ratio <- S4Vectors::metadata(pe2)$c3d_parameters$ANALOG$RATE /
    S4Vectors::metadata(pe2)$c3d_parameters$POINT$RATE
  expect_equal(ratio, 10)
})

test_that("writeC3D rejects duplicate and empty marker labels", {
  skip_if_not_installed("c3dr")
  mk_pe <- function(labels) {
    m <- matrix(as.numeric(seq_along(labels) * 2), 2, length(labels))
    colnames(m) <- labels
    PhysioExperiment(
      assays = S4Vectors::SimpleList(position_x = m, position_y = m,
                                     position_z = m),
      colData = S4Vectors::DataFrame(label = labels), samplingRate = 100)
  }
  expect_error(writeC3D(mk_pe(c("M", "M")), tempfile(fileext = ".c3d")),
               "unique")
  expect_error(writeC3D(mk_pe(c("A", "")), tempfile(fileext = ".c3d")),
               "non-empty")
})
