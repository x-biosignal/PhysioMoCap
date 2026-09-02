# OpenPose JSON Reader
# Reads OpenPose keypoint detection output into PhysioExperiment objects

#' Read OpenPose JSON output
#'
#' Reads OpenPose JSON keypoint data from a directory of frame files
#' or a single JSON file and returns a PhysioExperiment object.
#'
#' @param path Path to a directory of JSON files or a single JSON file.
#' @param model Keypoint model: `"BODY_25"` (25 keypoints) or `"COCO"`
#'   (18 keypoints). Default `"BODY_25"`.
#' @param fps Frame rate in Hz (frames per second). Default 30.
#' @param person_id Which person to extract (1-based index). Default 1
#'   (first detected person).
#'
#' @return A PhysioExperiment with assays:
#' \describe{
#'   \item{keypoint_x}{X coordinates matrix (frames x keypoints)}
#'   \item{keypoint_y}{Y coordinates matrix (frames x keypoints)}
#'   \item{confidence}{Detection confidence matrix (frames x keypoints)}
#' }
#'
#' The `colData` contains columns `label` (keypoint name), `type`
#' (`"keypoint"`), and `model` (the OpenPose model used).
#'
#' @details
#' OpenPose outputs one JSON file per video frame. Each file contains a
#' `"people"` array where each person's pose is stored as a flat array
#' of `[x, y, confidence]` triplets.
#'
#' **BODY_25 model** (25 keypoints): Nose, Neck, RShoulder, RElbow,
#' RWrist, LShoulder, LElbow, LWrist, MidHip, RHip, RKnee, RAnkle,
#' LHip, LKnee, LAnkle, REye, LEye, REar, LEar, LBigToe, LSmallToe,
#' LHeel, RBigToe, RSmallToe, RHeel.
#'
#' **COCO model** (18 keypoints): Nose, Neck, RShoulder, RElbow,
#' RWrist, LShoulder, LElbow, LWrist, RHip, RKnee, RAnkle, LHip,
#' LKnee, LAnkle, REye, LEye, REar, LEar.
#'
#' Frames where the specified person is not detected will contain
#' `NA` values for all keypoints.
#'
#' @examples
#' \dontrun{
#' # Read directory of OpenPose JSON files
#' pe <- readOpenPose("path/to/openpose_output/", fps = 30)
#'
#' # Read with COCO model
#' pe <- readOpenPose("path/to/output/", model = "COCO", fps = 25)
#'
#' # Extract second person
#' pe <- readOpenPose("path/to/output/", person_id = 2)
#' }
#'
#' @references
#' Cao Z, Hidalgo G, Simon T, Wei SE, Sheikh Y (2019). "OpenPose:
#' Realtime Multi-Person 2D Pose Estimation Using Part Affinity Fields."
#' IEEE Transactions on Pattern Analysis and Machine Intelligence,
#' 43(1), 172-186.
#'
#' @seealso [readDeepLabCut()], [readMediaPipe()], [define_skeleton()]
#'
#' @importFrom S4Vectors SimpleList DataFrame
#' @export
readOpenPose <- function(path, model = c("BODY_25", "COCO"), fps = 30,
                         person_id = 1L) {
  model <- match.arg(model)
  person_id <- as.integer(person_id)

  stopifnot(is.numeric(fps) && length(fps) == 1 && fps > 0)

  stopifnot(is.integer(person_id) && length(person_id) == 1 && person_id >= 1L)

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required for readOpenPose(). ",
         "Install it with install.packages('jsonlite').", call. = FALSE)
  }

  # Define keypoint names based on model
  kp_names <- .openpose_keypoint_names(model)
  n_keypoints <- length(kp_names)

  # Determine if path is a directory or single file
  json_files <- .resolve_openpose_files(path)
  n_frames <- length(json_files)

  # Initialize matrices
  kp_x <- matrix(NA_real_, nrow = n_frames, ncol = n_keypoints)
  kp_y <- matrix(NA_real_, nrow = n_frames, ncol = n_keypoints)
  conf <- matrix(NA_real_, nrow = n_frames, ncol = n_keypoints)
  colnames(kp_x) <- kp_names
  colnames(kp_y) <- kp_names
  colnames(conf) <- kp_names

  # Read each JSON file
  for (i in seq_len(n_frames)) {
    result <- .parse_openpose_frame(json_files[i], person_id, n_keypoints)
    if (!is.null(result)) {
      kp_x[i, ] <- result$x
      kp_y[i, ] <- result$y
      conf[i, ] <- result$confidence
    }
  }

  # Create PhysioExperiment
  PhysioExperiment(
    assays = SimpleList(
      keypoint_x = kp_x,
      keypoint_y = kp_y,
      confidence = conf
    ),
    colData = DataFrame(
      label = kp_names,
      type = rep("keypoint", n_keypoints),
      model = rep(model, n_keypoints)
    ),
    samplingRate = fps
  )
}


