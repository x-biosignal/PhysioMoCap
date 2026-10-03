library(testthat)
library(PhysioMoCap)

# --- Helpers ---

# Write a single MediaPipe JSON frame with landmarks
write_mediapipe_json <- function(file_path, n_landmarks, seed = NULL,
                                 include_world = FALSE,
                                 include_visibility = TRUE) {
  if (!is.null(seed)) set.seed(seed)
  landmarks <- lapply(seq_len(n_landmarks), function(i) {
    lm <- list(x = runif(1), y = runif(1), z = runif(1, -0.1, 0.1))
    if (include_visibility) lm$visibility <- runif(1, 0.5, 1.0)
    lm
  })

  json <- list(landmarks = landmarks)

  if (include_world) {
    world <- lapply(seq_len(n_landmarks), function(i) {
      list(x = runif(1, -1, 1), y = runif(1, -1, 1), z = runif(1, -1, 1))
    })
    json$world_landmarks <- world
  }

  jsonlite::write_json(json, file_path, auto_unbox = TRUE)
}

# Create a temp directory with MediaPipe JSON frame files
create_mediapipe_json_dir <- function(n_frames = 3, n_landmarks = 33,
                                      include_world = FALSE,
                                      include_visibility = TRUE,
                                      seed = 42) {
  dir <- file.path(tempdir(), paste0("mediapipe_test_", sample(1e6, 1)))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)

  set.seed(seed)
  for (i in seq_len(n_frames)) {
    write_mediapipe_json(
      file.path(dir, sprintf("frame_%06d.json", i - 1)),
      n_landmarks = n_landmarks,
      include_world = include_world,
      include_visibility = include_visibility
    )
  }
  dir
}

# Create a temp CSV file with MediaPipe landmark columns
create_mediapipe_csv <- function(n_frames = 5, n_landmarks = 33, seed = 42) {
  set.seed(seed)
  cols <- list()
  for (j in seq_len(n_landmarks)) {
    idx <- j - 1L
    cols[[paste0("landmark_", idx, "_x")]] <- runif(n_frames)
    cols[[paste0("landmark_", idx, "_y")]] <- runif(n_frames)
    cols[[paste0("landmark_", idx, "_z")]] <- runif(n_frames, -0.1, 0.1)
    cols[[paste0("landmark_", idx, "_visibility")]] <- runif(n_frames, 0.5, 1.0)
  }
  df <- as.data.frame(cols)
  path <- tempfile(fileext = ".csv")
  utils::write.csv(df, path, row.names = FALSE)
  path
}


# --- Tests ---

test_that("readMediaPipe reads a directory of pose JSON files", {
  skip_if_not_installed("jsonlite")
  mp_dir <- create_mediapipe_json_dir(n_frames = 5, n_landmarks = 33)
  on.exit(unlink(mp_dir, recursive = TRUE))

  pe <- readMediaPipe(mp_dir, model = "pose", fps = 30)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::samplingRate(pe), 30)
  expect_equal(ncol(SummarizedExperiment::assay(pe, "landmark_x")), 33)
  expect_equal(nrow(SummarizedExperiment::assay(pe, "landmark_x")), 5)

  # All four core assays present
  anames <- SummarizedExperiment::assayNames(pe)
  expect_true("landmark_x" %in% anames)
  expect_true("landmark_y" %in% anames)
  expect_true("landmark_z" %in% anames)
  expect_true("visibility" %in% anames)

  # Data should not be all NA
  expect_false(all(is.na(SummarizedExperiment::assay(pe, "landmark_x"))))
})


