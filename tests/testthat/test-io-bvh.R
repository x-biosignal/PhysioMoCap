library(testthat)
library(PhysioMoCap)

# ===========================================================================
# readBVH tests — sample.bvh
# ===========================================================================

test_that("readBVH reads sample.bvh and returns PhysioExperiment", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)
  expect_s4_class(pe, "PhysioExperiment")
})

test_that("readBVH extracts correct hierarchy (Hips -> RightKnee -> End Site)", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)
  md <- S4Vectors::metadata(pe)
  skeleton <- md$bvh_skeleton

  # Root is Hips

  expect_equal(skeleton$name, "Hips")
  expect_equal(skeleton$type, "root")

  # First child is RightKnee
  expect_equal(length(skeleton$children), 1)
  right_knee <- skeleton$children[[1]]
  expect_equal(right_knee$name, "RightKnee")
  expect_equal(right_knee$type, "joint")
  expect_equal(right_knee$parent, "Hips")

  # RightKnee has End Site child
  expect_equal(length(right_knee$children), 1)
  end_site <- right_knee$children[[1]]
  expect_equal(end_site$type, "end_site")
})

test_that("readBVH root has 6 channels, joints have 3", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)
  md <- S4Vectors::metadata(pe)
  skeleton <- md$bvh_skeleton

  # Root (Hips) has 6 channels
  expect_equal(length(skeleton$channels), 6)

  # Child joint (RightKnee) has 3 channels
  right_knee <- skeleton$children[[1]]
  expect_equal(length(right_knee$channels), 3)
})

test_that("readBVH returns correct number of frames", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)

  # 3 frames in sample.bvh
  rot_x <- SummarizedExperiment::assay(pe, "rotation_x")
  expect_equal(nrow(rot_x), 3)
})

test_that("readBVH computes correct frame_time", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)
  md <- S4Vectors::metadata(pe)

  expect_equal(md$frame_time, 0.033333)
})

test_that("readBVH computes samplingRate = 1/0.033333 ~ 30", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)
  sr <- PhysioCore::samplingRate(pe)

  expect_equal(sr, 1 / 0.033333, tolerance = 0.01)
  expect_true(abs(sr - 30) < 0.1)
})

test_that("readBVH colData has correct joint names and types", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)
  cd <- SummarizedExperiment::colData(pe)

  expect_equal(as.character(cd$label), c("Hips", "RightKnee"))
  # Hips is root (has position channels), RightKnee is rotation only
  expect_equal(as.character(cd$type), c("position", "rotation"))
  # parent_joint: Hips has no parent, RightKnee's parent is Hips
  expect_true(is.na(cd$parent_joint[1]))
  expect_equal(as.character(cd$parent_joint[2]), "Hips")
})

test_that("readBVH metadata contains skeleton hierarchy", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)
  md <- S4Vectors::metadata(pe)

  expect_true("bvh_skeleton" %in% names(md))
  expect_true("rotation_order" %in% names(md))
  expect_true("frame_time" %in% names(md))
  expect_true("offsets" %in% names(md))
  expect_true("source_file" %in% names(md))

  expect_equal(md$source_file, "sample.bvh")
})

test_that("readBVH produces rotation assays for all joints", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)
  assay_names <- SummarizedExperiment::assayNames(pe)

  expect_true("rotation_x" %in% assay_names)
  expect_true("rotation_y" %in% assay_names)
  expect_true("rotation_z" %in% assay_names)

  # Both Hips and RightKnee have rotation data
  rot_x <- SummarizedExperiment::assay(pe, "rotation_x")
  expect_equal(ncol(rot_x), 2)
  expect_equal(colnames(rot_x), c("Hips", "RightKnee"))
})

test_that("readBVH produces position assays for root joint only", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)
  assay_names <- SummarizedExperiment::assayNames(pe)

  expect_true("position_x" %in% assay_names)
  expect_true("position_y" %in% assay_names)
  expect_true("position_z" %in% assay_names)

  # Position assays have same ncol as rotation (SE requirement),
  # but only Hips (root) has non-NA position data
  pos_x <- SummarizedExperiment::assay(pe, "position_x")
  expect_equal(ncol(pos_x), 2)  # same as rotation assays
  expect_false(any(is.na(pos_x[, "Hips"])))
  expect_true(all(is.na(pos_x[, "RightKnee"])))
})

