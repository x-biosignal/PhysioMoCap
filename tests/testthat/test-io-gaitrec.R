library(testthat)
library(PhysioMoCap)

# ===========================================================================
# Helper: create a temporary GaitRec-format GRF CSV file
# ===========================================================================

make_gaitrec_grf_csv <- function(pattern = "standard", n_rows = 10,
                                 sep = ",", file_ext = ".csv") {

  tmp <- tempfile(fileext = file_ext)

  if (pattern == "standard") {
    # Pattern 1: Fx1, Fy1, Fz1, Fx2, Fy2, Fz2
    header <- paste(c("time", "Fx1", "Fy1", "Fz1", "Fx2", "Fy2", "Fz2"),
                    collapse = sep)
    rows <- vapply(seq_len(n_rows), function(i) {
      t_val <- (i - 1) / 1000
      paste(c(sprintf("%.3f", t_val),
              sprintf("%.1f", c(10 + i, 500 + i * 2, 50 + i,
                                8 + i, 480 + i * 2, 45 + i))),
            collapse = sep)
    }, character(1))

  } else if (pattern == "fp_prefix") {
    # Pattern 2: FP1_Fx, FP1_Fy, FP1_Fz, FP2_Fx, FP2_Fy, FP2_Fz
    header <- paste(c("time", "FP1_Fx", "FP1_Fy", "FP1_Fz",
                       "FP2_Fx", "FP2_Fy", "FP2_Fz"), collapse = sep)
    rows <- vapply(seq_len(n_rows), function(i) {
      t_val <- (i - 1) / 1000
      paste(c(sprintf("%.3f", t_val),
              sprintf("%.1f", c(10 + i, 500 + i * 2, 50 + i,
                                8 + i, 480 + i * 2, 45 + i))),
            collapse = sep)
    }, character(1))

  } else if (pattern == "single_plate") {
    # Pattern 5: Fx, Fy, Fz (single force plate)
    header <- paste(c("time", "Fx", "Fy", "Fz"), collapse = sep)
    rows <- vapply(seq_len(n_rows), function(i) {
      t_val <- (i - 1) / 1000
      paste(c(sprintf("%.3f", t_val),
              sprintf("%.1f", c(10 + i, 500 + i * 2, 50 + i))),
            collapse = sep)
    }, character(1))

  } else if (pattern == "normalized") {
    # 101-point time-normalised waveforms (0-100% gait cycle)
    header <- paste(c("Fx1", "Fy1", "Fz1", "Fx2", "Fy2", "Fz2"),
                    collapse = sep)
    n_rows <- 101
    pct <- seq(0, 1, length.out = 101)
    rows <- vapply(seq_len(n_rows), function(i) {
      p <- pct[i]
      paste(sprintf("%.2f", c(
        50 * sin(pi * p), 700 * sin(pi * p), 30 * sin(pi * p),
        45 * sin(pi * p), 650 * sin(pi * p), 25 * sin(pi * p)
      )), collapse = sep)
    }, character(1))

  } else if (pattern == "grf_prefix") {
    # Pattern 4: GRF_X_1, GRF_Y_1, GRF_Z_1
    header <- paste(c("time", "GRF_X_1", "GRF_Y_1", "GRF_Z_1"),
                    collapse = sep)
    rows <- vapply(seq_len(n_rows), function(i) {
      t_val <- (i - 1) / 1000
      paste(c(sprintf("%.3f", t_val),
              sprintf("%.1f", c(10 + i, 500 + i * 2, 50 + i))),
            collapse = sep)
    }, character(1))

  } else if (pattern == "no_force") {
    # No force columns at all
    header <- paste(c("time", "angle_hip", "angle_knee"), collapse = sep)
    rows <- vapply(seq_len(n_rows), function(i) {
      t_val <- (i - 1) / 1000
      paste(c(sprintf("%.3f", t_val),
              sprintf("%.1f", c(25 + i * 0.5, 15 + i * 0.3))),
            collapse = sep)
    }, character(1))
  }

  writeLines(c(header, rows), tmp)
  tmp
}