test_that("readMediaPipe reads CSV format", {
  skip_if_not_installed("jsonlite")
  csv_path <- create_mediapipe_csv(n_frames = 4, n_landmarks = 33)
  on.exit(unlink(csv_path))

  pe <- readMediaPipe(csv_path, model = "pose", fps = 60)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::samplingRate(pe), 60)
  expect_equal(ncol(SummarizedExperiment::assay(pe, "landmark_x")), 33)
  expect_equal(nrow(SummarizedExperiment::assay(pe, "landmark_x")), 4)

  anames <- SummarizedExperiment::assayNames(pe)
  expect_true("landmark_x" %in% anames)
  expect_true("landmark_y" %in% anames)
  expect_true("landmark_z" %in% anames)
  expect_true("visibility" %in% anames)

  # Data should not be all NA
  expect_false(all(is.na(SummarizedExperiment::assay(pe, "landmark_x"))))
  expect_false(all(is.na(SummarizedExperiment::assay(pe, "visibility"))))
})


test_that("readMediaPipe correct landmark count for pose model (33)", {
  skip_if_not_installed("jsonlite")
  mp_dir <- create_mediapipe_json_dir(n_frames = 2, n_landmarks = 33)
  on.exit(unlink(mp_dir, recursive = TRUE))

  pe <- readMediaPipe(mp_dir, model = "pose", fps = 30)

  expect_equal(ncol(SummarizedExperiment::assay(pe, "landmark_x")), 33)
  cd <- SummarizedExperiment::colData(pe)
  expect_equal(nrow(cd), 33)
  expect_equal(as.character(cd$label[1]), "nose")
  expect_equal(as.character(cd$label[33]), "right_foot_index")
})


test_that("readMediaPipe correct landmark count for hand model (21)", {
  skip_if_not_installed("jsonlite")
  mp_dir <- create_mediapipe_json_dir(n_frames = 2, n_landmarks = 21)
  on.exit(unlink(mp_dir, recursive = TRUE))

  pe <- readMediaPipe(mp_dir, model = "hand", fps = 30)

  expect_equal(ncol(SummarizedExperiment::assay(pe, "landmark_x")), 21)
  cd <- SummarizedExperiment::colData(pe)
  expect_equal(nrow(cd), 21)
  expect_equal(as.character(cd$label[1]), "wrist")
  expect_equal(as.character(cd$label[21]), "pinky_tip")
})


test_that("readMediaPipe includes world coordinates when present", {
  skip_if_not_installed("jsonlite")
  mp_dir <- create_mediapipe_json_dir(n_frames = 3, n_landmarks = 33,
                                       include_world = TRUE)
  on.exit(unlink(mp_dir, recursive = TRUE))

  pe <- readMediaPipe(mp_dir, model = "pose", fps = 30)

  anames <- SummarizedExperiment::assayNames(pe)
  expect_true("world_x" %in% anames)
  expect_true("world_y" %in% anames)
  expect_true("world_z" %in% anames)

  # World data should not be all NA
  expect_false(all(is.na(SummarizedExperiment::assay(pe, "world_x"))))
})


test_that("readMediaPipe extracts visibility values", {
  skip_if_not_installed("jsonlite")
  mp_dir <- create_mediapipe_json_dir(n_frames = 3, n_landmarks = 33,
                                       include_visibility = TRUE, seed = 123)
  on.exit(unlink(mp_dir, recursive = TRUE))

  pe <- readMediaPipe(mp_dir, model = "pose", fps = 30)

  vis <- SummarizedExperiment::assay(pe, "visibility")
  expect_false(all(is.na(vis)))
  # Visibility values should be in [0.5, 1.0] range (as we set in helper)
  non_na <- vis[!is.na(vis)]
  expect_true(all(non_na >= 0 & non_na <= 1))
})


test_that("readMediaPipe colData has correct labels and model", {
  skip_if_not_installed("jsonlite")
  mp_dir <- create_mediapipe_json_dir(n_frames = 1, n_landmarks = 33)
  on.exit(unlink(mp_dir, recursive = TRUE))

  pe <- readMediaPipe(mp_dir, model = "pose", fps = 30)
  cd <- SummarizedExperiment::colData(pe)

  expect_true("label" %in% colnames(cd))
  expect_true("type" %in% colnames(cd))
  expect_true("model" %in% colnames(cd))
  expect_true("landmark_idx" %in% colnames(cd))
  expect_true(all(cd$type == "landmark"))
  expect_true(all(cd$model == "pose"))
  expect_equal(as.integer(cd$landmark_idx), 0:32)
})


