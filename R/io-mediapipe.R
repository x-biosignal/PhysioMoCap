# MediaPipe Reader
# Reads MediaPipe pose/hand landmark output into PhysioExperiment objects

#' Read MediaPipe landmark output
#'
#' Reads MediaPipe landmark data from a directory of per-frame JSON files
#' or a single CSV file and returns a PhysioExperiment object.
#'
#' @param path Path to a directory of JSON files or a single CSV file.
#' @param model Landmark model: `"pose"` (33 landmarks) or `"hand"`
#'   (21 landmarks). Default `"pose"`.
#' @param fps Frame rate in Hz (frames per second). Default 30.
#'
#' @return A PhysioExperiment with assays:
#' \describe{
#'   \item{landmark_x}{X coordinates matrix (frames x landmarks)}
#'   \item{landmark_y}{Y coordinates matrix (frames x landmarks)}
#'   \item{landmark_z}{Z coordinates matrix (frames x landmarks)}
#'   \item{visibility}{Visibility scores matrix (frames x landmarks)}
#' }
#'
#' If world landmarks are present (JSON with `world_landmarks` field),
#' additional assays are included:
#' \describe{
#'   \item{world_x}{World X coordinates matrix}
#'   \item{world_y}{World Y coordinates matrix}
#'   \item{world_z}{World Z coordinates matrix}
#' }
#'
#' The `colData` contains columns `label` (landmark name), `type`
#' (`"landmark"`), `model` (the MediaPipe model used), and `landmark_idx`
#' (0-based landmark index).
#'
#' @details
#' MediaPipe can output landmarks in two formats:
#'
#' **JSON (directory of per-frame files):** Each JSON file contains a
#' `"landmarks"` array where each element has `x`, `y`, `z`, and
#' `visibility` fields. Optionally, a `"world_landmarks"` array may be
#' present with world-space coordinates.
#'
#' **CSV (single file):** Columns named `landmark_0_x`, `landmark_0_y`,
#' `landmark_0_z`, `landmark_0_visibility`, `landmark_1_x`, etc. Each row
#' corresponds to one frame.
#'
#' **Pose model** (33 landmarks): Full body landmarks from nose to feet.
#'
#' **Hand model** (21 landmarks): Hand landmarks from wrist to fingertips.
#'
#' @examples
#' \dontrun{
#' # Read directory of MediaPipe JSON files
#' pe <- readMediaPipe("path/to/mediapipe_output/", model = "pose", fps = 30)
#'
#' # Read CSV format
#' pe <- readMediaPipe("path/to/landmarks.csv", model = "hand", fps = 60)
#' }
#'
#' @references
#' Lugaresi C, Tang J, Nash H, McClanahan C, Uboweja E, Hays M, Zhang F,
#' Chang CL, Yong MG, Lee J, et al. (2019). "MediaPipe: A Framework
#' for Building Perception Pipelines." arXiv:1906.08172.
#'
#' @seealso [readOpenPose()], [readDeepLabCut()], [define_skeleton()]
#'
#' @importFrom S4Vectors SimpleList DataFrame
#' @export
readMediaPipe <- function(path, model = c("pose", "hand"), fps = 30) {
  model <- match.arg(model)

  stopifnot(is.numeric(fps) && length(fps) == 1 && fps > 0)

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required for readMediaPipe(). ",
         "Install it with install.packages('jsonlite').", call. = FALSE)
  }

  # Get landmark names for this model
  lm_names <- .mediapipe_landmark_names(model)
  n_landmarks <- length(lm_names)

  # Determine input format: directory of JSONs or single CSV
  if (dir.exists(path)) {
    result <- .read_mediapipe_json_dir(path, n_landmarks)
  } else if (file.exists(path)) {
    ext <- tolower(tools::file_ext(path))
    if (ext == "csv") {
      result <- .parse_mediapipe_csv(path, n_landmarks)
    } else if (ext == "json") {
      # Single JSON file -- treat as one frame
      frame <- .parse_mediapipe_json(path)
      result <- .single_frame_to_result(frame, n_landmarks)
    } else {
      stop("Unsupported file extension: ", ext, ". Expected .csv or .json.",
           call. = FALSE)
    }
  } else {
    stop("Path does not exist: ", path, call. = FALSE)
  }

  n_frames <- nrow(result$landmark_x)

  # Set column names
  colnames(result$landmark_x) <- lm_names
  colnames(result$landmark_y) <- lm_names
  colnames(result$landmark_z) <- lm_names
  colnames(result$visibility) <- lm_names

  assay_list <- list(
    landmark_x = result$landmark_x,
    landmark_y = result$landmark_y,
    landmark_z = result$landmark_z,
    visibility = result$visibility
  )

  # Add world coordinates if present
  if (!is.null(result$world_x)) {
    colnames(result$world_x) <- lm_names
    colnames(result$world_y) <- lm_names
    colnames(result$world_z) <- lm_names
    assay_list$world_x <- result$world_x
    assay_list$world_y <- result$world_y
    assay_list$world_z <- result$world_z
  }

  PhysioExperiment(
    assays = SimpleList(assay_list),
    colData = DataFrame(
      label = lm_names,
      type = rep("landmark", n_landmarks),
      model = rep(model, n_landmarks),
      landmark_idx = seq(0L, n_landmarks - 1L)
    ),
    metadata = list(source_file = path),
    samplingRate = fps
  )
}


