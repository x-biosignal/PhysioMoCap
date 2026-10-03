library(testthat)
library(PhysioMoCap)

# ===========================================================================
# xyz format tests
# ===========================================================================

test_that("xyz format: columns like nose_x, nose_y, nose_z produce correct PE", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "nose_x,nose_y,nose_z,hip_x,hip_y,hip_z",
    "1.0,2.0,3.0,4.0,5.0,6.0",
    "1.1,2.1,3.1,4.1,5.1,6.1",
    "1.2,2.2,3.2,4.2,5.2,6.2"
  ), tmp)

  pe <- readMoCapCSV(tmp, format = "xyz", sampling_rate = 100)

  expect_s4_class(pe, "PhysioExperiment")
  expect_true("position_x" %in% SummarizedExperiment::assayNames(pe))
  expect_true("position_y" %in% SummarizedExperiment::assayNames(pe))
  expect_true("position_z" %in% SummarizedExperiment::assayNames(pe))

  px <- SummarizedExperiment::assay(pe, "position_x")
  expect_equal(unname(px[1, "nose"]), 1.0)
  expect_equal(unname(px[1, "hip"]), 4.0)
  expect_equal(unname(px[3, "nose"]), 1.2)

  py <- SummarizedExperiment::assay(pe, "position_y")
  expect_equal(unname(py[1, "nose"]), 2.0)

  pz <- SummarizedExperiment::assay(pe, "position_z")
  expect_equal(unname(pz[1, "nose"]), 3.0)

  unlink(tmp)
})


# ===========================================================================
# wide format tests
# ===========================================================================

test_that("wide format: columns like Time, M1X, M1Y, M1Z produce correct PE", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "Time,M1X,M1Y,M1Z,M2X,M2Y,M2Z",
    "0.0,10.0,20.0,30.0,40.0,50.0,60.0",
    "0.01,10.1,20.1,30.1,40.1,50.1,60.1",
    "0.02,10.2,20.2,30.2,40.2,50.2,60.2"
  ), tmp)

  pe <- readMoCapCSV(tmp, format = "wide", sampling_rate = 100)

  expect_s4_class(pe, "PhysioExperiment")

  px <- SummarizedExperiment::assay(pe, "position_x")
  expect_equal(PhysioCore::channelNames(pe), c("M1", "M2"))
  expect_equal(unname(px[1, "M1"]), 10.0)
  expect_equal(unname(px[1, "M2"]), 40.0)

  unlink(tmp)
})


# ===========================================================================
# Auto-detection tests
# ===========================================================================

test_that("auto-detect xyz format from column names", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "shoulder_x,shoulder_y,shoulder_z,elbow_x,elbow_y,elbow_z",
    "1.0,2.0,3.0,4.0,5.0,6.0",
    "1.1,2.1,3.1,4.1,5.1,6.1"
  ), tmp)

  pe <- readMoCapCSV(tmp, sampling_rate = 60)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::channelNames(pe), c("shoulder", "elbow"))
  expect_equal(PhysioCore::samplingRate(pe), 60)

  unlink(tmp)
})

test_that("auto-detect wide format from column names", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "Time,HipX,HipY,HipZ,KneeX,KneeY,KneeZ",
    "0.0,1.0,2.0,3.0,4.0,5.0,6.0",
    "0.1,1.1,2.1,3.1,4.1,5.1,6.1"
  ), tmp)

  pe <- readMoCapCSV(tmp, sampling_rate = 10)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::channelNames(pe), c("Hip", "Knee"))

  unlink(tmp)
})


# ===========================================================================
# Time column and sampling rate tests
# ===========================================================================

test_that("Time column used to compute sampling rate", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "Time,M1X,M1Y,M1Z",
    "0.0,1.0,2.0,3.0",
    "0.01,1.1,2.1,3.1",
    "0.02,1.2,2.2,3.2",
    "0.03,1.3,2.3,3.3"
  ), tmp)

  pe <- readMoCapCSV(tmp, format = "wide")

  expect_equal(PhysioCore::samplingRate(pe), 100)

  unlink(tmp)
})

test_that("explicit sampling_rate parameter used over Time column", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "Time,M1X,M1Y,M1Z",
    "0.0,1.0,2.0,3.0",
    "0.01,1.1,2.1,3.1",
    "0.02,1.2,2.2,3.2"
  ), tmp)

  pe <- readMoCapCSV(tmp, format = "wide", sampling_rate = 200)

  # Explicit sampling_rate overrides the computed one

  expect_equal(PhysioCore::samplingRate(pe), 200)

  unlink(tmp)
})


# ===========================================================================
# marker_names override test
# ===========================================================================

test_that("marker_names parameter overrides auto-detection", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "a_x,a_y,a_z,b_x,b_y,b_z",
    "1.0,2.0,3.0,4.0,5.0,6.0",
    "1.1,2.1,3.1,4.1,5.1,6.1"
  ), tmp)

  pe <- readMoCapCSV(tmp, sampling_rate = 100,
                     marker_names = c("LeftHip", "RightHip"))

  expect_equal(PhysioCore::channelNames(pe), c("LeftHip", "RightHip"))

  px <- SummarizedExperiment::assay(pe, "position_x")
  expect_equal(colnames(px), c("LeftHip", "RightHip"))

  unlink(tmp)
})