test_that("readMediaPipe colData has correct labels for hand model", {
  skip_if_not_installed("jsonlite")
  mp_dir <- create_mediapipe_json_dir(n_frames = 1, n_landmarks = 21)
  on.exit(unlink(mp_dir, recursive = TRUE))

  pe <- readMediaPipe(mp_dir, model = "hand", fps = 30)
  cd <- SummarizedExperiment::colData(pe)

  expect_true(all(cd$type == "landmark"))
  expect_true(all(cd$model == "hand"))
  expect_equal(as.integer(cd$landmark_idx), 0:20)

  expected_names <- c("wrist", "thumb_cmc", "thumb_mcp", "thumb_ip", "thumb_tip",
                      "index_finger_mcp", "index_finger_pip", "index_finger_dip",
                      "index_finger_tip",
                      "middle_finger_mcp", "middle_finger_pip", "middle_finger_dip",
                      "middle_finger_tip",
                      "ring_finger_mcp", "ring_finger_pip", "ring_finger_dip",
                      "ring_finger_tip",
                      "pinky_mcp", "pinky_pip", "pinky_dip", "pinky_tip")
  expect_equal(as.character(cd$label), expected_names)
})


test_that("readMediaPipe handles missing landmarks gracefully", {
  skip_if_not_installed("jsonlite")
  dir <- file.path(tempdir(), paste0("mediapipe_missing_", sample(1e6, 1)))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE))

  # Write a frame with fewer landmarks than expected (e.g., 10 instead of 33)
  write_mediapipe_json(
    file.path(dir, "frame_000000.json"),
    n_landmarks = 10, seed = 42
  )

  pe <- readMediaPipe(dir, model = "pose", fps = 30)

  expect_s4_class(pe, "PhysioExperiment")
  x_mat <- SummarizedExperiment::assay(pe, "landmark_x")
  expect_equal(ncol(x_mat), 33)
  # First 10 landmarks should have data
  expect_false(all(is.na(x_mat[1, 1:10])))
  # Remaining 23 should be NA
  expect_true(all(is.na(x_mat[1, 11:33])))
})


test_that("readMediaPipe handles single frame (JSON directory with 1 file)", {
  skip_if_not_installed("jsonlite")
  mp_dir <- create_mediapipe_json_dir(n_frames = 1, n_landmarks = 33)
  on.exit(unlink(mp_dir, recursive = TRUE))

  pe <- readMediaPipe(mp_dir, model = "pose", fps = 30)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(nrow(SummarizedExperiment::assay(pe, "landmark_x")), 1)
  expect_equal(ncol(SummarizedExperiment::assay(pe, "landmark_x")), 33)
  expect_false(all(is.na(SummarizedExperiment::assay(pe, "landmark_x"))))
})


test_that("readMediaPipe handles single JSON file (not directory)", {
  skip_if_not_installed("jsonlite")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  write_mediapipe_json(tmp, n_landmarks = 33, seed = 99)

  pe <- readMediaPipe(tmp, model = "pose", fps = 24)

  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(PhysioCore::samplingRate(pe), 24)
  expect_equal(nrow(SummarizedExperiment::assay(pe, "landmark_x")), 1)
  expect_equal(ncol(SummarizedExperiment::assay(pe, "landmark_x")), 33)
})


test_that("readMediaPipe errors on non-existent path", {
  expect_error(readMediaPipe("/nonexistent/path/to/nowhere"),
               "Path does not exist")
})


test_that("readMediaPipe errors on empty directory (no JSON files)", {
  dir <- file.path(tempdir(), paste0("mediapipe_empty_", sample(1e6, 1)))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE))

  expect_error(readMediaPipe(dir, model = "pose", fps = 30),
               "No JSON files found")
})
