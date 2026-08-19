# Skeleton Model Definitions
# Pre-built skeleton models for pose estimation and motion capture systems

#' Create a SkeletonModel object
#'
#' Constructs an S3 `SkeletonModel` object that defines a skeleton topology
#' for pose estimation or motion capture data. A skeleton consists of named
#' keypoints (joints/markers), bones connecting them, and an optional
#' hierarchical tree structure.
#'
#' @param name Character string identifying the skeleton model
#'   (e.g., `"BODY_25"`, `"COCO"`).
#' @param keypoints A `data.frame` with columns:
#'   \describe{
#'     \item{id}{Integer, 0-indexed keypoint identifier.}
#'     \item{label}{Character, human-readable keypoint name.}
#'     \item{body_region}{Character, anatomical region
#'       (e.g., `"head"`, `"torso"`, `"left_arm"`).}
#'   }
#' @param bones A `data.frame` with columns:
#'   \describe{
#'     \item{from_id}{Integer, source keypoint id.}
#'     \item{to_id}{Integer, target keypoint id.}
#'     \item{bone_name}{Character, descriptive name for the bone segment.}
#'   }
#' @param hierarchy Named list of parent-to-children relationships. Each
#'   element name is a parent keypoint label; the value is a character
#'   vector of child keypoint labels.
#' @param root_keypoint Character, label of the root keypoint in the
#'   hierarchy (e.g., `"MidHip"` for BODY_25).
#'
#' @return A `SkeletonModel` object (S3 class).
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [define_skeleton()], [get_bone_connections()], [get_segment_lengths()]
#'
#' @export
#' @examples
#' # Minimal skeleton
#' kp <- data.frame(
#'   id = 0:2,
#'   label = c("Head", "Torso", "Hip"),
#'   body_region = c("head", "torso", "pelvis")
#' )
#' bones <- data.frame(
#'   from_id = c(0, 1),
#'   to_id = c(1, 2),
#'   bone_name = c("neck", "spine")
#' )
#' hier <- list(Head = "Torso", Torso = "Hip")
#' sk <- SkeletonModel("mini", kp, bones, hier, "Head")
#' print(sk)
SkeletonModel <- function(name, keypoints, bones, hierarchy, root_keypoint) {

  stopifnot(is.character(name) && length(name) == 1)
  stopifnot(is.data.frame(keypoints))
  stopifnot(all(c("id", "label", "body_region") %in% colnames(keypoints)))
  stopifnot(is.data.frame(bones))
  stopifnot(all(c("from_id", "to_id", "bone_name") %in% colnames(bones)))
  stopifnot(is.list(hierarchy))
  stopifnot(is.character(root_keypoint) && length(root_keypoint) == 1)
  stopifnot(root_keypoint %in% keypoints$label)

  # Validate that bone endpoints reference valid keypoint ids
  all_ids <- keypoints$id
  if (!all(bones$from_id %in% all_ids)) {
    bad <- setdiff(bones$from_id, all_ids)
    stop("bones$from_id contains invalid keypoint ids: ",
         paste(bad, collapse = ", "), call. = FALSE)
  }
  if (!all(bones$to_id %in% all_ids)) {
    bad <- setdiff(bones$to_id, all_ids)
    stop("bones$to_id contains invalid keypoint ids: ",
         paste(bad, collapse = ", "), call. = FALSE)
  }

  structure(
    list(
      name = name,
      keypoints = keypoints,
      bones = bones,
      hierarchy = hierarchy,
      root_keypoint = root_keypoint
    ),
    class = "SkeletonModel"
  )
}


#' Print a SkeletonModel object
#'
#' @param x A `SkeletonModel` object.
#' @param ... Additional arguments (ignored).
#' @return Invisibly returns `x`.
#' @export
print.SkeletonModel <- function(x, ...) {
  cat("SkeletonModel:", x$name, "\n")
  cat("  Keypoints:", nrow(x$keypoints), "\n")
  cat("  Bones:    ", nrow(x$bones), "\n")
  cat("  Root:     ", x$root_keypoint, "\n")
  regions <- unique(x$keypoints$body_region)
  cat("  Regions:  ", paste(regions, collapse = ", "), "\n")
  invisible(x)
}


