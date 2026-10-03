library(testthat)
library(PhysioMoCap)

# ===========================================================================
# readASF tests
# ===========================================================================

test_that("readASF parses units correctly", {
  asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
  skip_if(asf_file == "", message = "sample.asf not found")

  skel <- readASF(asf_file)

  expect_equal(skel$units$mass, 1.0)
  expect_equal(skel$units$length, 0.45)
  expect_equal(skel$units$angle, "deg")
})

test_that("readASF parses root position and orientation", {
  asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
  skip_if(asf_file == "", message = "sample.asf not found")

  skel <- readASF(asf_file)

  expect_equal(skel$root$position, c(0, 0, 0))
  expect_equal(skel$root$orientation, c(0, 0, 0))
  expect_equal(skel$root$order, c("TX", "TY", "TZ", "RX", "RY", "RZ"))
  expect_equal(skel$root$axis, "XYZ")
})

test_that("readASF parses bone data (name, direction, length, dof, limits)", {
  asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
  skip_if(asf_file == "", message = "sample.asf not found")

  skel <- readASF(asf_file)

  expect_true("lfemur" %in% names(skel$bones))
  expect_true("ltibia" %in% names(skel$bones))

  lfemur <- skel$bones[["lfemur"]]
  expect_equal(lfemur$id, 1L)
  expect_equal(lfemur$name, "lfemur")
  expect_equal(lfemur$direction, c(0.34, -0.93, 0.12))
  expect_equal(lfemur$length, 7.2)
  expect_equal(lfemur$dof, c("rx", "ry", "rz"))
  expect_equal(length(lfemur$limits), 3)
  expect_equal(lfemur$limits[[1]], c(-160, 20))
  expect_equal(lfemur$limits[[2]], c(-70, 70))

  ltibia <- skel$bones[["ltibia"]]
  expect_equal(ltibia$id, 2L)
  expect_equal(ltibia$dof, "rx")
  expect_equal(ltibia$length, 6.8)
  expect_equal(length(ltibia$limits), 1)
  expect_equal(ltibia$limits[[1]], c(-10, 170))
})

test_that("readASF hierarchy correct (root -> lfemur -> ltibia)", {
  asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
  skip_if(asf_file == "", message = "sample.asf not found")

  skel <- readASF(asf_file)

  expect_true("root" %in% names(skel$hierarchy))
  expect_true("lfemur" %in% names(skel$hierarchy))

  expect_equal(skel$hierarchy[["root"]], "lfemur")
  expect_equal(skel$hierarchy[["lfemur"]], "ltibia")
})

# ===========================================================================
# readAMC tests
# ===========================================================================

test_that("readAMC returns PE with correct frame count", {
  amc_file <- system.file("testdata", "sample.amc", package = "PhysioMoCap")
  skip_if(amc_file == "", message = "sample.amc not found")

  pe <- readAMC(amc_file)

  expect_s4_class(pe, "PhysioExperiment")
  rot_x <- SummarizedExperiment::assay(pe, "rotation_x")
  expect_equal(nrow(rot_x), 3)
})

test_that("readAMC root has 6 channels (3 position + 3 rotation)", {
  amc_file <- system.file("testdata", "sample.amc", package = "PhysioMoCap")
  skip_if(amc_file == "", message = "sample.amc not found")

  pe <- readAMC(amc_file)

  # Root joint should have non-NA position data

  pos_x <- SummarizedExperiment::assay(pe, "position_x")
  pos_y <- SummarizedExperiment::assay(pe, "position_y")
  pos_z <- SummarizedExperiment::assay(pe, "position_z")
  rot_x <- SummarizedExperiment::assay(pe, "rotation_x")
  rot_y <- SummarizedExperiment::assay(pe, "rotation_y")
  rot_z <- SummarizedExperiment::assay(pe, "rotation_z")

  # Root has position and rotation
  expect_false(any(is.na(pos_x[, "root"])))
  expect_false(any(is.na(pos_y[, "root"])))
  expect_false(any(is.na(pos_z[, "root"])))
  expect_false(any(is.na(rot_x[, "root"])))
  expect_false(any(is.na(rot_y[, "root"])))
  expect_false(any(is.na(rot_z[, "root"])))

  # Root dof_count should be 6
  cd <- SummarizedExperiment::colData(pe)
  root_row <- cd[cd$label == "root", ]
  expect_equal(root_row$dof_count, 6L)
})

test_that("readAMC joint DOFs match ASF definition", {
  asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
  amc_file <- system.file("testdata", "sample.amc", package = "PhysioMoCap")
  skip_if(asf_file == "" || amc_file == "", message = "test files not found")

  skel <- readASF(asf_file)
  pe <- readAMC(amc_file, asf = skel)

  # lfemur has dof rx ry rz -> 3 rotation channels
  rot_x <- SummarizedExperiment::assay(pe, "rotation_x")
  rot_y <- SummarizedExperiment::assay(pe, "rotation_y")
  rot_z <- SummarizedExperiment::assay(pe, "rotation_z")

  expect_false(any(is.na(rot_x[, "lfemur"])))
  expect_false(any(is.na(rot_y[, "lfemur"])))
  expect_false(any(is.na(rot_z[, "lfemur"])))

  # ltibia has dof rx only -> only rotation_x should be filled
  expect_false(any(is.na(rot_x[, "ltibia"])))
  expect_true(all(is.na(rot_y[, "ltibia"])))
  expect_true(all(is.na(rot_z[, "ltibia"])))
})

