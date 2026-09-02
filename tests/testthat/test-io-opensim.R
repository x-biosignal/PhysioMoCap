library(testthat)
library(PhysioMoCap)

# ===========================================================================
# readMOT tests
# ===========================================================================

test_that("readMOT handles header correctly", {
  tmp <- tempfile(fileext = ".mot")
  writeLines(c(
    "Coordinates",
    "version=1",
    "nRows=3",
    "nColumns=4",
    "inDegrees=yes",
    "endheader",
    "time\thip_flexion_r\tknee_angle_r\tankle_angle_r",
    "0.0\t25.0\t-5.0\t10.0",
    "0.01\t24.5\t-4.8\t9.5",
    "0.02\t24.0\t-4.6\t9.0"
  ), tmp)
  pe <- readMOT(tmp)
  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::nChannels(pe), 3)
  unlink(tmp)
})

test_that("readMOT reads sample.mot from inst/testdata", {
  mot_file <- system.file("testdata", "sample.mot", package = "PhysioMoCap")
  skip_if(mot_file == "", message = "sample.mot not found")

  pe <- readMOT(mot_file)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(nrow(SummarizedExperiment::assay(pe, "raw")), 5)
  expect_equal(ncol(SummarizedExperiment::assay(pe, "raw")), 3)
  expect_equal(
    PhysioCore::channelNames(pe),
    c("hip_flexion_r", "knee_angle_r", "ankle_angle_r")
  )
})

test_that("readMOT computes correct sampling rate", {
  tmp <- tempfile(fileext = ".mot")
  writeLines(c(
    "Test",
    "endheader",
    "time\tcol1\tcol2",
    "0.0\t1.0\t2.0",
    "0.01\t1.1\t2.1",
    "0.02\t1.2\t2.2",
    "0.03\t1.3\t2.3"
  ), tmp)
  pe <- readMOT(tmp)
  expect_equal(PhysioCore::samplingRate(pe), 100)
  unlink(tmp)
})

test_that("readMOT preserves data values", {
  tmp <- tempfile(fileext = ".mot")
  writeLines(c(
    "Coordinates",
    "endheader",
    "time\ta\tb",
    "0.0\t1.5\t2.5",
    "0.1\t3.5\t4.5"
  ), tmp)
  pe <- readMOT(tmp)
  raw <- SummarizedExperiment::assay(pe, "raw")
  expect_equal(unname(raw[1, "a"]), 1.5)
  expect_equal(unname(raw[1, "b"]), 2.5)
  expect_equal(unname(raw[2, "a"]), 3.5)
  expect_equal(unname(raw[2, "b"]), 4.5)
  unlink(tmp)
})

test_that("readMOT stores metadata correctly", {
  tmp <- tempfile(fileext = ".mot")
  writeLines(c(
    "Coordinates",
    "version=1",
    "nRows=2",
    "nColumns=3",
    "inDegrees=yes",
    "endheader",
    "time\tx\ty",
    "0.0\t1.0\t2.0",
    "0.01\t1.1\t2.1"
  ), tmp)
  pe <- readMOT(tmp)
  md <- S4Vectors::metadata(pe)
  expect_equal(md[["format"]], "mot")
  expect_equal(md[["inDegrees"]], "yes")
  expect_equal(md[["version"]], 1)
  expect_true(!is.null(md[["time"]]))
  expect_equal(length(md[["time"]]), 2)
  unlink(tmp)
})

test_that("readMOT errors on missing endheader", {
  tmp <- tempfile(fileext = ".mot")
  writeLines(c(
    "time\tx",
    "0.0\t1.0"
  ), tmp)
  expect_error(readMOT(tmp), "endheader")
  unlink(tmp)
})

test_that("readMOT errors on missing file", {
  expect_error(readMOT("/nonexistent/path.mot"))
})


# ===========================================================================
# readSTO tests
# ===========================================================================

test_that("readSTO reads sample.sto from inst/testdata", {
  sto_file <- system.file("testdata", "sample.sto", package = "PhysioMoCap")
  skip_if(sto_file == "", message = "sample.sto not found")

  pe <- readSTO(sto_file)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(nrow(SummarizedExperiment::assay(pe, "raw")), 5)
  expect_equal(ncol(SummarizedExperiment::assay(pe, "raw")), 2)
  expect_equal(
    PhysioCore::channelNames(pe),
    c("ground_force_vx", "ground_force_vy")
  )
})