make_gaitrec_param_csv <- function(sep = ",") {
  tmp <- tempfile(fileext = ".csv")
  header <- paste(c("subject_id", "trial", "stride_time", "stride_length",
                     "cadence", "walking_speed", "stance_pct"), collapse = sep)
  rows <- c(
    paste(c("S001", "1", "1.12", "1.35", "107.1", "1.21", "60.2"), collapse = sep),
    paste(c("S001", "2", "1.10", "1.33", "109.1", "1.21", "59.8"), collapse = sep),
    paste(c("S002", "1", "1.15", "1.28", "104.3", "1.11", "61.5"), collapse = sep)
  )
  writeLines(c(header, rows), tmp)
  tmp
}


# ===========================================================================
# readGaitRec — standard GRF format (Fx1, Fy1, Fz1, ...)
# ===========================================================================

test_that("readGaitRec reads standard GRF file and returns PhysioExperiment", {
  f <- make_gaitrec_grf_csv("standard", n_rows = 20)
  on.exit(unlink(f))

  pe <- readGaitRec(f)

  expect_s4_class(pe, "PhysioExperiment")
  expect_true("raw" %in% SummarizedExperiment::assayNames(pe))
})

test_that("readGaitRec standard format has correct dimensions", {
  f <- make_gaitrec_grf_csv("standard", n_rows = 15)
  on.exit(unlink(f))

  pe <- readGaitRec(f)
  raw <- SummarizedExperiment::assay(pe, "raw")

  # 15 rows x 6 force channels

  expect_equal(nrow(raw), 15)
  expect_equal(ncol(raw), 6)
})

test_that("readGaitRec standard format extracts correct channel labels", {
  f <- make_gaitrec_grf_csv("standard", n_rows = 5)
  on.exit(unlink(f))

  pe <- readGaitRec(f)
  cd <- SummarizedExperiment::colData(pe)

  expect_equal(as.character(cd$label), c("Fx1", "Fy1", "Fz1",
                                          "Fx2", "Fy2", "Fz2"))
  expect_equal(as.character(cd$component), c("Fx", "Fy", "Fz",
                                              "Fx", "Fy", "Fz"))
  expect_equal(cd$plate, c(1L, 1L, 1L, 2L, 2L, 2L))
  expect_true(all(cd$unit == "N"))
  expect_true(all(cd$type == "force"))
})

test_that("readGaitRec preserves data values", {
  f <- make_gaitrec_grf_csv("standard", n_rows = 5)
  on.exit(unlink(f))

  pe <- readGaitRec(f)
  raw <- SummarizedExperiment::assay(pe, "raw")

  # Row 1: Fx1 = 10 + 1 = 11.0, Fy1 = 500 + 1*2 = 502.0
  expect_equal(unname(raw[1, "Fx1"]), 11.0)
  expect_equal(unname(raw[1, "Fy1"]), 502.0)
  # Row 3: Fx2 = 8 + 3 = 11.0
  expect_equal(unname(raw[3, "Fx2"]), 11.0)
})

test_that("readGaitRec uses default sampling rate of 1000 Hz", {
  f <- make_gaitrec_grf_csv("standard", n_rows = 5)
  on.exit(unlink(f))

  pe <- readGaitRec(f)
  expect_equal(PhysioCore::samplingRate(pe), 1000)
})

test_that("readGaitRec accepts custom sampling rate", {
  f <- make_gaitrec_grf_csv("standard", n_rows = 5)
  on.exit(unlink(f))

  pe <- readGaitRec(f, sr = 2000)
  expect_equal(PhysioCore::samplingRate(pe), 2000)
})


# ===========================================================================
# readGaitRec — FP prefix format (FP1_Fx, FP1_Fy, ...)
# ===========================================================================

test_that("readGaitRec handles FP prefix format (FP1_Fx, FP2_Fx, ...)", {
  f <- make_gaitrec_grf_csv("fp_prefix", n_rows = 8)
  on.exit(unlink(f))

  pe <- readGaitRec(f)

  expect_s4_class(pe, "PhysioExperiment")
  raw <- SummarizedExperiment::assay(pe, "raw")
  expect_equal(ncol(raw), 6)

  cd <- SummarizedExperiment::colData(pe)
  expect_true(all(cd$plate %in% c(1L, 2L)))
  expect_true(all(cd$component %in% c("Fx", "Fy", "Fz")))
})