#' Create a pre-defined skeleton model
#'
#' Factory function that returns a `SkeletonModel` for a well-known
#' pose estimation or motion capture marker set.
#'
#' @param model_name Character string. One of:
#'   \describe{
#'     \item{`"BODY_25"`}{OpenPose BODY_25 model (25 keypoints, 24 bones).}
#'     \item{`"COCO"`}{OpenPose COCO model (18 keypoints, 17 bones).}
#'     \item{`"BlazePose"`}{MediaPipe BlazePose model (33 keypoints, 35 bones).}
#'     \item{`"PluginGait"`}{Vicon Plug-in Gait full-body marker set
#'       (39 markers, 38 bones).}
#'   }
#'
#' @return A `SkeletonModel` object.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [SkeletonModel()], [get_bone_connections()], [get_limb_pairs()]
#'
#' @export
#' @examples
#' sk <- define_skeleton("BODY_25")
#' print(sk)
#'
#' sk_coco <- define_skeleton("COCO")
#' get_bone_connections(sk_coco)
define_skeleton <- function(model_name) {
  model_name <- match.arg(model_name,
                          choices = c("BODY_25", "COCO", "BlazePose", "PluginGait"))

  switch(model_name,
    BODY_25   = .skeleton_body25(),
    COCO      = .skeleton_coco(),
    BlazePose = .skeleton_blazepose(),
    PluginGait = .skeleton_plugingait()
  )
}


#' Get bone connections from a skeleton
#'
#' Returns the bone connections as an edge list (data.frame) or as an
#' adjacency matrix.
#'
#' @param skeleton A `SkeletonModel` object.
#' @param as_matrix Logical. If `TRUE`, return a square adjacency matrix
#'   with keypoint labels as row/column names. Default `FALSE`.
#'
#' @return If `as_matrix = FALSE`, a `data.frame` with columns `from_label`,
#'   `to_label`, and `bone_name`. If `as_matrix = TRUE`, a symmetric
#'   logical adjacency matrix.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [SkeletonModel()], [define_skeleton()], [get_segment_lengths()]
#'
#' @export
#' @examples
#' sk <- define_skeleton("COCO")
#' edges <- get_bone_connections(sk)
#' head(edges)
#'
#' adj <- get_bone_connections(sk, as_matrix = TRUE)
#' dim(adj)
get_bone_connections <- function(skeleton, as_matrix = FALSE) {
  stopifnot(inherits(skeleton, "SkeletonModel"))

  kp <- skeleton$keypoints
  bones <- skeleton$bones

  # Map ids to labels
  id_to_label <- stats::setNames(as.character(kp$label), as.character(kp$id))
  from_labels <- id_to_label[as.character(bones$from_id)]
  to_labels <- id_to_label[as.character(bones$to_id)]

  if (!as_matrix) {
    data.frame(
      from_label = unname(from_labels),
      to_label = unname(to_labels),
      bone_name = bones$bone_name,
      stringsAsFactors = FALSE
    )
  } else {
    labels <- as.character(kp$label)
    n <- length(labels)
    adj <- matrix(FALSE, nrow = n, ncol = n,
                  dimnames = list(labels, labels))
    for (i in seq_len(nrow(bones))) {
      fl <- unname(from_labels[i])
      tl <- unname(to_labels[i])
      adj[fl, tl] <- TRUE
      adj[tl, fl] <- TRUE
    }
    adj
  }
}