test_that("readSTO preserves data values", {
  sto_file <- system.file("testdata", "sample.sto", package = "PhysioMoCap")
  skip_if(sto_file == "", message = "sample.sto not found")

  pe <- readSTO(sto_file)
  raw <- SummarizedExperiment::assay(pe, "raw")

  expect_equal(unname(raw[1, "ground_force_vx"]), 100.5)
  expect_equal(unname(raw[1, "ground_force_vy"]), 750.2)
})

test_that("readSTO stores format metadata as sto", {
  tmp <- tempfile(fileext = ".sto")
  writeLines(c(
    "Storage",
    "endheader",
    "time\tforce_x",
    "0.0\t10.0",
    "0.001\t11.0"
  ), tmp)
  pe <- readSTO(tmp)
  md <- S4Vectors::metadata(pe)
  expect_equal(md[["format"]], "sto")
  expect_equal(PhysioCore::samplingRate(pe), 1000)
  unlink(tmp)
})


# ===========================================================================
# readTRC tests
# ===========================================================================

test_that("readTRC reads sample.trc from inst/testdata", {
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if(trc_file == "", message = "sample.trc not found")

  pe <- readTRC(trc_file)

  expect_s4_class(pe, "PhysioExperiment")
  expect_true("position_x" %in% SummarizedExperiment::assayNames(pe))
  expect_true("position_y" %in% SummarizedExperiment::assayNames(pe))
  expect_true("position_z" %in% SummarizedExperiment::assayNames(pe))
})

test_that("readTRC returns correct dimensions", {
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if(trc_file == "", message = "sample.trc not found")

  pe <- readTRC(trc_file)

  # 5 frames, 2 markers

  expect_equal(nrow(SummarizedExperiment::assay(pe, "position_x")), 5)
  expect_equal(ncol(SummarizedExperiment::assay(pe, "position_x")), 2)
  expect_equal(PhysioCore::nChannels(pe), 2)
})

test_that("readTRC extracts marker names correctly", {
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if(trc_file == "", message = "sample.trc not found")

  pe <- readTRC(trc_file)
  expect_equal(PhysioCore::channelNames(pe), c("RASI", "LASI"))
})

test_that("readTRC computes correct sampling rate from DataRate", {
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if(trc_file == "", message = "sample.trc not found")

  pe <- readTRC(trc_file)
  expect_equal(PhysioCore::samplingRate(pe), 120.0)
})

test_that("readTRC preserves coordinate values", {
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if(trc_file == "", message = "sample.trc not found")

  pe <- readTRC(trc_file)
  px <- SummarizedExperiment::assay(pe, "position_x")
  py <- SummarizedExperiment::assay(pe, "position_y")
  pz <- SummarizedExperiment::assay(pe, "position_z")

  # First marker (RASI), first frame
  expect_equal(unname(px[1, "RASI"]), 100.5)
  expect_equal(unname(py[1, "RASI"]), 200.3)
  expect_equal(unname(pz[1, "RASI"]), 300.1)

  # Second marker (LASI), first frame
  expect_equal(unname(px[1, "LASI"]), 110.2)
  expect_equal(unname(py[1, "LASI"]), 210.4)
  expect_equal(unname(pz[1, "LASI"]), 310.6)
})

test_that("readTRC stores time in metadata", {
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if(trc_file == "", message = "sample.trc not found")

  pe <- readTRC(trc_file)
  md <- S4Vectors::metadata(pe)
  expect_true(!is.null(md[["time"]]))
  expect_equal(length(md[["time"]]), 5)
  expect_equal(md[["time"]][1], 0.0)
})

test_that("readTRC stores header metadata", {
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if(trc_file == "", message = "sample.trc not found")

  pe <- readTRC(trc_file)
  md <- S4Vectors::metadata(pe)
  expect_equal(md[["format"]], "trc")
  expect_equal(md[["Units"]], "mm")
  expect_equal(md[["NumMarkers"]], 2)
  expect_equal(md[["NumFrames"]], 5)
})

