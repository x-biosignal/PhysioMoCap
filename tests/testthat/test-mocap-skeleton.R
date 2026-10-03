library(testthat)
library(PhysioMoCap)

# --- SkeletonModel constructor tests ---

test_that("SkeletonModel creates valid object", {
  kp <- data.frame(
    id = 0:2,
    label = c("Head", "Torso", "Hip"),
    body_region = c("head", "torso", "pelvis"),
    stringsAsFactors = FALSE
  )
  bones <- data.frame(
    from_id = c(0, 1),
    to_id = c(1, 2),
    bone_name = c("neck", "spine"),
    stringsAsFactors = FALSE
  )
  hier <- list(Head = "Torso", Torso = "Hip")

  sk <- SkeletonModel("test", kp, bones, hier, "Head")

  expect_s3_class(sk, "SkeletonModel")
  expect_equal(sk$name, "test")
  expect_equal(nrow(sk$keypoints), 3)
  expect_equal(nrow(sk$bones), 2)
  expect_equal(sk$root_keypoint, "Head")
})


test_that("SkeletonModel errors on invalid bone references", {
  kp <- data.frame(
    id = 0:1,
    label = c("A", "B"),
    body_region = c("r1", "r2"),
    stringsAsFactors = FALSE
  )
  bones <- data.frame(
    from_id = 0, to_id = 99,
    bone_name = "bad_bone",
    stringsAsFactors = FALSE
  )
  expect_error(
    SkeletonModel("bad", kp, bones, list(), "A"),
    "invalid keypoint ids"
  )
})


test_that("SkeletonModel errors on invalid root_keypoint", {
  kp <- data.frame(
    id = 0:1,
    label = c("A", "B"),
    body_region = c("r1", "r2"),
    stringsAsFactors = FALSE
  )
  bones <- data.frame(
    from_id = 0, to_id = 1,
    bone_name = "ab",
    stringsAsFactors = FALSE
  )
  expect_error(
    SkeletonModel("bad", kp, bones, list(), "NotExist")
  )
})


# --- define_skeleton tests ---

test_that("define_skeleton returns valid SkeletonModel for BODY_25", {
  sk <- define_skeleton("BODY_25")
  expect_s3_class(sk, "SkeletonModel")
  expect_equal(sk$name, "BODY_25")
  expect_equal(nrow(sk$keypoints), 25)
  expect_equal(nrow(sk$bones), 24)
  expect_equal(sk$root_keypoint, "MidHip")
})


test_that("define_skeleton returns valid SkeletonModel for COCO", {
  sk <- define_skeleton("COCO")
  expect_s3_class(sk, "SkeletonModel")
  expect_equal(sk$name, "COCO")
  expect_equal(nrow(sk$keypoints), 18)
  expect_equal(nrow(sk$bones), 17)
  expect_equal(sk$root_keypoint, "Neck")
})


test_that("define_skeleton returns valid SkeletonModel for BlazePose", {
  sk <- define_skeleton("BlazePose")
  expect_s3_class(sk, "SkeletonModel")
  expect_equal(sk$name, "BlazePose")
  expect_equal(nrow(sk$keypoints), 33)
  expect_equal(nrow(sk$bones), 35)
})


test_that("define_skeleton returns valid SkeletonModel for PluginGait", {
  sk <- define_skeleton("PluginGait")
  expect_s3_class(sk, "SkeletonModel")
  expect_equal(sk$name, "PluginGait")
  expect_equal(nrow(sk$keypoints), 39)
  expect_equal(nrow(sk$bones), 38)
})


test_that("define_skeleton errors on invalid model name", {
  expect_error(define_skeleton("INVALID_MODEL"))
  expect_error(define_skeleton("body25"))
})


# --- get_bone_connections tests ---

test_that("get_bone_connections returns edge list by default", {
  sk <- define_skeleton("COCO")
  edges <- get_bone_connections(sk)

  expect_s3_class(edges, "data.frame")
  expect_equal(nrow(edges), 17)
  expect_true(all(c("from_label", "to_label", "bone_name") %in% colnames(edges)))

  # Verify labels are character, not numeric ids

  expect_true(all(edges$from_label %in% sk$keypoints$label))
  expect_true(all(edges$to_label %in% sk$keypoints$label))
})


test_that("get_bone_connections returns adjacency matrix", {
  sk <- define_skeleton("COCO")
  adj <- get_bone_connections(sk, as_matrix = TRUE)

  expect_true(is.matrix(adj))
  expect_equal(nrow(adj), 18)
  expect_equal(ncol(adj), 18)
  expect_equal(rownames(adj), sk$keypoints$label)
  expect_equal(colnames(adj), sk$keypoints$label)

  # Adjacency matrix should be symmetric
  expect_true(all(adj == t(adj)))

  # Number of TRUE entries should be 2 * n_bones (symmetric)
  expect_equal(sum(adj), 17 * 2)
})


# --- get_segment_lengths tests ---