#' Compute segment lengths from a PhysioExperiment and skeleton
#'
#' Calculates the Euclidean distance between connected keypoints for each
#' frame. The PhysioExperiment must contain `position_x`, `position_y`,
#' and (optionally) `position_z` assays with columns matching skeleton
#' keypoint labels.
#'
#' @param pe A `PhysioExperiment` object with position assays.
#' @param skeleton A `SkeletonModel` object whose keypoint labels match
#'   column names in the position assays.
#'
#' @return A matrix of segment lengths with dimensions
#'   (n_frames x n_bones). Column names are bone names.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [SkeletonModel()], [get_bone_connections()], [get_limb_pairs()]
#'
#' @export
#' @examples
#' \dontrun{
#' pe <- readOpenPose("path/to/frames/", model = "BODY_25")
#' sk <- define_skeleton("BODY_25")
#' lengths <- get_segment_lengths(pe, sk)
#' }
get_segment_lengths <- function(pe, skeleton) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  stopifnot(inherits(skeleton, "SkeletonModel"))

  anames <- SummarizedExperiment::assayNames(pe)
  has_x <- "position_x" %in% anames
  has_y <- "position_y" %in% anames
  has_z <- "position_z" %in% anames

  if (!has_x || !has_y) {
    stop("PhysioExperiment must contain 'position_x' and 'position_y' assays.",
         call. = FALSE)
  }

  pos_x <- SummarizedExperiment::assay(pe, "position_x")
  pos_y <- SummarizedExperiment::assay(pe, "position_y")
  pos_z <- if (has_z) SummarizedExperiment::assay(pe, "position_z") else NULL

  kp <- skeleton$keypoints
  bones <- skeleton$bones
  id_to_label <- stats::setNames(as.character(kp$label), as.character(kp$id))

  col_names <- colnames(pos_x)
  n_frames <- nrow(pos_x)
  n_bones <- nrow(bones)

  result <- matrix(NA_real_, nrow = n_frames, ncol = n_bones)
  colnames(result) <- bones$bone_name

  for (i in seq_len(n_bones)) {
    from_label <- id_to_label[as.character(bones$from_id[i])]
    to_label <- id_to_label[as.character(bones$to_id[i])]

    if (!(from_label %in% col_names) || !(to_label %in% col_names)) {
      next
    }

    dx <- pos_x[, from_label] - pos_x[, to_label]
    dy <- pos_y[, from_label] - pos_y[, to_label]

    if (!is.null(pos_z)) {
      dz <- pos_z[, from_label] - pos_z[, to_label]
      result[, i] <- sqrt(dx^2 + dy^2 + dz^2)
    } else {
      result[, i] <- sqrt(dx^2 + dy^2)
    }
  }

  result
}


#' Get left/right limb pairs for symmetry analysis
#'
#' Identifies corresponding left and right keypoint pairs in a skeleton
#' model, useful for bilateral symmetry analysis.
#'
#' @param skeleton A `SkeletonModel` object.
#'
#' @return A `data.frame` with columns `left` and `right`, where each
#'   row is a matched pair of keypoint labels.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [SkeletonModel()], [define_skeleton()], [get_segment_lengths()]
#'
#' @export
#' @examples
#' sk <- define_skeleton("BODY_25")
#' pairs <- get_limb_pairs(sk)
#' head(pairs)
get_limb_pairs <- function(skeleton) {
  stopifnot(inherits(skeleton, "SkeletonModel"))

  labels <- as.character(skeleton$keypoints$label)

  # Find pairs by matching L/R prefixes

  left_labels <- labels[grepl("^L", labels)]
  pairs_list <- list()

  for (ll in left_labels) {
    # Replace leading "L" with "R"
    rl <- sub("^L", "R", ll)
    if (rl %in% labels) {
      pairs_list[[length(pairs_list) + 1]] <- data.frame(
        left = ll, right = rl, stringsAsFactors = FALSE
      )
    }
  }

  if (length(pairs_list) == 0) {
    return(data.frame(left = character(0), right = character(0),
                      stringsAsFactors = FALSE))
  }

  do.call(rbind, pairs_list)
}


# ---------------------------------------------------------------------------
# Internal skeleton model builders
# ---------------------------------------------------------------------------