test_that("readTRC handles temp file with known data", {
  tmp <- tempfile(fileext = ".trc")
  writeLines(c(
    "PathFileType\t4\t(X/Y/Z)\ttest.trc",
    "DataRate\tCameraRate\tNumFrames\tNumMarkers\tUnits\tOrigDataRate\tOrigDataStartFrame\tOrigNumFrames",
    "60.0\t60.0\t2\t1\tm\t60.0\t1\t2",
    "Frame#\tTime\tMARKER1",
    "\t\tX1\tY1\tZ1",
    "1\t0.0\t1.0\t2.0\t3.0",
    "2\t0.01667\t4.0\t5.0\t6.0"
  ), tmp)

  pe <- readTRC(tmp)
  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::nChannels(pe), 1)
  expect_equal(PhysioCore::channelNames(pe), "MARKER1")
  expect_equal(PhysioCore::samplingRate(pe), 60.0)

  px <- SummarizedExperiment::assay(pe, "position_x")
  expect_equal(unname(px[1, 1]), 1.0)
  expect_equal(unname(px[2, 1]), 4.0)
  unlink(tmp)
})

test_that("readTRC errors on file too short", {
  tmp <- tempfile(fileext = ".trc")
  writeLines(c("Line1", "Line2"), tmp)
  expect_error(readTRC(tmp), "too short")
  unlink(tmp)
})

test_that("readTRC errors on missing file", {
  expect_error(readTRC("/nonexistent/path.trc"))
})


# ===========================================================================
# Edge cases
# ===========================================================================

test_that("readMOT handles minimal file with single data column", {
  tmp <- tempfile(fileext = ".mot")
  writeLines(c(
    "Minimal",
    "endheader",
    "time\tsignal",
    "0.0\t42.0",
    "0.5\t43.0",
    "1.0\t44.0"
  ), tmp)
  pe <- readMOT(tmp)
  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::nChannels(pe), 1)
  expect_equal(PhysioCore::samplingRate(pe), 2.0)
  expect_equal(PhysioCore::channelNames(pe), "signal")
  unlink(tmp)
})

test_that("readMOT handles extra blank lines", {
  tmp <- tempfile(fileext = ".mot")
  writeLines(c(
    "Test",
    "endheader",
    "time\tx",
    "",
    "0.0\t1.0",
    "",
    "0.1\t2.0",
    ""
  ), tmp)
  pe <- readMOT(tmp)
  expect_equal(nrow(SummarizedExperiment::assay(pe, "raw")), 2)
  unlink(tmp)
})

test_that("readMOT stores time vector in metadata", {
  tmp <- tempfile(fileext = ".mot")
  writeLines(c(
    "Test",
    "endheader",
    "time\ta",
    "0.0\t1.0",
    "0.5\t2.0",
    "1.0\t3.0"
  ), tmp)
  pe <- readMOT(tmp)
  md <- S4Vectors::metadata(pe)
  expect_equal(md[["time"]], c(0.0, 0.5, 1.0))
  unlink(tmp)
})

# ===========================================================================
# writeTRC / writeMOT tests (DMIO-13)
# ===========================================================================

test_that("readTRC -> writeTRC -> readTRC reproduces markers exactly", {
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if(trc_file == "", message = "sample.trc not found")
  pe <- readTRC(trc_file)
  out <- tempfile(fileext = ".trc")
  writeTRC(pe, out)
  pe2 <- readTRC(out)

  for (a in c("position_x", "position_y", "position_z")) {
    # expect_equal, not expect_identical: writing/reading numeric data through a
    # decimal ASCII file recovers the values to full double precision on a
    # correctly-rounded libc (glibc) but only to ~1 ULP on others (macOS's
    # printf/strtod), so a bit-identical round-trip is not portable. The
    # meaningful, portable guarantee is numerical equality.
    expect_equal(unname(SummarizedExperiment::assay(pe2, a)),
                 unname(SummarizedExperiment::assay(pe, a)))
  }
  expect_equal(samplingRate(pe2), samplingRate(pe))
  expect_equal(S4Vectors::metadata(pe2)$DataRate,
               S4Vectors::metadata(pe)$DataRate)
  expect_equal(S4Vectors::metadata(pe2)$Units, S4Vectors::metadata(pe)$Units)
  expect_equal(colnames(SummarizedExperiment::assay(pe2, "position_x")),
               colnames(SummarizedExperiment::assay(pe, "position_x")))
})

test_that("writeTRC preserves the time column", {
  trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
  skip_if(trc_file == "", message = "sample.trc not found")
  pe <- readTRC(trc_file)
  out <- tempfile(fileext = ".trc")
  writeTRC(pe, out)
  pe2 <- readTRC(out)
  expect_equal(S4Vectors::metadata(pe2)$time, S4Vectors::metadata(pe)$time)
})