test_that("get_segment_lengths computes correct distances for known data", {
  # Create a PE with 2 keypoints at known positions
  # Keypoint A at (0, 0, 0) and B at (3, 4, 0) => distance = 5
  n_frames <- 5
  marker_names <- c("Nose", "Neck")

  pos_x <- matrix(c(rep(0, n_frames), rep(3, n_frames)),
                  nrow = n_frames, ncol = 2)
  pos_y <- matrix(c(rep(0, n_frames), rep(4, n_frames)),
                  nrow = n_frames, ncol = 2)
  pos_z <- matrix(0, nrow = n_frames, ncol = 2)
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
      type = rep("marker", 2)
    ),
    samplingRate = 30
  )

  # Minimal skeleton with just Nose-Neck bone
  kp <- data.frame(
    id = c(0L, 1L),
    label = c("Nose", "Neck"),
    body_region = c("head", "torso"),
    stringsAsFactors = FALSE
  )
  bones <- data.frame(
    from_id = 1L, to_id = 0L,
    bone_name = "neck",
    stringsAsFactors = FALSE
  )
  sk <- SkeletonModel("mini", kp, bones, list(Neck = "Nose"), "Neck")

  lengths <- get_segment_lengths(pe, sk)

  expect_true(is.matrix(lengths))
  expect_equal(ncol(lengths), 1)
  expect_equal(nrow(lengths), n_frames)
  expect_equal(colnames(lengths), "neck")

  # All frames should have distance = 5

  expect_equal(as.numeric(lengths[, 1]), rep(5, n_frames))
})


test_that("get_segment_lengths works with 2D data (no position_z)", {
  n_frames <- 3
  marker_names <- c("Nose", "Neck")

  pos_x <- matrix(c(rep(0, n_frames), rep(6, n_frames)),
                  nrow = n_frames, ncol = 2)
  pos_y <- matrix(c(rep(0, n_frames), rep(8, n_frames)),
                  nrow = n_frames, ncol = 2)
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
    samplingRate = 30
  )

  kp <- data.frame(
    id = c(0L, 1L),
    label = c("Nose", "Neck"),
    body_region = c("head", "torso"),
    stringsAsFactors = FALSE
  )
  bones <- data.frame(
    from_id = 1L, to_id = 0L,
    bone_name = "neck",
    stringsAsFactors = FALSE
  )
  sk <- SkeletonModel("mini", kp, bones, list(Neck = "Nose"), "Neck")

  lengths <- get_segment_lengths(pe, sk)

  # sqrt(6^2 + 8^2) = 10
  expect_equal(as.numeric(lengths[, 1]), rep(10, n_frames))
})


test_that("get_segment_lengths returns NA for missing keypoints", {
  pe <- make_mocap_markers(n_time = 10, n_markers = 3, sr = 30)

  # Skeleton referencing keypoints not in PE
  kp <- data.frame(
    id = c(0L, 1L),
    label = c("NotInPE_A", "NotInPE_B"),
    body_region = c("x", "y"),
    stringsAsFactors = FALSE
  )
  bones <- data.frame(
    from_id = 0L, to_id = 1L,
    bone_name = "missing",
    stringsAsFactors = FALSE
  )
  sk <- SkeletonModel("bad", kp, bones, list(NotInPE_A = "NotInPE_B"), "NotInPE_A")

  lengths <- get_segment_lengths(pe, sk)
  expect_true(all(is.na(lengths)))
})


# --- get_limb_pairs tests ---

test_that("get_limb_pairs returns correct pairs for BODY_25", {
  sk <- define_skeleton("BODY_25")
  pairs <- get_limb_pairs(sk)

  expect_s3_class(pairs, "data.frame")
  expect_true(all(c("left", "right") %in% colnames(pairs)))

  # Check specific known pairs
  expect_true(any(pairs$left == "LShoulder" & pairs$right == "RShoulder"))
  expect_true(any(pairs$left == "LElbow" & pairs$right == "RElbow"))
  expect_true(any(pairs$left == "LWrist" & pairs$right == "RWrist"))
  expect_true(any(pairs$left == "LHip" & pairs$right == "RHip"))
  expect_true(any(pairs$left == "LKnee" & pairs$right == "RKnee"))
  expect_true(any(pairs$left == "LAnkle" & pairs$right == "RAnkle"))
})


test_that("get_limb_pairs returns correct pairs for COCO", {
  sk <- define_skeleton("COCO")
  pairs <- get_limb_pairs(sk)

  expect_s3_class(pairs, "data.frame")
  # COCO has L/R for: Shoulder, Elbow, Wrist, Hip, Knee, Ankle, Eye, Ear
  expect_equal(nrow(pairs), 8)
})


test_that("get_limb_pairs returns correct pairs for BlazePose", {
  sk <- define_skeleton("BlazePose")
  pairs <- get_limb_pairs(sk)

  expect_s3_class(pairs, "data.frame")
  # BlazePose has many L/R pairs (eyes, ears, mouth, shoulder, elbow,
  # wrist, pinky, index, thumb, hip, knee, ankle, heel, foot index)
  expect_true(nrow(pairs) >= 14)
  expect_true(any(pairs$left == "LShoulder" & pairs$right == "RShoulder"))
  expect_true(any(pairs$left == "LAnkle" & pairs$right == "RAnkle"))
})


test_that("get_limb_pairs returns correct pairs for PluginGait", {
  sk <- define_skeleton("PluginGait")
  pairs <- get_limb_pairs(sk)

  expect_s3_class(pairs, "data.frame")
  # PluginGait has many bilateral markers
  expect_true(nrow(pairs) >= 10)
  expect_true(any(pairs$left == "LSHO" & pairs$right == "RSHO"))
  expect_true(any(pairs$left == "LKNE" & pairs$right == "RKNE"))
})


# --- print.SkeletonModel tests ---

test_that("print.SkeletonModel produces output", {
  sk <- define_skeleton("BODY_25")
  output <- capture.output(print(sk))

  expect_true(any(grepl("SkeletonModel", output)))
  expect_true(any(grepl("BODY_25", output)))
  expect_true(any(grepl("25", output)))
  expect_true(any(grepl("24", output)))
  expect_true(any(grepl("MidHip", output)))
})


test_that("print.SkeletonModel returns invisibly", {
  sk <- define_skeleton("COCO")
  result <- withVisible(print(sk))
  expect_false(result$visible)
  expect_s3_class(result$value, "SkeletonModel")
})
