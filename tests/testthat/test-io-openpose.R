library(testthat)
library(PhysioMoCap)

# Helper: write a single OpenPose JSON frame to file
write_openpose_frame <- function(file_path, keypoints_2d, n_people = 1) {
  people <- lapply(seq_len(n_people), function(i) {
    if (i <= length(keypoints_2d)) {
      list(
        person_id = list(-1L),
        pose_keypoints_2d = keypoints_2d[[i]]
      )
    } else {
      list(
        person_id = list(-1L),
        pose_keypoints_2d = as.list(rep(0, length(keypoints_2d[[1]])))
      )
    }
  })
  json <- list(version = 1.3, people = people)
  jsonlite::write_json(json, file_path, auto_unbox = TRUE)
}

# Helper: create temp dir with OpenPose frame files
create_openpose_dir <- function(n_frames = 3, n_keypoints = 25, n_people = 1,
                                seed = 42) {
  dir <- file.path(tempdir(), paste0("openpose_test_", sample(1e6, 1)))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)

  set.seed(seed)
  for (i in seq_len(n_frames)) {
    kps <- lapply(seq_len(n_people), function(p) {
      as.list(runif(n_keypoints * 3, 0, 1))
    })
    write_openpose_frame(
      file.path(dir, sprintf("frame_%012d_keypoints.json", i - 1)),
      kps, n_people
    )
  }
  dir
}


# --- Tests ---

test_that("readOpenPose reads a directory of BODY_25 JSON files", {
  skip_if_not_installed("jsonlite")
  op_dir <- create_openpose_dir(n_frames = 5, n_keypoints = 25)
  on.exit(unlink(op_dir, recursive = TRUE))

  pe <- readOpenPose(op_dir, model = "BODY_25", fps = 30)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::samplingRate(pe), 30)
  expect_equal(ncol(SummarizedExperiment::assay(pe, "keypoint_x")), 25)
  expect_equal(nrow(SummarizedExperiment::assay(pe, "keypoint_x")), 5)

  # All three assays present
  anames <- SummarizedExperiment::assayNames(pe)
  expect_true("keypoint_x" %in% anames)
  expect_true("keypoint_y" %in% anames)
  expect_true("confidence" %in% anames)

  # colData has expected columns
  cd <- SummarizedExperiment::colData(pe)
  expect_true("label" %in% colnames(cd))
  expect_true("type" %in% colnames(cd))
  expect_true("model" %in% colnames(cd))
  expect_true(all(cd$type == "keypoint"))
  expect_true(all(cd$model == "BODY_25"))

  # Data should not be all NA (we wrote valid data)
  expect_false(all(is.na(SummarizedExperiment::assay(pe, "keypoint_x"))))
})


test_that("readOpenPose reads a directory of COCO JSON files", {
  skip_if_not_installed("jsonlite")
  op_dir <- create_openpose_dir(n_frames = 3, n_keypoints = 18)
  on.exit(unlink(op_dir, recursive = TRUE))

  pe <- readOpenPose(op_dir, model = "COCO", fps = 25)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::samplingRate(pe), 25)
  expect_equal(ncol(SummarizedExperiment::assay(pe, "keypoint_x")), 18)
  expect_equal(nrow(SummarizedExperiment::assay(pe, "keypoint_x")), 3)

  cd <- SummarizedExperiment::colData(pe)
  expect_true(all(cd$model == "COCO"))
  expect_equal(as.character(cd$label[1]), "Nose")
})


test_that("readOpenPose reads a single JSON file", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  set.seed(123)
  kps <- list(as.list(runif(25 * 3, 0, 500)))
  write_openpose_frame(tmp, kps)

  pe <- readOpenPose(tmp, model = "BODY_25", fps = 60)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::samplingRate(pe), 60)
  expect_equal(nrow(SummarizedExperiment::assay(pe, "keypoint_x")), 1)
  expect_equal(ncol(SummarizedExperiment::assay(pe, "keypoint_x")), 25)
})


test_that("readOpenPose handles empty people array (no detection)", {
  skip_if_not_installed("jsonlite")
  dir <- file.path(tempdir(), paste0("openpose_empty_", sample(1e6, 1)))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE))

  # Frame with no people detected
  json <- list(version = 1.3, people = list())
  jsonlite::write_json(json, file.path(dir, "frame_000000000000_keypoints.json"),
                       auto_unbox = TRUE)

  pe <- readOpenPose(dir, model = "BODY_25", fps = 30)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(nrow(SummarizedExperiment::assay(pe, "keypoint_x")), 1)
  # All NA because no person was detected

  expect_true(all(is.na(SummarizedExperiment::assay(pe, "keypoint_x"))))
  expect_true(all(is.na(SummarizedExperiment::assay(pe, "keypoint_y"))))
  expect_true(all(is.na(SummarizedExperiment::assay(pe, "confidence"))))
})