test_that("writeTRC requires marker position assays", {
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = matrix(rnorm(20), 10, 2)),
    colData = S4Vectors::DataFrame(label = c("a", "b")), samplingRate = 100)
  expect_error(writeTRC(pe, tempfile(fileext = ".trc")), "position_x")
})

test_that("readMOT -> writeMOT -> readMOT reproduces columns exactly", {
  mot_file <- system.file("testdata", "sample.mot", package = "PhysioMoCap")
  skip_if(mot_file == "", message = "sample.mot not found")
  pe <- readMOT(mot_file)
  out <- tempfile(fileext = ".mot")
  writeMOT(pe, out)
  pe2 <- readMOT(out)

  # numeric (not bit-identical) round-trip: decimal ASCII recovery is exact on
  # glibc but ~1 ULP on macOS's libc, so assert numerical equality.
  expect_equal(unname(SummarizedExperiment::assay(pe2, "raw")),
               unname(SummarizedExperiment::assay(pe, "raw")))
  expect_equal(samplingRate(pe2), samplingRate(pe))
  expect_equal(colnames(SummarizedExperiment::assay(pe2, "raw")),
               colnames(SummarizedExperiment::assay(pe, "raw")))
  # inDegrees flag preserved
  expect_equal(S4Vectors::metadata(pe2)$inDegrees,
               S4Vectors::metadata(pe)$inDegrees)
})

test_that("writeMOT round-trips a synthetic object with an explicit time column", {
  set.seed(1)
  dat <- matrix(rnorm(30), 10, 3)
  colnames(dat) <- c("q1", "q2", "q3")
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = dat),
    colData = S4Vectors::DataFrame(label = colnames(dat)),
    metadata = list(time = seq(0, by = 0.02, length.out = 10),
                    inDegrees = "no"),
    samplingRate = 50)
  out <- tempfile(fileext = ".mot")
  writeMOT(pe, out)
  pe2 <- readMOT(out)
  # numeric (not bit-identical) round-trip — decimal ASCII recovery is ~1 ULP on
  # macOS's libc, so assert numerical equality (data preserved to full precision)
  expect_equal(unname(SummarizedExperiment::assay(pe2, "raw")), unname(dat))
  expect_equal(S4Vectors::metadata(pe2)$time,
               S4Vectors::metadata(pe)$time)
  expect_equal(S4Vectors::metadata(pe2)$inDegrees, "no")
})

# ---- regression tests for adversarial-review findings (DMIO-13) -------------

test_that("writeTRC rejects empty and duplicate marker labels", {
  mk_pe <- function(labels) {
    m <- matrix(as.numeric(seq_along(labels)), 2, length(labels))
    colnames(m) <- labels
    PhysioExperiment(
      assays = S4Vectors::SimpleList(position_x = m, position_y = m,
                                     position_z = m),
      colData = S4Vectors::DataFrame(label = labels), samplingRate = 100)
  }
  expect_error(writeTRC(mk_pe(c("A", "")), tempfile(fileext = ".trc")),
               "non-empty")
  expect_error(writeTRC(mk_pe(c("M", "M")), tempfile(fileext = ".trc")),
               "unique")
})

test_that("readMOT captures the name line and writeMOT round-trips it", {
  mot_file <- system.file("testdata", "sample.mot", package = "PhysioMoCap")
  skip_if(mot_file == "", message = "sample.mot not found")
  pe <- readMOT(mot_file)
  expect_true(nzchar(S4Vectors::metadata(pe)$name %||% ""))
  out <- tempfile(fileext = ".mot")
  writeMOT(pe, out)
  pe2 <- readMOT(out)
  expect_equal(S4Vectors::metadata(pe2)$name, S4Vectors::metadata(pe)$name)
})

test_that("writeMOT neutralises '=' in the name so it is not misread as a key", {
  dat <- matrix(rnorm(6), 3, 2)
  colnames(dat) <- c("a", "b")
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = dat),
    colData = S4Vectors::DataFrame(label = c("a", "b")),
    metadata = list(name = "my=trial", time = c(0, 0.1, 0.2)),
    samplingRate = 10)
  out <- tempfile(fileext = ".mot")
  writeMOT(pe, out)
  pe2 <- readMOT(out)
  expect_null(S4Vectors::metadata(pe2)$my)          # no spurious key
  # numeric (not bit-identical) round-trip — decimal ASCII recovery is ~1 ULP on
  # macOS's libc, so assert numerical equality (data preserved to full precision)
  expect_equal(unname(SummarizedExperiment::assay(pe2, "raw")), unname(dat))
})