#' Build BODY_25 skeleton (OpenPose)
#' @keywords internal
#' @noRd
.skeleton_body25 <- function() {
  # 25 keypoints, 0-indexed (OpenPose convention)
  keypoints <- data.frame(
    id = 0:24,
    label = c(
      "Nose", "Neck", "RShoulder", "RElbow", "RWrist",
      "LShoulder", "LElbow", "LWrist", "MidHip",
      "RHip", "RKnee", "RAnkle", "LHip", "LKnee", "LAnkle",
      "REye", "LEye", "REar", "LEar",
      "LBigToe", "LSmallToe", "LHeel",
      "RBigToe", "RSmallToe", "RHeel"
    ),
    body_region = c(
      "head", "torso", "right_arm", "right_arm", "right_arm",
      "left_arm", "left_arm", "left_arm", "pelvis",
      "right_leg", "right_leg", "right_leg",
      "left_leg", "left_leg", "left_leg",
      "head", "head", "head", "head",
      "left_foot", "left_foot", "left_foot",
      "right_foot", "right_foot", "right_foot"
    ),
    stringsAsFactors = FALSE
  )

  # 24 bones from OpenPose POSE_BODY_25_PAIRS_RENDER_GPU
  # Pairs: 1-8, 1-2, 1-5, 2-3, 3-4, 5-6, 6-7, 8-9, 9-10, 10-11,
  #         8-12, 12-13, 13-14, 1-0, 0-15, 15-17, 0-16, 16-18,
  #         14-19, 19-20, 14-21, 11-22, 22-23, 11-24
  bones <- data.frame(
    from_id = c(1, 1, 1, 2, 3, 5, 6, 8, 9, 10,
                8, 12, 13, 1, 0, 15, 0, 16,
                14, 19, 14, 11, 22, 11),
    to_id   = c(8, 2, 5, 3, 4, 6, 7, 9, 10, 11,
                12, 13, 14, 0, 15, 17, 16, 18,
                19, 20, 21, 22, 23, 24),
    bone_name = c(
      "spine", "right_clavicle", "left_clavicle",
      "right_upper_arm", "right_forearm",
      "left_upper_arm", "left_forearm",
      "right_hip_joint", "right_thigh", "right_shank",
      "left_hip_joint", "left_thigh", "left_shank",
      "neck", "nose_to_right_eye", "right_eye_to_ear",
      "nose_to_left_eye", "left_eye_to_ear",
      "left_ankle_to_bigtoe", "left_bigtoe_to_smalltoe", "left_ankle_to_heel",
      "right_ankle_to_bigtoe", "right_bigtoe_to_smalltoe", "right_ankle_to_heel"
    ),
    stringsAsFactors = FALSE
  )

  hierarchy <- list(
    MidHip = c("Neck", "RHip", "LHip"),
    Neck = c("Nose", "RShoulder", "LShoulder"),
    Nose = c("REye", "LEye"),
    REye = "REar",
    LEye = "LEar",
    RShoulder = c("RElbow"),
    RElbow = "RWrist",
    LShoulder = c("LElbow"),
    LElbow = "LWrist",
    RHip = "RKnee",
    RKnee = "RAnkle",
    RAnkle = c("RBigToe", "RHeel"),
    RBigToe = "RSmallToe",
    LHip = "LKnee",
    LKnee = "LAnkle",
    LAnkle = c("LBigToe", "LHeel"),
    LBigToe = "LSmallToe"
  )

  SkeletonModel("BODY_25", keypoints, bones, hierarchy, "MidHip")
}