test_that("readAMC data values correct for frame 1", {
  asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
  amc_file <- system.file("testdata", "sample.amc", package = "PhysioMoCap")
  skip_if(asf_file == "" || amc_file == "", message = "test files not found")

  skel <- readASF(asf_file)
  pe <- readAMC(amc_file, asf = skel)

  # Frame 1: root 0.1 35.0 0.0 1.0 0.5 0.3
  pos_x <- SummarizedExperiment::assay(pe, "position_x")
  pos_y <- SummarizedExperiment::assay(pe, "position_y")
  pos_z <- SummarizedExperiment::assay(pe, "position_z")
  rot_x <- SummarizedExperiment::assay(pe, "rotation_x")
  rot_y <- SummarizedExperiment::assay(pe, "rotation_y")
  rot_z <- SummarizedExperiment::assay(pe, "rotation_z")

  expect_equal(unname(pos_x[1, "root"]), 0.1)
  expect_equal(unname(pos_y[1, "root"]), 35.0)
  expect_equal(unname(pos_z[1, "root"]), 0.0)
  expect_equal(unname(rot_x[1, "root"]), 1.0)
  expect_equal(unname(rot_y[1, "root"]), 0.5)
  expect_equal(unname(rot_z[1, "root"]), 0.3)

  # Frame 1: lfemur 5.0 0.0 2.0 -> rx=5.0 ry=0.0 rz=2.0
  expect_equal(unname(rot_x[1, "lfemur"]), 5.0)
  expect_equal(unname(rot_y[1, "lfemur"]), 0.0)
  expect_equal(unname(rot_z[1, "lfemur"]), 2.0)

  # Frame 1: ltibia 10.0 -> rx=10.0
  expect_equal(unname(rot_x[1, "ltibia"]), 10.0)
})

test_that("samplingRate equals fps parameter", {
  amc_file <- system.file("testdata", "sample.amc", package = "PhysioMoCap")
  skip_if(amc_file == "", message = "sample.amc not found")

  pe_default <- readAMC(amc_file)
  expect_equal(PhysioCore::samplingRate(pe_default), 120)

  pe_custom <- readAMC(amc_file, fps = 60)
  expect_equal(PhysioCore::samplingRate(pe_custom), 60)
})

test_that("readAMC without ASF still works", {
  amc_file <- system.file("testdata", "sample.amc", package = "PhysioMoCap")
  skip_if(amc_file == "", message = "sample.amc not found")

  pe <- readAMC(amc_file)

  expect_s4_class(pe, "PhysioExperiment")

  # Without ASF, DOFs are assigned positionally (rx, ry, rz)
  rot_x <- SummarizedExperiment::assay(pe, "rotation_x")
  rot_y <- SummarizedExperiment::assay(pe, "rotation_y")
  rot_z <- SummarizedExperiment::assay(pe, "rotation_z")

  # lfemur has 3 values -> all three rotation axes filled
  expect_false(any(is.na(rot_x[, "lfemur"])))
  expect_false(any(is.na(rot_y[, "lfemur"])))
  expect_false(any(is.na(rot_z[, "lfemur"])))

  # ltibia has 1 value -> only rx filled (without ASF, assumes rx first)
  expect_false(any(is.na(rot_x[, "ltibia"])))
  expect_true(all(is.na(rot_y[, "ltibia"])))
  expect_true(all(is.na(rot_z[, "ltibia"])))

  # metadata should NOT have asf_skeleton
  md <- S4Vectors::metadata(pe)
  expect_null(md$asf_skeleton)
})

test_that("print.ASFSkeleton works", {
  asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
  skip_if(asf_file == "", message = "sample.asf not found")

  skel <- readASF(asf_file)

  output <- capture.output(print(skel))
  expect_true(any(grepl("ASF Skeleton", output)))
  expect_true(any(grepl("Bones:", output)))
  expect_true(any(grepl("lfemur", output)))
  expect_true(any(grepl("ltibia", output)))
})

test_that("readASF errors on missing file", {
  expect_error(readASF("/nonexistent/path.asf"))
})

test_that("readAMC errors on missing file", {
  expect_error(readAMC("/nonexistent/path.amc"))
})

test_that("colData has correct labels and types", {
  asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
  amc_file <- system.file("testdata", "sample.amc", package = "PhysioMoCap")
  skip_if(asf_file == "" || amc_file == "", message = "test files not found")

  skel <- readASF(asf_file)
  pe <- readAMC(amc_file, asf = skel)

  cd <- SummarizedExperiment::colData(pe)

  expect_equal(as.character(cd$label), c("root", "lfemur", "ltibia"))
  expect_equal(as.character(cd$type), c("root", "joint", "joint"))
  expect_equal(cd$dof_count, c(6L, 3L, 1L))
})