#' Get MediaPipe landmark names for a model
#'
#' @param model Character, either `"pose"` or `"hand"`.
#' @return Character vector of landmark names.
#' @keywords internal
#' @noRd
.mediapipe_landmark_names <- function(model) {
  if (model == "pose") {
    c("nose", "left_eye_inner", "left_eye", "left_eye_outer",
      "right_eye_inner", "right_eye", "right_eye_outer",
      "left_ear", "right_ear", "mouth_left", "mouth_right",
      "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
      "left_wrist", "right_wrist", "left_pinky", "right_pinky",
      "left_index", "right_index", "left_thumb", "right_thumb",
      "left_hip", "right_hip", "left_knee", "right_knee",
      "left_ankle", "right_ankle", "left_heel", "right_heel",
      "left_foot_index", "right_foot_index")
  } else if (model == "hand") {
    c("wrist", "thumb_cmc", "thumb_mcp", "thumb_ip", "thumb_tip",
      "index_finger_mcp", "index_finger_pip", "index_finger_dip",
      "index_finger_tip",
      "middle_finger_mcp", "middle_finger_pip", "middle_finger_dip",
      "middle_finger_tip",
      "ring_finger_mcp", "ring_finger_pip", "ring_finger_dip",
      "ring_finger_tip",
      "pinky_mcp", "pinky_pip", "pinky_dip", "pinky_tip")
  } else {
    stop("Unknown MediaPipe model: ", model,
         ". Supported models: 'pose', 'hand'.", call. = FALSE)
  }
}


#' Parse a single MediaPipe JSON frame
#'
#' @param file_path Path to a single JSON file.
#' @return A list with components `x`, `y`, `z`, `visibility` (each numeric
#'   vector), and optionally `world_x`, `world_y`, `world_z`. Returns
#'   `NULL` if landmarks are not found.
#' @keywords internal
#' @noRd
.parse_mediapipe_json <- function(file_path) {
  json_data <- jsonlite::fromJSON(file_path, simplifyVector = TRUE)

  landmarks <- json_data$landmarks
  if (is.null(landmarks)) return(NULL)

  # landmarks should be a data.frame or list with x, y, z, visibility

  if (is.data.frame(landmarks)) {
    x <- as.numeric(landmarks$x)
    y <- as.numeric(landmarks$y)
    z <- as.numeric(landmarks$z)
    vis <- if (!is.null(landmarks$visibility)) {
      as.numeric(landmarks$visibility)
    } else {
      rep(NA_real_, length(x))
    }
  } else if (is.list(landmarks)) {
    x <- vapply(landmarks, function(lm) as.numeric(lm$x %||% NA_real_), numeric(1))
    y <- vapply(landmarks, function(lm) as.numeric(lm$y %||% NA_real_), numeric(1))
    z <- vapply(landmarks, function(lm) as.numeric(lm$z %||% NA_real_), numeric(1))
    vis <- vapply(landmarks, function(lm) as.numeric(lm$visibility %||% NA_real_), numeric(1))
  } else {
    return(NULL)
  }

  result <- list(x = x, y = y, z = z, visibility = vis)

  # Check for world landmarks
  world_landmarks <- json_data$world_landmarks
  if (!is.null(world_landmarks)) {
    if (is.data.frame(world_landmarks)) {
      result$world_x <- as.numeric(world_landmarks$x)
      result$world_y <- as.numeric(world_landmarks$y)
      result$world_z <- as.numeric(world_landmarks$z)
    } else if (is.list(world_landmarks)) {
      result$world_x <- vapply(world_landmarks, function(lm) as.numeric(lm$x %||% NA_real_), numeric(1))
      result$world_y <- vapply(world_landmarks, function(lm) as.numeric(lm$y %||% NA_real_), numeric(1))
      result$world_z <- vapply(world_landmarks, function(lm) as.numeric(lm$z %||% NA_real_), numeric(1))
    }
  }

  result
}