# ===========================================================================
# readGaitRec — single plate format (Fx, Fy, Fz)
# ===========================================================================

test_that("readGaitRec handles single plate format (Fx, Fy, Fz)", {
  f <- make_gaitrec_grf_csv("single_plate", n_rows = 10)
  on.exit(unlink(f))

  pe <- readGaitRec(f)

  expect_s4_class(pe, "PhysioExperiment")
  raw <- SummarizedExperiment::assay(pe, "raw")
  expect_equal(ncol(raw), 3)

  cd <- SummarizedExperiment::colData(pe)
  expect_equal(as.character(cd$component), c("Fx", "Fy", "Fz"))
  expect_equal(cd$plate, c(1L, 1L, 1L))
})


# ===========================================================================
# readGaitRec — GRF prefix format (GRF_X_1, GRF_Y_1, ...)
# ===========================================================================

test_that("readGaitRec handles GRF prefix format (GRF_X_1, GRF_Y_1, ...)", {
  f <- make_gaitrec_grf_csv("grf_prefix", n_rows = 5)
  on.exit(unlink(f))

  pe <- readGaitRec(f)

  expect_s4_class(pe, "PhysioExperiment")
  raw <- SummarizedExperiment::assay(pe, "raw")
  expect_equal(ncol(raw), 3)
})


# ===========================================================================
# readGaitRec — time-normalised 101-point waveforms
# ===========================================================================

test_that("readGaitRec detects 101-point time-normalised waveforms", {
  f <- make_gaitrec_grf_csv("normalized")
  on.exit(unlink(f))

  pe <- readGaitRec(f)
  raw <- SummarizedExperiment::assay(pe, "raw")

  expect_equal(nrow(raw), 101)
  expect_equal(ncol(raw), 6)

  md <- S4Vectors::metadata(pe)
  expect_true(md$time_normalized)
  expect_equal(length(md$percent_gait_cycle), 101)
  expect_equal(md$percent_gait_cycle[1], 0)
  expect_equal(md$percent_gait_cycle[101], 100)
})


# ===========================================================================
# readGaitRec — metadata
# ===========================================================================

test_that("readGaitRec stores correct metadata", {
  f <- make_gaitrec_grf_csv("standard", n_rows = 5)
  on.exit(unlink(f))

  pe <- readGaitRec(f, subject_id = "S001")
  md <- S4Vectors::metadata(pe)

  expect_equal(md$format, "gaitrec")
  expect_equal(md$source_file, basename(f))
  expect_equal(md$subject_id, "S001")
  expect_true("time" %in% names(md))
  expect_equal(length(md$time), 5)
})


# ===========================================================================
# readGaitRec — parameter file reading
# ===========================================================================

test_that("readGaitRec reads parameter file as data.frame", {
  f <- make_gaitrec_param_csv()
  on.exit(unlink(f))

  params <- readGaitRec(f, type = "parameters")

  expect_s3_class(params, "data.frame")
  expect_equal(nrow(params), 3)
  expect_true("subject_id" %in% names(params))
  expect_true("stride_time" %in% names(params))
  expect_true("cadence" %in% names(params))
  expect_true("source_file" %in% names(params))
})


# ===========================================================================
# readGaitRec — directory reading
# ===========================================================================

test_that("readGaitRec reads a directory of GRF files", {
  tmpdir <- tempfile("gaitrec_dir")
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  # Create two GRF files
  f1 <- file.path(tmpdir, "S001_grf.csv")
  f2 <- file.path(tmpdir, "S002_grf.csv")

  writeLines(c(
    "time,Fx1,Fy1,Fz1",
    "0.000,10.0,500.0,50.0",
    "0.001,11.0,502.0,51.0",
    "0.002,12.0,504.0,52.0"
  ), f1)
  writeLines(c(
    "time,Fx1,Fy1,Fz1",
    "0.000,15.0,510.0,55.0",
    "0.001,16.0,512.0,56.0"
  ), f2)

  result <- readGaitRec(tmpdir)

  expect_type(result, "list")
  expect_equal(length(result), 2)
  expect_true(all(vapply(result, inherits, logical(1), "PhysioExperiment")))
})

