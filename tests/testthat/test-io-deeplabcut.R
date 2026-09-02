library(testthat)
library(PhysioMoCap)

# Helper: create a DLC CSV file with specified bodyparts
write_dlc_csv <- function(file_path, bodyparts, n_frames = 3,
                          scorer = "DLC_model", seed = 42) {
  n_bp <- length(bodyparts)
  # Build 3-row multi-level header
  # Each bodypart has 3 columns: x, y, likelihood
  scorer_cols <- rep(scorer, n_bp * 3)
  bp_cols <- rep(bodyparts, each = 3)
  coord_cols <- rep(c("x", "y", "likelihood"), n_bp)

  header1 <- paste(c("scorer", scorer_cols), collapse = ",")
  header2 <- paste(c("bodyparts", bp_cols), collapse = ",")
  header3 <- paste(c("coords", coord_cols), collapse = ",")

  set.seed(seed)
  data_lines <- vapply(seq_len(n_frames), function(i) {
    vals <- c()
    for (bp in bodyparts) {
      x <- round(runif(1, 50, 500), 1)
      y <- round(runif(1, 50, 500), 1)
      like <- round(runif(1, 0.5, 1.0), 2)
      vals <- c(vals, x, y, like)
    }
    paste(c(i - 1, vals), collapse = ",")
  }, character(1))

  lines <- c(header1, header2, header3, data_lines)
  writeLines(lines, file_path)
}


# --- Tests ---

test_that("readDeepLabCut reads sample CSV file with correct structure", {
  sample_path <- system.file("testdata", "sample_dlc.csv", package = "PhysioMoCap")
  skip_if(sample_path == "", message = "sample_dlc.csv not found in testdata")

  pe <- readDeepLabCut(sample_path, fps = 30, format = "csv")

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::samplingRate(pe), 30)

  # All three assays present
  anames <- SummarizedExperiment::assayNames(pe)
  expect_true("keypoint_x" %in% anames)
  expect_true("keypoint_y" %in% anames)
  expect_true("confidence" %in% anames)
})


test_that("readDeepLabCut extracts bodypart names correctly from CSV", {
  sample_path <- system.file("testdata", "sample_dlc.csv", package = "PhysioMoCap")
  skip_if(sample_path == "", message = "sample_dlc.csv not found in testdata")

  pe <- readDeepLabCut(sample_path, fps = 30)

  cd <- SummarizedExperiment::colData(pe)
  expect_equal(as.character(cd$label), c("nose", "left_ear"))
  expect_true(all(cd$type == "keypoint"))
  expect_true(all(cd$scorer == "DLC_model"))
})


test_that("readDeepLabCut multi-level header parsed correctly", {
  sample_path <- system.file("testdata", "sample_dlc.csv", package = "PhysioMoCap")
  skip_if(sample_path == "", message = "sample_dlc.csv not found in testdata")

  pe <- readDeepLabCut(sample_path, fps = 30)

  # Column names on assays should be bodypart names
  x_cols <- colnames(SummarizedExperiment::assay(pe, "keypoint_x"))
  expect_equal(x_cols, c("nose", "left_ear"))

  y_cols <- colnames(SummarizedExperiment::assay(pe, "keypoint_y"))
  expect_equal(y_cols, c("nose", "left_ear"))

  conf_cols <- colnames(SummarizedExperiment::assay(pe, "confidence"))
  expect_equal(conf_cols, c("nose", "left_ear"))
})


test_that("readDeepLabCut assay dimensions match n_frames x n_bodyparts", {
  sample_path <- system.file("testdata", "sample_dlc.csv", package = "PhysioMoCap")
  skip_if(sample_path == "", message = "sample_dlc.csv not found in testdata")

  pe <- readDeepLabCut(sample_path, fps = 30)

  # Sample file has 3 frames and 2 bodyparts (nose, left_ear)
  kp_x <- SummarizedExperiment::assay(pe, "keypoint_x")
  expect_equal(nrow(kp_x), 3)
  expect_equal(ncol(kp_x), 2)

  kp_y <- SummarizedExperiment::assay(pe, "keypoint_y")
  expect_equal(dim(kp_y), c(3, 2))

  conf <- SummarizedExperiment::assay(pe, "confidence")
  expect_equal(dim(conf), c(3, 2))
})