test_that("readBVH preserves motion data values correctly", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)

  # Frame 1: 0.0 35.0 0.0  0.0 0.0 0.0  5.0 0.0 0.0
  # Hips: Xposition=0.0, Yposition=35.0, Zposition=0.0,
  #        Zrotation=0.0, Xrotation=0.0, Yrotation=0.0
  # RightKnee: Zrotation=5.0, Xrotation=0.0, Yrotation=0.0
  pos_x <- SummarizedExperiment::assay(pe, "position_x")
  pos_y <- SummarizedExperiment::assay(pe, "position_y")
  pos_z <- SummarizedExperiment::assay(pe, "position_z")

  expect_equal(unname(pos_x[1, "Hips"]), 0.0)
  expect_equal(unname(pos_y[1, "Hips"]), 35.0)
  expect_equal(unname(pos_z[1, "Hips"]), 0.0)

  # Frame 2 position: 0.1, 35.1, 0.1
  expect_equal(unname(pos_x[2, "Hips"]), 0.1)
  expect_equal(unname(pos_y[2, "Hips"]), 35.1)
  expect_equal(unname(pos_z[2, "Hips"]), 0.1)

  # Rotation data for RightKnee
  rot_z <- SummarizedExperiment::assay(pe, "rotation_z")
  rot_x <- SummarizedExperiment::assay(pe, "rotation_x")
  rot_y <- SummarizedExperiment::assay(pe, "rotation_y")

  # RightKnee frame 1: Zrot=5.0, Xrot=0.0, Yrot=0.0
  expect_equal(unname(rot_z[1, "RightKnee"]), 5.0)
  expect_equal(unname(rot_x[1, "RightKnee"]), 0.0)
  expect_equal(unname(rot_y[1, "RightKnee"]), 0.0)

  # RightKnee frame 3: Zrot=15.0, Xrot=2.0, Yrot=1.0
  expect_equal(unname(rot_z[3, "RightKnee"]), 15.0)
  expect_equal(unname(rot_x[3, "RightKnee"]), 2.0)
  expect_equal(unname(rot_y[3, "RightKnee"]), 1.0)
})

test_that("readBVH extracts rotation order from channels", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)
  md <- S4Vectors::metadata(pe)

  # Hips channels: Xposition Yposition Zposition Zrotation Xrotation Yrotation
  # Rotation order = ZXY
  expect_equal(md$rotation_order, "ZXY")
})

test_that("readBVH stores offsets in metadata", {
  bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
  skip_if(bvh_file == "", message = "sample.bvh not found")

  pe <- readBVH(bvh_file)
  md <- S4Vectors::metadata(pe)

  expect_true("offsets" %in% names(md))
  expect_equal(md$offsets[["Hips"]], c(0, 0, 0))
  expect_equal(md$offsets[["RightKnee"]], c(0, -18, 0))
  # End site offset should also be stored
  expect_equal(md$offsets[["RightKnee_End"]], c(0, -17, 0))
})


# ===========================================================================
# Edge cases
# ===========================================================================

test_that("readBVH handles extra whitespace in file", {
  tmp <- tempfile(fileext = ".bvh")
  writeLines(c(
    "HIERARCHY",
    "ROOT   Spine  ",
    "{",
    "    OFFSET   0.00   0.00   0.00  ",
    "    CHANNELS  6  Xposition Yposition Zposition Zrotation Xrotation Yrotation",
    "    End Site",
    "    {",
    "        OFFSET  0.00  10.00  0.00",
    "    }",
    "}",
    "MOTION",
    "Frames:  2",
    "Frame Time:  0.01",
    "  1.0  2.0  3.0  4.0  5.0  6.0  ",
    "  7.0  8.0  9.0  10.0  11.0  12.0  "
  ), tmp)

  pe <- readBVH(tmp)
  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::samplingRate(pe), 100.0)

  pos_x <- SummarizedExperiment::assay(pe, "position_x")
  expect_equal(unname(pos_x[1, 1]), 1.0)
  expect_equal(unname(pos_x[2, 1]), 7.0)

  unlink(tmp)
})

test_that("readBVH handles empty motion (0 frames)", {
  tmp <- tempfile(fileext = ".bvh")
  writeLines(c(
    "HIERARCHY",
    "ROOT Pelvis",
    "{",
    "    OFFSET 0.00 0.00 0.00",
    "    CHANNELS 6 Xposition Yposition Zposition Zrotation Xrotation Yrotation",
    "    End Site",
    "    {",
    "        OFFSET 0.00 5.00 0.00",
    "    }",
    "}",
    "MOTION",
    "Frames: 0",
    "Frame Time: 0.01"
  ), tmp)

  pe <- readBVH(tmp)
  expect_s4_class(pe, "PhysioExperiment")
  rot_x <- SummarizedExperiment::assay(pe, "rotation_x")
  expect_equal(nrow(rot_x), 0)

  unlink(tmp)
})

test_that("readBVH errors on missing file", {
  expect_error(readBVH("/nonexistent/path.bvh"))
})

test_that("readBVH errors on file without MOTION section", {
  tmp <- tempfile(fileext = ".bvh")
  writeLines(c(
    "HIERARCHY",
    "ROOT Test",
    "{",
    "    OFFSET 0.00 0.00 0.00",
    "    CHANNELS 6 Xposition Yposition Zposition Zrotation Xrotation Yrotation",
    "}"
  ), tmp)

  expect_error(readBVH(tmp), "MOTION")

  unlink(tmp)
})

# ===========================================================================
# Additional internal parser tests
# ===========================================================================

test_that(".parse_bvh_hierarchy returns correct structure", {
  lines <- c(
    "HIERARCHY",
    "ROOT TestRoot",
    "{",
    "    OFFSET 1.0 2.0 3.0",
    "    CHANNELS 6 Xposition Yposition Zposition Xrotation Yrotation Zrotation",
    "    End Site",
    "    {",
    "        OFFSET 0.0 5.0 0.0",
    "    }",
    "}"
  )

  skeleton <- PhysioMoCap:::.parse_bvh_hierarchy(lines)

  expect_equal(skeleton$name, "TestRoot")
  expect_equal(skeleton$offset, c(1, 2, 3))
  expect_equal(length(skeleton$channels), 6)
  expect_equal(length(skeleton$children), 1)
  expect_equal(skeleton$children[[1]]$type, "end_site")
})