test_that("readOpenPose extracts multi-person data", {
  skip_if_not_installed("jsonlite")
  op_dir <- create_openpose_dir(n_frames = 3, n_keypoints = 25, n_people = 3,
                                seed = 99)
  on.exit(unlink(op_dir, recursive = TRUE))

  # Read person 1
  pe1 <- readOpenPose(op_dir, model = "BODY_25", fps = 30, person_id = 1)
  # Read person 2
  pe2 <- readOpenPose(op_dir, model = "BODY_25", fps = 30, person_id = 2)

  expect_s4_class(pe1, "PhysioExperiment")
  expect_s4_class(pe2, "PhysioExperiment")

  # Both should have data (not all NA)
  expect_false(all(is.na(SummarizedExperiment::assay(pe1, "keypoint_x"))))
  expect_false(all(is.na(SummarizedExperiment::assay(pe2, "keypoint_x"))))

  # Data should differ between persons
  x1 <- SummarizedExperiment::assay(pe1, "keypoint_x")
  x2 <- SummarizedExperiment::assay(pe2, "keypoint_x")
  expect_false(identical(x1, x2))
})


test_that("readOpenPose returns NA for person_id beyond detected people", {
  skip_if_not_installed("jsonlite")
  op_dir <- create_openpose_dir(n_frames = 2, n_keypoints = 25, n_people = 1)
  on.exit(unlink(op_dir, recursive = TRUE))

  pe <- readOpenPose(op_dir, model = "BODY_25", fps = 30, person_id = 5)

  # Person 5 doesn't exist, so all NA
  expect_true(all(is.na(SummarizedExperiment::assay(pe, "keypoint_x"))))
  expect_true(all(is.na(SummarizedExperiment::assay(pe, "confidence"))))
})


test_that("readOpenPose errors on empty directory (no JSON files)", {
  dir <- file.path(tempdir(), paste0("openpose_nojson_", sample(1e6, 1)))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE))

  expect_error(readOpenPose(dir, model = "BODY_25", fps = 30),
               "No JSON files found")
})


test_that("readOpenPose errors on non-existent path", {
  expect_error(readOpenPose("/nonexistent/path/to/nowhere"),
               "Path does not exist")
})


test_that("readOpenPose validates fps argument", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  kps <- list(as.list(runif(25 * 3)))
  write_openpose_frame(tmp, kps)

  expect_error(readOpenPose(tmp, fps = -1))
  expect_error(readOpenPose(tmp, fps = "abc"))
})


test_that("readOpenPose validates person_id argument", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  kps <- list(as.list(runif(25 * 3)))
  write_openpose_frame(tmp, kps)

  expect_error(readOpenPose(tmp, person_id = 0))
  expect_error(readOpenPose(tmp, person_id = -1))
})


test_that("readOpenPose keypoint names are correct for BODY_25", {
  skip_if_not_installed("jsonlite")
  op_dir <- create_openpose_dir(n_frames = 1, n_keypoints = 25)
  on.exit(unlink(op_dir, recursive = TRUE))

  pe <- readOpenPose(op_dir, model = "BODY_25", fps = 30)

  expected_names <- c("Nose", "Neck", "RShoulder", "RElbow", "RWrist",
                      "LShoulder", "LElbow", "LWrist", "MidHip",
                      "RHip", "RKnee", "RAnkle", "LHip", "LKnee", "LAnkle",
                      "REye", "LEye", "REar", "LEar",
                      "LBigToe", "LSmallToe", "LHeel",
                      "RBigToe", "RSmallToe", "RHeel")
  actual_names <- colnames(SummarizedExperiment::assay(pe, "keypoint_x"))
  expect_equal(actual_names, expected_names)
})


test_that("readOpenPose keypoint names are correct for COCO", {
  skip_if_not_installed("jsonlite")
  op_dir <- create_openpose_dir(n_frames = 1, n_keypoints = 18)
  on.exit(unlink(op_dir, recursive = TRUE))

  pe <- readOpenPose(op_dir, model = "COCO", fps = 30)

  expected_names <- c("Nose", "Neck", "RShoulder", "RElbow", "RWrist",
                      "LShoulder", "LElbow", "LWrist", "RHip", "RKnee",
                      "RAnkle", "LHip", "LKnee", "LAnkle", "REye", "LEye",
                      "REar", "LEar")
  actual_names <- colnames(SummarizedExperiment::assay(pe, "keypoint_x"))
  expect_equal(actual_names, expected_names)
})


test_that("readOpenPose handles mixed detection across frames", {
  skip_if_not_installed("jsonlite")
  dir <- file.path(tempdir(), paste0("openpose_mixed_", sample(1e6, 1)))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE))

  # Frame 0: person detected
  kps <- list(as.list(runif(25 * 3, 100, 500)))
  write_openpose_frame(file.path(dir, "frame_000000000000_keypoints.json"), kps)

  # Frame 1: no people
  json_empty <- list(version = 1.3, people = list())
  jsonlite::write_json(json_empty,
                       file.path(dir, "frame_000000000001_keypoints.json"),
                       auto_unbox = TRUE)

  # Frame 2: person detected again
  kps2 <- list(as.list(runif(25 * 3, 200, 600)))
  write_openpose_frame(file.path(dir, "frame_000000000002_keypoints.json"), kps2)

  pe <- readOpenPose(dir, model = "BODY_25", fps = 30)

  x_mat <- SummarizedExperiment::assay(pe, "keypoint_x")
  expect_equal(nrow(x_mat), 3)

  # Frame 1 (row 1) should have data
  expect_false(any(is.na(x_mat[1, ])))
  # Frame 2 (row 2) should be all NA
  expect_true(all(is.na(x_mat[2, ])))
  # Frame 3 (row 3) should have data
  expect_false(any(is.na(x_mat[3, ])))
})
