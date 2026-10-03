library(testthat)
library(PhysioMoCap)

# ===========================================================================
# readVenus3D — basic reading from sample file
# ===========================================================================

test_that("readVenus3D reads sample_venus3d.csv and returns PhysioExperiment", {
  v3d_file <- system.file("testdata", "sample_venus3d.csv", package = "PhysioMoCap")
  skip_if(v3d_file == "", message = "sample_venus3d.csv not found")

  pe <- readVenus3D(v3d_file)
  expect_s4_class(pe, "PhysioExperiment")
})

test_that("readVenus3D produces position_x, position_y, position_z assays", {
  v3d_file <- system.file("testdata", "sample_venus3d.csv", package = "PhysioMoCap")
  skip_if(v3d_file == "", message = "sample_venus3d.csv not found")

  pe <- readVenus3D(v3d_file)
  anames <- SummarizedExperiment::assayNames(pe)

  expect_true("position_x" %in% anames)
  expect_true("position_y" %in% anames)
  expect_true("position_z" %in% anames)
})

test_that("readVenus3D has correct dimensions (5 frames x 3 markers)", {
  v3d_file <- system.file("testdata", "sample_venus3d.csv", package = "PhysioMoCap")
  skip_if(v3d_file == "", message = "sample_venus3d.csv not found")

  pe <- readVenus3D(v3d_file)
  px <- SummarizedExperiment::assay(pe, "position_x")

  expect_equal(nrow(px), 5)
  expect_equal(ncol(px), 3)
})

test_that("readVenus3D preserves data values correctly", {
  v3d_file <- system.file("testdata", "sample_venus3d.csv", package = "PhysioMoCap")
  skip_if(v3d_file == "", message = "sample_venus3d.csv not found")

  pe <- readVenus3D(v3d_file)
  px <- SummarizedExperiment::assay(pe, "position_x")
  py <- SummarizedExperiment::assay(pe, "position_y")
  pz <- SummarizedExperiment::assay(pe, "position_z")

  # Frame 1, marker 1 (P1): 100.5, 200.3, 300.1
  expect_equal(unname(px[1, 1]), 100.5)
  expect_equal(unname(py[1, 1]), 200.3)
  expect_equal(unname(pz[1, 1]), 300.1)

  # Frame 1, marker 2 (P2): 110.2, 210.4, 310.6
  expect_equal(unname(px[1, 2]), 110.2)
  expect_equal(unname(py[1, 2]), 210.4)
  expect_equal(unname(pz[1, 2]), 310.6)

  # Frame 5, marker 3 (P3): 122.8, 221.7, 321.1
  expect_equal(unname(px[5, 3]), 122.8)
  expect_equal(unname(py[5, 3]), 221.7)
  expect_equal(unname(pz[5, 3]), 321.1)
})


# ===========================================================================
# Metadata parsing
# ===========================================================================

test_that("readVenus3D extracts correct sampling rate from header", {
  v3d_file <- system.file("testdata", "sample_venus3d.csv", package = "PhysioMoCap")
  skip_if(v3d_file == "", message = "sample_venus3d.csv not found")

  pe <- readVenus3D(v3d_file)
  expect_equal(PhysioCore::samplingRate(pe), 120.0)
})

test_that("readVenus3D stores metadata fields correctly", {
  v3d_file <- system.file("testdata", "sample_venus3d.csv", package = "PhysioMoCap")
  skip_if(v3d_file == "", message = "sample_venus3d.csv not found")

  pe <- readVenus3D(v3d_file)
  md <- S4Vectors::metadata(pe)

  expect_equal(md$format, "venus3d")
  expect_equal(md$source_file, "sample_venus3d.csv")
  expect_equal(md$format_version, 8L)
  expect_equal(md$units, "mm")
  expect_equal(md$coordinate_system, "Y-Up")
})

test_that("readVenus3D extracts time vector", {
  v3d_file <- system.file("testdata", "sample_venus3d.csv", package = "PhysioMoCap")
  skip_if(v3d_file == "", message = "sample_venus3d.csv not found")

  pe <- readVenus3D(v3d_file)
  md <- S4Vectors::metadata(pe)

  expect_true("time" %in% names(md))
  expect_equal(length(md$time), 5)
  expect_equal(md$time[1], 0.0)
  expect_true(md$time[5] > 0.03)
})


# ===========================================================================
# colData validation
# ===========================================================================

test_that("readVenus3D colData has label and type columns", {
  v3d_file <- system.file("testdata", "sample_venus3d.csv", package = "PhysioMoCap")
  skip_if(v3d_file == "", message = "sample_venus3d.csv not found")

  pe <- readVenus3D(v3d_file)
  cd <- SummarizedExperiment::colData(pe)

  expect_true("label" %in% colnames(cd))
  expect_true("type" %in% colnames(cd))
  expect_true(all(cd$type == "marker"))
})