# ===========================================================================
# Multiple header rows / skip parameter
# ===========================================================================

test_that("skip parameter skips leading lines", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "# This is a comment line",
    "# Another comment",
    "foot_x,foot_y,foot_z",
    "1.0,2.0,3.0",
    "1.1,2.1,3.1"
  ), tmp)

  pe <- readMoCapCSV(tmp, sampling_rate = 50, skip = 2)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::channelNames(pe), "foot")
  expect_equal(nrow(SummarizedExperiment::assay(pe, "position_x")), 2)

  unlink(tmp)
})


# ===========================================================================
# Error on missing sampling_rate
# ===========================================================================

test_that("error on missing sampling_rate when not detectable", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "nose_x,nose_y,nose_z",
    "1.0,2.0,3.0",
    "1.1,2.1,3.1"
  ), tmp)

  expect_error(
    readMoCapCSV(tmp, format = "xyz"),
    "sampling_rate"
  )

  unlink(tmp)
})


# ===========================================================================
# Dimension tests
# ===========================================================================

test_that("position assays have correct dimensions", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "a_x,a_y,a_z,b_x,b_y,b_z,c_x,c_y,c_z",
    "1,2,3,4,5,6,7,8,9",
    "10,20,30,40,50,60,70,80,90",
    "11,21,31,41,51,61,71,81,91",
    "12,22,32,42,52,62,72,82,92"
  ), tmp)

  pe <- readMoCapCSV(tmp, sampling_rate = 120)

  px <- SummarizedExperiment::assay(pe, "position_x")
  py <- SummarizedExperiment::assay(pe, "position_y")
  pz <- SummarizedExperiment::assay(pe, "position_z")

  expect_equal(dim(px), c(4, 3))
  expect_equal(dim(py), c(4, 3))
  expect_equal(dim(pz), c(4, 3))
  expect_equal(PhysioCore::nChannels(pe), 3)

  unlink(tmp)
})


# ===========================================================================
# colData labels test
# ===========================================================================

test_that("colData has correct marker labels", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "wrist_x,wrist_y,wrist_z,ankle_x,ankle_y,ankle_z",
    "1.0,2.0,3.0,4.0,5.0,6.0"
  ), tmp)

  pe <- readMoCapCSV(tmp, sampling_rate = 30)
  cd <- SummarizedExperiment::colData(pe)

  expect_equal(as.character(cd$label), c("wrist", "ankle"))
  expect_equal(as.character(cd$type), c("marker", "marker"))

  unlink(tmp)
})


# ===========================================================================
# Custom separator (tab-separated)
# ===========================================================================

test_that("custom separator handles tab-separated files", {
  tmp <- tempfile(fileext = ".tsv")
  writeLines(c(
    "knee_x\tknee_y\tknee_z\thip_x\thip_y\thip_z",
    "1.0\t2.0\t3.0\t4.0\t5.0\t6.0",
    "1.1\t2.1\t3.1\t4.1\t5.1\t6.1"
  ), tmp)

  pe <- readMoCapCSV(tmp, sampling_rate = 100, sep = "\t")

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::channelNames(pe), c("knee", "hip"))

  px <- SummarizedExperiment::assay(pe, "position_x")
  expect_equal(unname(px[1, "knee"]), 1.0)
  expect_equal(unname(px[1, "hip"]), 4.0)

  unlink(tmp)
})


# ===========================================================================
# Long format test
# ===========================================================================

test_that("long format parsing works correctly", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "frame,marker,x,y,z",
    "1,hip,1.0,2.0,3.0",
    "1,knee,4.0,5.0,6.0",
    "2,hip,1.1,2.1,3.1",
    "2,knee,4.1,5.1,6.1",
    "3,hip,1.2,2.2,3.2",
    "3,knee,4.2,5.2,6.2"
  ), tmp)

  pe <- readMoCapCSV(tmp, format = "long", sampling_rate = 60)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::channelNames(pe), c("hip", "knee"))

  px <- SummarizedExperiment::assay(pe, "position_x")
  expect_equal(dim(px), c(3, 2))
  expect_equal(unname(px[1, "hip"]), 1.0)
  expect_equal(unname(px[1, "knee"]), 4.0)
  expect_equal(unname(px[3, "hip"]), 1.2)

  unlink(tmp)
})


# ===========================================================================
# Edge case: single marker
# ===========================================================================

test_that("single marker file is handled correctly", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    "Time,head_x,head_y,head_z",
    "0.0,10.0,20.0,30.0",
    "0.005,10.1,20.1,30.1",
    "0.01,10.2,20.2,30.2"
  ), tmp)

  pe <- readMoCapCSV(tmp)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::nChannels(pe), 1)
  expect_equal(PhysioCore::channelNames(pe), "head")
  expect_equal(PhysioCore::samplingRate(pe), 200)

  px <- SummarizedExperiment::assay(pe, "position_x")
  expect_equal(dim(px), c(3, 1))
  expect_equal(unname(px[1, 1]), 10.0)

  unlink(tmp)
})