#' Build COCO skeleton (OpenPose COCO)
#' @keywords internal
#' @noRd
.skeleton_coco <- function() {
  # 18 keypoints, 0-indexed
  keypoints <- data.frame(
    id = 0:17,
    label = c(
      "Nose", "Neck", "RShoulder", "RElbow", "RWrist",
      "LShoulder", "LElbow", "LWrist",
      "RHip", "RKnee", "RAnkle",
      "LHip", "LKnee", "LAnkle",
      "REye", "LEye", "REar", "LEar"
    ),
    body_region = c(
      "head", "torso",
      "right_arm", "right_arm", "right_arm",
      "left_arm", "left_arm", "left_arm",
      "right_leg", "right_leg", "right_leg",
      "left_leg", "left_leg", "left_leg",
      "head", "head", "head", "head"
    ),
    stringsAsFactors = FALSE
  )

  # 17 bones from OpenPose COCO pairs
  # Pairs: 1-2, 1-5, 2-3, 3-4, 5-6, 6-7, 1-8, 8-9, 9-10,
  #         1-11, 11-12, 12-13, 1-0, 0-14, 14-16, 0-15, 15-17
  bones <- data.frame(
    from_id = c(1, 1, 2, 3, 5, 6, 1, 8, 9,
                1, 11, 12, 1, 0, 14, 0, 15),
    to_id   = c(2, 5, 3, 4, 6, 7, 8, 9, 10,
                11, 12, 13, 0, 14, 16, 15, 17),
    bone_name = c(
      "right_clavicle", "left_clavicle",
      "right_upper_arm", "right_forearm",
      "left_upper_arm", "left_forearm",
      "right_hip_joint", "right_thigh", "right_shank",
      "left_hip_joint", "left_thigh", "left_shank",
      "neck", "nose_to_right_eye", "right_eye_to_ear",
      "nose_to_left_eye", "left_eye_to_ear"
    ),
    stringsAsFactors = FALSE
  )

  hierarchy <- list(
    Neck = c("Nose", "RShoulder", "LShoulder", "RHip", "LHip"),
    Nose = c("REye", "LEye"),
    REye = "REar",
    LEye = "LEar",
    RShoulder = "RElbow",
    RElbow = "RWrist",
    LShoulder = "LElbow",
    LElbow = "LWrist",
    RHip = "RKnee",
    RKnee = "RAnkle",
    LHip = "LKnee",
    LKnee = "LAnkle"
  )

  SkeletonModel("COCO", keypoints, bones, hierarchy, "Neck")
}