#' Get OpenPose keypoint names for a model
#'
#' @param model Character, either `"BODY_25"` or `"COCO"`.
#' @return Character vector of keypoint names.
#' @keywords internal
#' @noRd
.openpose_keypoint_names <- function(model) {
  if (model == "BODY_25") {
    c("Nose", "Neck", "RShoulder", "RElbow", "RWrist",
      "LShoulder", "LElbow", "LWrist", "MidHip",
      "RHip", "RKnee", "RAnkle", "LHip", "LKnee", "LAnkle",
      "REye", "LEye", "REar", "LEar",
      "LBigToe", "LSmallToe", "LHeel",
      "RBigToe", "RSmallToe", "RHeel")
  } else {
    c("Nose", "Neck", "RShoulder", "RElbow", "RWrist",
      "LShoulder", "LElbow", "LWrist", "RHip", "RKnee", "RAnkle",
      "LHip", "LKnee", "LAnkle", "REye", "LEye", "REar", "LEar")
  }
}


#' Resolve OpenPose file paths
#'
#' Given a path (directory or file), returns a sorted vector of JSON file paths.
#'
#' @param path Path to a directory or single JSON file.
#' @return Character vector of JSON file paths.
#' @keywords internal
#' @noRd
.resolve_openpose_files <- function(path) {
  if (dir.exists(path)) {
    json_files <- sort(list.files(path, pattern = "\\.json$", full.names = TRUE))
    if (length(json_files) == 0) {
      stop("No JSON files found in directory: ", path, call. = FALSE)
    }
    json_files
  } else if (file.exists(path)) {
    path
  } else {
    stop("Path does not exist: ", path, call. = FALSE)
  }
}


#' Parse a single OpenPose JSON frame
#'
#' @param file_path Path to a single JSON file.
#' @param person_id Integer, 1-based person index.
#' @param n_keypoints Expected number of keypoints.
#' @return A list with components `x`, `y`, `confidence` (each numeric vector
#'   of length `n_keypoints`), or `NULL` if the person is not present.
#' @keywords internal
#' @noRd
.parse_openpose_frame <- function(file_path, person_id, n_keypoints) {
  json_data <- jsonlite::fromJSON(file_path, simplifyVector = TRUE)

  people <- json_data$people

  # No people detected in this frame
  if (is.null(people) || length(people) == 0) return(NULL)

  # Determine number of people and check person_id bounds
  n_people <- if (is.data.frame(people)) nrow(people) else length(people)
  if (person_id > n_people) return(NULL)

  # Extract the specified person's data
  # jsonlite can parse people as a data.frame or a list-of-lists
  if (is.data.frame(people)) {
    person <- people[person_id, ]
    keypoints <- unlist(person$pose_keypoints_2d)
  } else {
    person <- people[[person_id]]
    keypoints <- unlist(person$pose_keypoints_2d)
  }

  if (is.null(keypoints) || length(keypoints) < n_keypoints * 3) return(NULL)

  # Extract x, y, confidence from flattened [x0, y0, c0, x1, y1, c1, ...] triplets
  idx <- seq(1, n_keypoints * 3, by = 3)
  list(
    x = as.numeric(keypoints[idx]),
    y = as.numeric(keypoints[idx + 1]),
    confidence = as.numeric(keypoints[idx + 2])
  )
}