#' Read a directory of MediaPipe JSON frame files
#'
#' @param path Path to directory containing JSON files.
#' @param n_landmarks Expected number of landmarks.
#' @return A list with matrices: landmark_x, landmark_y, landmark_z,
#'   visibility, and optionally world_x, world_y, world_z.
#' @keywords internal
#' @noRd
.read_mediapipe_json_dir <- function(path, n_landmarks) {
  json_files <- sort(list.files(path, pattern = "\\.json$", full.names = TRUE))
  if (length(json_files) == 0) {
    stop("No JSON files found in directory: ", path, call. = FALSE)
  }

  n_frames <- length(json_files)

  lm_x <- matrix(NA_real_, nrow = n_frames, ncol = n_landmarks)
  lm_y <- matrix(NA_real_, nrow = n_frames, ncol = n_landmarks)
  lm_z <- matrix(NA_real_, nrow = n_frames, ncol = n_landmarks)
  vis <- matrix(NA_real_, nrow = n_frames, ncol = n_landmarks)

  has_world <- FALSE
  w_x <- NULL
  w_y <- NULL
  w_z <- NULL

  for (i in seq_len(n_frames)) {
    frame <- .parse_mediapipe_json(json_files[i])
    if (!is.null(frame)) {
      n_lm <- min(length(frame$x), n_landmarks)
      lm_x[i, seq_len(n_lm)] <- frame$x[seq_len(n_lm)]
      lm_y[i, seq_len(n_lm)] <- frame$y[seq_len(n_lm)]
      lm_z[i, seq_len(n_lm)] <- frame$z[seq_len(n_lm)]
      vis[i, seq_len(n_lm)] <- frame$visibility[seq_len(n_lm)]

      if (!is.null(frame$world_x)) {
        if (!has_world) {
          has_world <- TRUE
          w_x <- matrix(NA_real_, nrow = n_frames, ncol = n_landmarks)
          w_y <- matrix(NA_real_, nrow = n_frames, ncol = n_landmarks)
          w_z <- matrix(NA_real_, nrow = n_frames, ncol = n_landmarks)
        }
        n_wlm <- min(length(frame$world_x), n_landmarks)
        w_x[i, seq_len(n_wlm)] <- frame$world_x[seq_len(n_wlm)]
        w_y[i, seq_len(n_wlm)] <- frame$world_y[seq_len(n_wlm)]
        w_z[i, seq_len(n_wlm)] <- frame$world_z[seq_len(n_wlm)]
      }
    }
  }

  result <- list(
    landmark_x = lm_x,
    landmark_y = lm_y,
    landmark_z = lm_z,
    visibility = vis
  )

  if (has_world) {
    result$world_x <- w_x
    result$world_y <- w_y
    result$world_z <- w_z
  }

  result
}