#' Build BlazePose skeleton (MediaPipe)
#' @keywords internal
#' @noRd
.skeleton_blazepose <- function() {
  # 33 keypoints, 0-indexed (MediaPipe convention)
  keypoints <- data.frame(
    id = 0:32,
    label = c(
      "Nose",                                         # 0
      "LEyeInner", "LEye", "LEyeOuter",              # 1-3
      "REyeInner", "REye", "REyeOuter",              # 4-6
      "LEar", "REar",                                 # 7-8
      "LMouth", "RMouth",                             # 9-10
      "LShoulder", "RShoulder",                       # 11-12
      "LElbow", "RElbow",                             # 13-14
      "LWrist", "RWrist",                             # 15-16
      "LPinky", "RPinky",                             # 17-18
      "LIndex", "RIndex",                             # 19-20
      "LThumb", "RThumb",                             # 21-22
      "LHip", "RHip",                                 # 23-24
      "LKnee", "RKnee",                               # 25-26
      "LAnkle", "RAnkle",                             # 27-28
      "LHeel", "RHeel",                               # 29-30
      "LFootIndex", "RFootIndex"                      # 31-32
    ),
    body_region = c(
      "head",
      "head", "head", "head",
      "head", "head", "head",
      "head", "head",
      "head", "head",
      "left_arm", "right_arm",
      "left_arm", "right_arm",
      "left_arm", "right_arm",
      "left_hand", "right_hand",
      "left_hand", "right_hand",
      "left_hand", "right_hand",
      "left_leg", "right_leg",
      "left_leg", "right_leg",
      "left_leg", "right_leg",
      "left_foot", "right_foot",
      "left_foot", "right_foot"
    ),
    stringsAsFactors = FALSE
  )

  # 35 bones (MediaPipe POSE_CONNECTIONS)
  bones <- data.frame(
    from_id = c(
      # Face (8)
      0, 0, 1, 2, 3, 4, 5, 6,
      # Mouth (1)
      9,
      # Torso (4)
      11, 11, 12, 23,
      # Left arm (6)
      11, 13, 15, 15, 15, 17,
      # Right arm (6)
      12, 14, 16, 16, 16, 18,
      # Left leg (5)
      23, 25, 27, 27, 29,
      # Right leg (5)
      24, 26, 28, 28, 30
    ),
    to_id = c(
      # Face (8)
      1, 4, 2, 3, 7, 5, 6, 8,
      # Mouth (1)
      10,
      # Torso (4)
      12, 23, 24, 24,
      # Left arm (6)
      13, 15, 17, 19, 21, 19,
      # Right arm (6)
      14, 16, 18, 20, 22, 20,
      # Left leg (5)
      25, 27, 29, 31, 31,
      # Right leg (5)
      26, 28, 30, 32, 32
    ),
    bone_name = c(
      # Face (8)
      "nose_to_left_eye_inner", "nose_to_right_eye_inner",
      "left_eye_inner_to_eye", "left_eye_to_outer",
      "left_eye_outer_to_ear",
      "right_eye_inner_to_eye", "right_eye_to_outer",
      "right_eye_outer_to_ear",
      # Mouth (1)
      "mouth",
      # Torso (4)
      "shoulders", "left_torso", "right_torso", "hips",
      # Left arm (6)
      "left_upper_arm", "left_forearm",
      "left_wrist_to_pinky", "left_wrist_to_index", "left_wrist_to_thumb",
      "left_pinky_to_index",
      # Right arm (6)
      "right_upper_arm", "right_forearm",
      "right_wrist_to_pinky", "right_wrist_to_index", "right_wrist_to_thumb",
      "right_pinky_to_index",
      # Left leg (5)
      "left_thigh", "left_shank",
      "left_ankle_to_heel", "left_ankle_to_foot_index",
      "left_heel_to_foot_index",
      # Right leg (5)
      "right_thigh", "right_shank",
      "right_ankle_to_heel", "right_ankle_to_foot_index",
      "right_heel_to_foot_index"
    ),
    stringsAsFactors = FALSE
  )

  hierarchy <- list(
    Nose = c("LEyeInner", "REyeInner", "LMouth"),
    LEyeInner = "LEye",
    LEye = "LEyeOuter",
    LEyeOuter = "LEar",
    REyeInner = "REye",
    REye = "REyeOuter",
    REyeOuter = "REar",
    LMouth = "RMouth",
    LShoulder = c("LElbow", "LHip", "RShoulder"),
    RShoulder = c("RElbow", "RHip"),
    LElbow = "LWrist",
    LWrist = c("LPinky", "LIndex", "LThumb"),
    LPinky = "LIndex",
    RElbow = "RWrist",
    RWrist = c("RPinky", "RIndex", "RThumb"),
    RPinky = "RIndex",
    LHip = c("LKnee", "RHip"),
    RHip = "RKnee",
    LKnee = "LAnkle",
    LAnkle = c("LHeel", "LFootIndex"),
    LHeel = "LFootIndex",
    RKnee = "RAnkle",
    RAnkle = c("RHeel", "RFootIndex"),
    RHeel = "RFootIndex"
  )

  SkeletonModel("BlazePose", keypoints, bones, hierarchy, "Nose")
}