test_that("readDeepLabCut extracts correct coordinate values from sample CSV", {
  sample_path <- system.file("testdata", "sample_dlc.csv", package = "PhysioMoCap")
  skip_if(sample_path == "", message = "sample_dlc.csv not found in testdata")

  pe <- readDeepLabCut(sample_path, fps = 30)

  kp_x <- SummarizedExperiment::assay(pe, "keypoint_x")
  kp_y <- SummarizedExperiment::assay(pe, "keypoint_y")
  conf <- SummarizedExperiment::assay(pe, "confidence")

  # First frame, nose: x=120.5, y=80.3, likelihood=0.99
  expect_equal(unname(kp_x[1, "nose"]), 120.5)
  expect_equal(unname(kp_y[1, "nose"]), 80.3)
  expect_equal(unname(conf[1, "nose"]), 0.99)

  # First frame, left_ear: x=115.2, y=75.1, likelihood=0.95
  expect_equal(unname(kp_x[1, "left_ear"]), 115.2)
  expect_equal(unname(kp_y[1, "left_ear"]), 75.1)
  expect_equal(unname(conf[1, "left_ear"]), 0.95)

  # Third frame, nose: x=121.5, y=80.7, likelihood=0.97
  expect_equal(unname(kp_x[3, "nose"]), 121.5)
  expect_equal(unname(kp_y[3, "nose"]), 80.7)
  expect_equal(unname(conf[3, "nose"]), 0.97)
})


test_that("readDeepLabCut confidence values are in [0, 1]", {
  sample_path <- system.file("testdata", "sample_dlc.csv", package = "PhysioMoCap")
  skip_if(sample_path == "", message = "sample_dlc.csv not found in testdata")

  pe <- readDeepLabCut(sample_path, fps = 30)

  conf <- SummarizedExperiment::assay(pe, "confidence")
  expect_true(all(conf >= 0 & conf <= 1))
})


test_that("readDeepLabCut fps parameter sets samplingRate", {
  sample_path <- system.file("testdata", "sample_dlc.csv", package = "PhysioMoCap")
  skip_if(sample_path == "", message = "sample_dlc.csv not found in testdata")

  pe_30 <- readDeepLabCut(sample_path, fps = 30)
  expect_equal(PhysioCore::samplingRate(pe_30), 30)

  pe_60 <- readDeepLabCut(sample_path, fps = 60)
  expect_equal(PhysioCore::samplingRate(pe_60), 60)

  pe_120 <- readDeepLabCut(sample_path, fps = 120)
  expect_equal(PhysioCore::samplingRate(pe_120), 120)
})


test_that("readDeepLabCut metadata contains expected fields", {
  sample_path <- system.file("testdata", "sample_dlc.csv", package = "PhysioMoCap")
  skip_if(sample_path == "", message = "sample_dlc.csv not found in testdata")

  pe <- readDeepLabCut(sample_path, fps = 30)

  md <- S4Vectors::metadata(pe)
  expect_true("dlc_scorer" %in% names(md))
  expect_true("format" %in% names(md))
  expect_true("source_file" %in% names(md))

  expect_equal(md$dlc_scorer, "DLC_model")
  expect_equal(md$format, "csv")
})


test_that("readDeepLabCut reads generated CSV with many bodyparts", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))

  bodyparts <- c("nose", "left_ear", "right_ear", "left_eye", "right_eye",
                 "tail_base", "tail_tip")
  write_dlc_csv(tmp, bodyparts, n_frames = 10, scorer = "MyDLCModel")


  pe <- readDeepLabCut(tmp, fps = 25)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::samplingRate(pe), 25)

  kp_x <- SummarizedExperiment::assay(pe, "keypoint_x")
  expect_equal(nrow(kp_x), 10)
  expect_equal(ncol(kp_x), 7)

  cd <- SummarizedExperiment::colData(pe)
  expect_equal(as.character(cd$label), bodyparts)
  expect_true(all(cd$scorer == "MyDLCModel"))
})