#' Convert a single parsed frame to a result structure
#'
#' @param frame Parsed frame from `.parse_mediapipe_json()`, or NULL.
#' @param n_landmarks Expected number of landmarks.
#' @return A list with 1-row matrices for each component.
#' @keywords internal
#' @noRd
.single_frame_to_result <- function(frame, n_landmarks) {
  lm_x <- matrix(NA_real_, nrow = 1, ncol = n_landmarks)
  lm_y <- matrix(NA_real_, nrow = 1, ncol = n_landmarks)
  lm_z <- matrix(NA_real_, nrow = 1, ncol = n_landmarks)
  vis <- matrix(NA_real_, nrow = 1, ncol = n_landmarks)
  w_x <- NULL
  w_y <- NULL
  w_z <- NULL

  if (!is.null(frame)) {
    n_lm <- min(length(frame$x), n_landmarks)
    lm_x[1, seq_len(n_lm)] <- frame$x[seq_len(n_lm)]
    lm_y[1, seq_len(n_lm)] <- frame$y[seq_len(n_lm)]
    lm_z[1, seq_len(n_lm)] <- frame$z[seq_len(n_lm)]
    vis[1, seq_len(n_lm)] <- frame$visibility[seq_len(n_lm)]

    if (!is.null(frame$world_x)) {
      w_x <- matrix(NA_real_, nrow = 1, ncol = n_landmarks)
      w_y <- matrix(NA_real_, nrow = 1, ncol = n_landmarks)
      w_z <- matrix(NA_real_, nrow = 1, ncol = n_landmarks)
      n_wlm <- min(length(frame$world_x), n_landmarks)
      w_x[1, seq_len(n_wlm)] <- frame$world_x[seq_len(n_wlm)]
      w_y[1, seq_len(n_wlm)] <- frame$world_y[seq_len(n_wlm)]
      w_z[1, seq_len(n_wlm)] <- frame$world_z[seq_len(n_wlm)]
    }
  }

  result <- list(
    landmark_x = lm_x,
    landmark_y = lm_y,
    landmark_z = lm_z,
    visibility = vis
  )

  if (!is.null(w_x)) {
    result$world_x <- w_x
    result$world_y <- w_y
    result$world_z <- w_z
  }

  result
}


#' Parse a MediaPipe CSV file
#'
#' Reads a CSV file with columns named `landmark_0_x`, `landmark_0_y`,
#' `landmark_0_z`, `landmark_0_visibility`, `landmark_1_x`, etc.
#'
#' @param path Path to the CSV file.
#' @param n_landmarks Expected number of landmarks.
#' @return A list with matrices: landmark_x, landmark_y, landmark_z,
#'   visibility.
#' @keywords internal
#' @noRd
.parse_mediapipe_csv <- function(path, n_landmarks) {
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  n_frames <- nrow(df)

  if (n_frames == 0) {
    stop("CSV file is empty: ", path, call. = FALSE)
  }

  lm_x <- matrix(NA_real_, nrow = n_frames, ncol = n_landmarks)
  lm_y <- matrix(NA_real_, nrow = n_frames, ncol = n_landmarks)
  lm_z <- matrix(NA_real_, nrow = n_frames, ncol = n_landmarks)
  vis <- matrix(NA_real_, nrow = n_frames, ncol = n_landmarks)

  for (j in seq_len(n_landmarks)) {
    idx <- j - 1L  # 0-based landmark index
    x_col <- paste0("landmark_", idx, "_x")
    y_col <- paste0("landmark_", idx, "_y")
    z_col <- paste0("landmark_", idx, "_z")
    v_col <- paste0("landmark_", idx, "_visibility")

    if (x_col %in% colnames(df)) lm_x[, j] <- as.numeric(df[[x_col]])
    if (y_col %in% colnames(df)) lm_y[, j] <- as.numeric(df[[y_col]])
    if (z_col %in% colnames(df)) lm_z[, j] <- as.numeric(df[[z_col]])
    if (v_col %in% colnames(df)) vis[, j] <- as.numeric(df[[v_col]])
  }

  list(
    landmark_x = lm_x,
    landmark_y = lm_y,
    landmark_z = lm_z,
    visibility = vis,
    world_x = NULL,
    world_y = NULL,
    world_z = NULL
  )
}