test_that("readGaitRec reads a directory of parameter files", {
  tmpdir <- tempfile("gaitrec_params")
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  f1 <- file.path(tmpdir, "params_S001.csv")
  writeLines(c(
    "subject_id,stride_time,cadence",
    "S001,1.12,107.1",
    "S001,1.10,109.1"
  ), f1)

  f2 <- file.path(tmpdir, "params_S002.csv")
  writeLines(c(
    "subject_id,stride_time,cadence",
    "S002,1.15,104.3"
  ), f2)

  params <- readGaitRec(tmpdir, type = "parameters")

  expect_s3_class(params, "data.frame")
  expect_equal(nrow(params), 3)
})


# ===========================================================================
# readGaitRec — tab-separated files
# ===========================================================================

test_that("readGaitRec handles tab-separated files", {
  f <- make_gaitrec_grf_csv("standard", n_rows = 5, sep = "\t",
                             file_ext = ".tsv")
  on.exit(unlink(f))

  pe <- readGaitRec(f, sep = "\t")

  expect_s4_class(pe, "PhysioExperiment")
  raw <- SummarizedExperiment::assay(pe, "raw")
  expect_equal(ncol(raw), 6)
  expect_equal(nrow(raw), 5)
})


# ===========================================================================
# Error handling
# ===========================================================================

test_that("readGaitRec errors on non-existent path", {
  expect_error(readGaitRec("/nonexistent/path.csv"), "does not exist")
})

test_that("readGaitRec errors on empty file", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c("time,Fx1,Fy1,Fz1"), tmp)
  on.exit(unlink(tmp))

  expect_error(readGaitRec(tmp), "empty")
})

test_that("readGaitRec errors when no force columns detected", {
  f <- make_gaitrec_grf_csv("no_force", n_rows = 5)
  on.exit(unlink(f))

  expect_error(readGaitRec(f), "No force columns")
})

test_that("readGaitRec errors on invalid path argument", {
  expect_error(readGaitRec(""), "non-empty")
  expect_error(readGaitRec(123), "character")
})

test_that("readGaitRec errors on empty directory", {
  tmpdir <- tempfile("empty_dir")
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  expect_error(readGaitRec(tmpdir), "No CSV")
})


# ===========================================================================
# Internal helper: .detect_gaitrec_force_columns
# ===========================================================================

test_that(".detect_gaitrec_force_columns detects pattern 1 (Fx1, Fy1, ...)", {
  cols <- c("time", "Fx1", "Fy1", "Fz1", "Fx2", "Fy2", "Fz2")
  result <- PhysioMoCap:::.detect_gaitrec_force_columns(cols)

  expect_equal(length(result$indices), 6)
  expect_equal(result$labels, c("Fx1", "Fy1", "Fz1", "Fx2", "Fy2", "Fz2"))
  expect_equal(result$components, c("Fx", "Fy", "Fz", "Fx", "Fy", "Fz"))
  expect_equal(result$plates, c(1L, 1L, 1L, 2L, 2L, 2L))
})

test_that(".detect_gaitrec_force_columns detects pattern 2 (FP1_Fx, ...)", {
  cols <- c("time", "FP1_Fx", "FP1_Fy", "FP1_Fz")
  result <- PhysioMoCap:::.detect_gaitrec_force_columns(cols)

  expect_equal(length(result$indices), 3)
  expect_equal(result$components, c("Fx", "Fy", "Fz"))
  expect_equal(result$plates, c(1L, 1L, 1L))
})

test_that(".detect_gaitrec_force_columns detects pattern 5 (Fx, Fy, Fz)", {
  cols <- c("time", "Fx", "Fy", "Fz")
  result <- PhysioMoCap:::.detect_gaitrec_force_columns(cols)

  expect_equal(length(result$indices), 3)
  expect_equal(result$components, c("Fx", "Fy", "Fz"))
  expect_equal(result$plates, c(1L, 1L, 1L))
})

test_that(".detect_gaitrec_force_columns returns empty on non-force columns", {
  cols <- c("time", "hip_angle", "knee_angle")
  result <- PhysioMoCap:::.detect_gaitrec_force_columns(cols)

  expect_equal(length(result$indices), 0)
})