#' Build PluginGait skeleton (Vicon)
#' @keywords internal
#' @noRd
.skeleton_plugingait <- function() {
  # 39 markers for Vicon Plug-in Gait full-body model, 0-indexed
  keypoints <- data.frame(
    id = 0:38,
    label = c(
      # Head (4)
      "LFHD", "RFHD", "LBHD", "RBHD",
      # Trunk (5)
      "C7", "T10", "CLAV", "STRN", "RBAK",
      # Left arm (6)
      "LSHO", "LUPA", "LELB", "LFRA", "LWRA", "LWRB",
      # Right arm (6)
      "RSHO", "RUPA", "RELB", "RFRA", "RWRA", "RWRB",
      # Hands (2)
      "LFIN", "RFIN",
      # Pelvis (4)
      "LASI", "RASI", "LPSI", "RPSI",
      # Left leg (6)
      "LTHI", "LKNE", "LTIB", "LANK", "LTOE", "LHEE",
      # Right leg (6)
      "RTHI", "RKNE", "RTIB", "RANK", "RTOE", "RHEE"
    ),
    body_region = c(
      # Head
      rep("head", 4),
      # Trunk
      rep("torso", 5),
      # Left arm
      rep("left_arm", 6),
      # Right arm
      rep("right_arm", 6),
      # Hands
      "left_hand", "right_hand",
      # Pelvis
      rep("pelvis", 4),
      # Left leg
      rep("left_leg", 6),
      # Right leg
      rep("right_leg", 6)
    ),
    stringsAsFactors = FALSE
  )

  # 38 bones connecting the markers in an anatomically meaningful way
  bones <- data.frame(
    from_id = c(
      # Head (3)
      0, 1, 2,
      # Head to trunk (2)
      0, 1,
      # Trunk (4)
      4, 6, 6, 7,
      # Trunk to pelvis (2)
      4, 7,
      # Pelvis (3)
      23, 24, 25,
      # Left arm chain (7)
      9, 9, 10, 11, 11, 13, 14,
      # Right arm chain (7)
      15, 15, 16, 17, 17, 19, 20,
      # Left leg chain (5)
      23, 27, 28, 29, 30,
      # Right leg chain (5)
      24, 32, 33, 34, 35
    ),
    to_id = c(
      # Head (3)
      1, 3, 3,
      # Head to trunk (2)
      6, 6,
      # Trunk (4)
      5, 7, 4, 5,
      # Trunk to pelvis (2)
      25, 23,
      # Pelvis (3)
      24, 25, 26,
      # Left arm chain (7)
      6, 10, 11, 12, 13, 14, 21,
      # Right arm chain (7)
      6, 16, 17, 18, 19, 20, 22,
      # Left leg chain (5)
      27, 28, 29, 30, 31,
      # Right leg chain (5)
      32, 33, 34, 35, 36
    ),
    bone_name = c(
      # Head (3)
      "head_front", "head_right", "head_back",
      # Head to trunk (2)
      "left_head_to_clav", "right_head_to_clav",
      # Trunk (4)
      "c7_to_t10", "clav_to_strn", "clav_to_c7", "strn_to_t10",
      # Trunk to pelvis (2)
      "c7_to_lpsi", "strn_to_lasi",
      # Pelvis (3)
      "lasi_to_rasi", "rasi_to_lpsi", "lpsi_to_rpsi",
      # Left arm chain (7)
      "left_shoulder_to_clav", "left_shoulder_to_upa",
      "left_upper_arm", "left_elbow_to_fra",
      "left_elbow_to_wra", "left_wra_to_wrb", "left_wrb_to_fin",
      # Right arm chain (7)
      "right_shoulder_to_clav", "right_shoulder_to_upa",
      "right_upper_arm", "right_elbow_to_fra",
      "right_elbow_to_wra", "right_wra_to_wrb", "right_wrb_to_fin",
      # Left leg chain (5)
      "left_asi_to_thi", "left_thigh",
      "left_knee_to_tib", "left_shank", "left_ankle_to_toe",
      # Right leg chain (5)
      "right_asi_to_thi", "right_thigh",
      "right_knee_to_tib", "right_shank", "right_ankle_to_toe"
    ),
    stringsAsFactors = FALSE
  )

  hierarchy <- list(
    CLAV = c("C7", "STRN", "LSHO", "RSHO", "LFHD", "RFHD"),
    C7 = c("T10", "LPSI"),
    STRN = c("T10", "LASI"),
    LFHD = c("RFHD", "LBHD"),
    RFHD = "RBHD",
    LBHD = "RBHD",
    LSHO = c("LUPA", "LELB"),
    LUPA = "LELB",
    LELB = c("LFRA", "LWRA"),
    LWRA = "LWRB",
    LWRB = "LFIN",
    RSHO = c("RUPA", "RELB"),
    RUPA = "RELB",
    RELB = c("RFRA", "RWRA"),
    RWRA = "RWRB",
    RWRB = "RFIN",
    LASI = c("RASI", "LTHI"),
    RASI = c("LPSI", "RTHI"),
    LPSI = "RPSI",
    RPSI = "LASI",
    LTHI = "LKNE",
    LKNE = c("LTIB", "LANK"),
    LANK = c("LTOE", "LHEE"),
    LTOE = "LHEE",
    RTHI = "RKNE",
    RKNE = c("RTIB", "RANK"),
    RANK = c("RTOE", "RHEE"),
    RTOE = "RHEE"
  )

  SkeletonModel("PluginGait", keypoints, bones, hierarchy, "CLAV")
}