test_that("readVenus3D uses Point Type header for default labels", {
  v3d_file <- system.file("testdata", "sample_venus3d.csv", package = "PhysioMoCap")
  skip_if(v3d_file == "", message = "sample_venus3d.csv not found")

  pe <- readVenus3D(v3d_file)
  cd <- SummarizedExperiment::colData(pe)

  expect_equal(as.character(cd$label), c("P1", "P2", "P3"))
})


# ===========================================================================
# marker_names parameter
# ===========================================================================

test_that("readVenus3D marker_names overrides default labels", {
  v3d_file <- system.file("testdata", "sample_venus3d.csv", package = "PhysioMoCap")
  skip_if(v3d_file == "", message = "sample_venus3d.csv not found")

  pe <- readVenus3D(v3d_file, marker_names = c("Hip", "Knee", "Ankle"))
  cd <- SummarizedExperiment::colData(pe)

  expect_equal(as.character(cd$label), c("Hip", "Knee", "Ankle"))

  px <- SummarizedExperiment::assay(pe, "position_x")
  expect_equal(colnames(px), c("Hip", "Knee", "Ankle"))
})

test_that("readVenus3D errors on marker_names length mismatch", {
  v3d_file <- system.file("testdata", "sample_venus3d.csv", package = "PhysioMoCap")
  skip_if(v3d_file == "", message = "sample_venus3d.csv not found")

  expect_error(
    readVenus3D(v3d_file, marker_names = c("A", "B")),
    "marker_names"
  )
})


# ===========================================================================
# Missing values (empty cells -> NA)
# ===========================================================================

test_that("readVenus3D handles missing values (empty cells become NA)", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "#Venus3D CSV Data",
    "#Sample Rate,,100.000000",
    "#Number Of Points,,2",
    "#Point Type,,,P1(X),P1(Y),P1(Z),P2(X),P2(Y),P2(Z)",
    "ID,Sample,Time,1(X),1(Y),1(Z),2(X),2(Y),2(Z)",
    "0,0,0.000000,1.0,2.0,3.0,4.0,5.0,6.0",
    "1,1,0.010000,,,, 4.1,5.1,6.1",
    "2,2,0.020000,1.2,2.2,3.2,4.2,5.2,6.2"
  ), tmp)

  pe <- readVenus3D(tmp)
  px <- SummarizedExperiment::assay(pe, "position_x")

  # Frame 2, marker 1 should be NA

  expect_true(is.na(px[2, 1]))
  # Frame 2, marker 2 should be present
  expect_equal(unname(px[2, 2]), 4.1)
  # Other values normal
  expect_equal(unname(px[1, 1]), 1.0)
  expect_equal(unname(px[3, 1]), 1.2)

  unlink(tmp)
})


# ===========================================================================
# Edge cases
# ===========================================================================

test_that("readVenus3D errors on missing file", {
  expect_error(readVenus3D("/nonexistent/path.csv"), "not found")
})

test_that("readVenus3D falls back to M1, M2 labels when no Point Type header", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "#Venus3D CSV Data",
    "#Sample Rate,,60.000000",
    "#Number Of Points,,2",
    "ID,Sample,Time,1(X),1(Y),1(Z),2(X),2(Y),2(Z)",
    "0,0,0.000000,1.0,2.0,3.0,4.0,5.0,6.0",
    "1,1,0.016667,1.1,2.1,3.1,4.1,5.1,6.1"
  ), tmp)

  pe <- readVenus3D(tmp)
  cd <- SummarizedExperiment::colData(pe)

  expect_equal(as.character(cd$label), c("M1", "M2"))

  unlink(tmp)
})

test_that("readVenus3D computes sampling rate from Time column when header missing", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "#Venus3D CSV Data",
    "#Number Of Points,,1",
    "ID,Sample,Time,1(X),1(Y),1(Z)",
    "0,0,0.000,10.0,20.0,30.0",
    "1,1,0.010,10.1,20.1,30.1",
    "2,2,0.020,10.2,20.2,30.2"
  ), tmp)

  pe <- readVenus3D(tmp)
  expect_equal(PhysioCore::samplingRate(pe), 100.0, tolerance = 0.1)

  unlink(tmp)
})


# ===========================================================================
# Internal helper tests
# ===========================================================================

test_that(".parse_venus3d_header extracts all fields", {
  lines <- c(
    "#Venus3D CSV Data",
    "#FormatVersion,,8",
    "#Sample Rate,,240.000000",
    "#Number Of Points,,4",
    "#Units,,m",
    "#Coordinate System,,Z-Up",
    "#Point Type,,,P1(X),P1(Y),P1(Z),P2(X),P2(Y),P2(Z),P3(X),P3(Y),P3(Z),P4(X),P4(Y),P4(Z)"
  )

  hdr <- PhysioMoCap:::.parse_venus3d_header(lines)

  expect_equal(hdr$format_version, 8L)
  expect_equal(hdr$sampling_rate, 240.0)
  expect_equal(hdr$n_points, 4L)
  expect_equal(hdr$units, "m")
  expect_equal(hdr$coordinate_system, "Z-Up")
  expect_equal(hdr$point_types, c("P1", "P2", "P3", "P4"))
})