test_that("readDeepLabCut handles single bodypart", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))

  write_dlc_csv(tmp, bodyparts = "nose", n_frames = 5)

  pe <- readDeepLabCut(tmp, fps = 30)

  expect_s4_class(pe, "PhysioExperiment")

  kp_x <- SummarizedExperiment::assay(pe, "keypoint_x")
  expect_equal(nrow(kp_x), 5)
  expect_equal(ncol(kp_x), 1)

  cd <- SummarizedExperiment::colData(pe)
  expect_equal(as.character(cd$label), "nose")
})


test_that("readDeepLabCut handles CSV without likelihood columns", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))

  # Write a CSV with only x, y (no likelihood) - some DLC configs output this
  lines <- c(
    "scorer,DLC_model,DLC_model,DLC_model,DLC_model",
    "bodyparts,nose,nose,tail,tail",
    "coords,x,y,x,y",
    "0,100.0,200.0,300.0,400.0",
    "1,101.0,201.0,301.0,401.0"
  )
  writeLines(lines, tmp)

  pe <- readDeepLabCut(tmp, fps = 30)

  expect_s4_class(pe, "PhysioExperiment")

  kp_x <- SummarizedExperiment::assay(pe, "keypoint_x")
  expect_equal(unname(kp_x[1, "nose"]), 100.0)
  expect_equal(unname(kp_x[1, "tail"]), 300.0)

  kp_y <- SummarizedExperiment::assay(pe, "keypoint_y")
  expect_equal(unname(kp_y[1, "nose"]), 200.0)

  # Confidence should be NA since no likelihood columns exist
  conf <- SummarizedExperiment::assay(pe, "confidence")
  expect_true(all(is.na(conf)))
})


test_that("readDeepLabCut errors on non-existent file", {
  expect_error(readDeepLabCut("/nonexistent/path/dlc.csv"),
               "File does not exist")
})


test_that("readDeepLabCut validates fps argument", {
  sample_path <- system.file("testdata", "sample_dlc.csv", package = "PhysioMoCap")
  skip_if(sample_path == "", message = "sample_dlc.csv not found in testdata")

  expect_error(readDeepLabCut(sample_path, fps = -1))
  expect_error(readDeepLabCut(sample_path, fps = 0))
  expect_error(readDeepLabCut(sample_path, fps = "abc"))
})


test_that("readDeepLabCut errors on invalid CSV (too few header rows)", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))

  writeLines(c("scorer,DLC_model", "bodyparts,nose"), tmp)

  expect_error(readDeepLabCut(tmp, fps = 30),
               "at least 3 header rows")
})


test_that("readDeepLabCut H5 format requires rhdf5", {
  skip_if_not_installed("rhdf5")

  # If rhdf5 is installed, we cannot easily test the error.
  # Instead, test that format = "h5" is accepted as a valid argument
  # by checking that it would attempt to read the file (and fail on
  # file structure, not on format validation)
  tmp <- tempfile(fileext = ".h5")
  on.exit(unlink(tmp))
  writeLines("not a real h5 file", tmp)

  # Should fail on H5 parsing, not on format validation
  expect_error(readDeepLabCut(tmp, fps = 30, format = "h5"))
})


test_that("readDeepLabCut H5 format errors when rhdf5 not installed", {
  # This test is only meaningful when rhdf5 is NOT installed
  skip_if(requireNamespace("rhdf5", quietly = TRUE),
          "rhdf5 is installed, cannot test missing-package error")

  tmp <- tempfile(fileext = ".h5")
  on.exit(unlink(tmp))
  writeLines("placeholder", tmp)

  expect_error(readDeepLabCut(tmp, fps = 30, format = "h5"),
               "rhdf5")
})


test_that("readDeepLabCut data values are numeric", {
  sample_path <- system.file("testdata", "sample_dlc.csv", package = "PhysioMoCap")
  skip_if(sample_path == "", message = "sample_dlc.csv not found in testdata")

  pe <- readDeepLabCut(sample_path, fps = 30)

  kp_x <- SummarizedExperiment::assay(pe, "keypoint_x")
  kp_y <- SummarizedExperiment::assay(pe, "keypoint_y")
  conf <- SummarizedExperiment::assay(pe, "confidence")

  expect_true(is.numeric(kp_x))
  expect_true(is.numeric(kp_y))
  expect_true(is.numeric(conf))
})
