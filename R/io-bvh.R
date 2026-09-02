# BVH File I/O Functions
# Reader for BVH (Biovision Hierarchy) skeleton animation files

#' Read BVH Skeleton Animation File (.bvh)
#'
#' Reads a BVH (Biovision Hierarchy) file containing skeleton animation data.
#' BVH files have two sections: HIERARCHY (joint tree structure with offsets
#' and channel definitions) and MOTION (frame data). The ROOT joint has 6
#' channels (3 position + 3 rotation), while child JOINTs have 3 channels
#' (rotation only).
#'
#' @param path Character string giving the path to the `.bvh` file.
#' @return A `PhysioExperiment` object with rotation assays (`rotation_x`,
#'   `rotation_y`, `rotation_z`) for all joints, and position assays
#'   (`position_x`, `position_y`, `position_z`) for the root joint.
#'   `colData` includes joint names (`label`), channel type (`type`), and
#'   `parent_joint`. `metadata` includes `bvh_skeleton` (hierarchy tree),
#'   `rotation_order`, `frame_time`, `offsets`, and `source_file`.
#'   `samplingRate` is computed as `1 / frame_time`.
#' @references
#' Meredith M, Maddock S (2001). "Motion Capture File Formats Explained."
#' Department of Computer Science, University of Sheffield.
#'
#' @seealso [readC3D()], [readTRC()], [readOpenPose()]
#'
#' @export
#' @examples
#' bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
#' if (nzchar(bvh_file)) {
#'   pe <- readBVH(bvh_file)
#'   pe
#' }
readBVH <- function(path) {
  stopifnot(file.exists(path))

  lines <- readLines(path, warn = FALSE)

  # Find where MOTION section begins
  motion_idx <- which(trimws(lines) == "MOTION")
  if (length(motion_idx) == 0) {
    stop("Could not find 'MOTION' section in BVH file: ", path, call. = FALSE)
  }
  motion_idx <- motion_idx[1]

  # Split into hierarchy and motion sections
  hierarchy_lines <- lines[seq_len(motion_idx - 1)]
  motion_lines <- lines[(motion_idx + 1):length(lines)]

  # Parse hierarchy
  skeleton <- .parse_bvh_hierarchy(hierarchy_lines)

  # Flatten the joint tree to get ordered channel info
  joint_info <- .flatten_bvh_joints(skeleton)

  # Total number of channels
  n_channels <- sum(vapply(joint_info, function(j) length(j$channels), integer(1)))

  # Parse motion data
  motion <- .parse_bvh_motion(motion_lines, n_channels)
  n_frames <- motion$n_frames
  frame_time <- motion$frame_time
  data_mat <- motion$data

  # Compute sampling rate
  sr <- if (!is.na(frame_time) && frame_time > 0) 1 / frame_time else NA_real_

  # Build assays: separate rotation and position channels

  # Identify joints that have channels (exclude End Sites)
  active_joints <- Filter(function(j) length(j$channels) > 0, joint_info)

  # Collect joint names (for columns)
  joint_names <- vapply(active_joints, function(j) j$name, character(1))

  # Build rotation matrices (all joints have rotation channels)
  rot_x <- matrix(NA_real_, nrow = n_frames, ncol = length(active_joints))
  rot_y <- matrix(NA_real_, nrow = n_frames, ncol = length(active_joints))
  rot_z <- matrix(NA_real_, nrow = n_frames, ncol = length(active_joints))
  colnames(rot_x) <- joint_names
  colnames(rot_y) <- joint_names
  colnames(rot_z) <- joint_names

  # Identify root joints (those with position channels)
  root_joints <- Filter(function(j) any(grepl("position", j$channels, ignore.case = TRUE)), active_joints)
  root_names <- vapply(root_joints, function(j) j$name, character(1))

  # Build position matrices (same ncol as rotation for SummarizedExperiment
  # compatibility, but only root joints have non-NA values)
  pos_x <- pos_y <- pos_z <- NULL
  if (length(root_names) > 0) {
    pos_x <- matrix(NA_real_, nrow = n_frames, ncol = length(active_joints))
    pos_y <- matrix(NA_real_, nrow = n_frames, ncol = length(active_joints))
    pos_z <- matrix(NA_real_, nrow = n_frames, ncol = length(active_joints))
    colnames(pos_x) <- joint_names
    colnames(pos_y) <- joint_names
    colnames(pos_z) <- joint_names
  }

  # Map channel data to assay matrices
  col_offset <- 0
  for (i in seq_along(active_joints)) {
    joint <- active_joints[[i]]
    channels <- joint$channels
    n_ch <- length(channels)

    for (k in seq_len(n_ch)) {
      ch_name <- tolower(channels[k])
      col_idx <- col_offset + k

      if (grepl("xposition", ch_name)) {
        if (joint$name %in% root_names) pos_x[, i] <- data_mat[, col_idx]
      } else if (grepl("yposition", ch_name)) {
        if (joint$name %in% root_names) pos_y[, i] <- data_mat[, col_idx]
      } else if (grepl("zposition", ch_name)) {
        if (joint$name %in% root_names) pos_z[, i] <- data_mat[, col_idx]
      } else if (grepl("xrotation", ch_name)) {
        rot_x[, i] <- data_mat[, col_idx]
      } else if (grepl("yrotation", ch_name)) {
        rot_y[, i] <- data_mat[, col_idx]
      } else if (grepl("zrotation", ch_name)) {
        rot_z[, i] <- data_mat[, col_idx]
      }
    }

    col_offset <- col_offset + n_ch
  }

  # Build assays list
  assays_list <- list(
    rotation_x = rot_x,
    rotation_y = rot_y,
    rotation_z = rot_z
  )
  if (!is.null(pos_x)) {
    assays_list[["position_x"]] <- pos_x
    assays_list[["position_y"]] <- pos_y
    assays_list[["position_z"]] <- pos_z
  }

  # Determine channel type and parent for colData
  joint_types <- vapply(active_joints, function(j) {
    if (any(grepl("position", j$channels, ignore.case = TRUE))) "position" else "rotation"
  }, character(1))

  parent_joints <- vapply(active_joints, function(j) {
    if (is.null(j$parent) || is.na(j$parent)) NA_character_ else j$parent
  }, character(1))

  # Extract rotation order from the first joint's rotation channels
  rotation_order <- .extract_rotation_order(active_joints[[1]]$channels)

  # Build offsets named list
  offsets <- lapply(joint_info, function(j) j$offset)
  names(offsets) <- vapply(joint_info, function(j) j$name, character(1))

  # Build metadata
  meta <- list(
    bvh_skeleton = skeleton,
    rotation_order = rotation_order,
    frame_time = frame_time,
    offsets = offsets,
    source_file = basename(path)
  )

  PhysioExperiment(
    assays = S4Vectors::SimpleList(assays_list),
    colData = S4Vectors::DataFrame(
      label = joint_names,
      type = joint_types,
      parent_joint = parent_joints
    ),
    metadata = meta,
    samplingRate = sr
  )
}

#' Parse BVH HIERARCHY section
#'
#' Performs a recursive descent parse of the HIERARCHY section of a BVH file.
#' Returns a nested list representing the joint tree structure.
#'
#' @param lines Character vector of hierarchy section lines.
#' @return A list representing the root joint with name, offset, channels,
#'   and children (each child being a similar list).
#' @keywords internal
#' @noRd
.parse_bvh_hierarchy <- function(lines) {
  # Remove empty/whitespace-only lines and trim
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]

  # Remove the "HIERARCHY" header line if present
  if (length(lines) > 0 && toupper(lines[1]) == "HIERARCHY") {
    lines <- lines[-1]
  }

  if (length(lines) == 0) {
    stop("Empty HIERARCHY section in BVH file", call. = FALSE)
  }

  env <- new.env(parent = emptyenv())
  env$pos <- 1
  env$lines <- lines

  result <- .parse_bvh_joint(env, parent_name = NA_character_)
  result
}

#' Parse a single BVH joint recursively
#'
#' @param env Environment containing `lines` and current `pos`.
#' @param parent_name Name of the parent joint (NA for root).
#' @return A list with name, offset, channels, children, parent.
#' @keywords internal
#' @noRd
.parse_bvh_joint <- function(env, parent_name = NA_character_) {
  lines <- env$lines

  if (env$pos > length(lines)) {
    stop("Unexpected end of HIERARCHY section", call. = FALSE)
  }

  # Current line should be ROOT/JOINT/End Site
  current_line <- lines[env$pos]

  # Determine joint type and name
  is_end_site <- grepl("^End\\s+Site", current_line, ignore.case = TRUE)

  if (is_end_site) {
    joint_name <- paste0(parent_name, "_End")
    joint_type <- "end_site"
  } else if (grepl("^ROOT\\s+", current_line, ignore.case = TRUE)) {
    joint_name <- sub("^ROOT\\s+", "", current_line, ignore.case = TRUE)
    joint_type <- "root"
  } else if (grepl("^JOINT\\s+", current_line, ignore.case = TRUE)) {
    joint_name <- sub("^JOINT\\s+", "", current_line, ignore.case = TRUE)
    joint_type <- "joint"
  } else {
    stop("Expected ROOT, JOINT, or End Site but got: ", current_line, call. = FALSE)
  }

  joint_name <- trimws(joint_name)
  env$pos <- env$pos + 1

  # Expect opening brace
  if (env$pos > length(lines) || trimws(lines[env$pos]) != "{") {
    stop("Expected '{' after joint declaration for: ", joint_name, call. = FALSE)
  }
  env$pos <- env$pos + 1

  # Parse joint contents
  offset <- c(0, 0, 0)
  channels <- character(0)
  children <- list()

  while (env$pos <= length(lines)) {
    line <- trimws(lines[env$pos])

    if (line == "}") {
      env$pos <- env$pos + 1
      break
    }

    if (grepl("^OFFSET\\s+", line, ignore.case = TRUE)) {
      offset_str <- sub("^OFFSET\\s+", "", line, ignore.case = TRUE)
      offset_vals <- as.numeric(strsplit(trimws(offset_str), "\\s+")[[1]])
      if (length(offset_vals) >= 3) {
        offset <- offset_vals[1:3]
      }
      env$pos <- env$pos + 1
    } else if (grepl("^CHANNELS\\s+", line, ignore.case = TRUE)) {
      ch_parts <- strsplit(sub("^CHANNELS\\s+", "", line, ignore.case = TRUE), "\\s+")[[1]]
      # First element is the count, rest are channel names
      n_ch <- as.integer(ch_parts[1])
      channels <- ch_parts[2:(n_ch + 1)]
      env$pos <- env$pos + 1
    } else if (grepl("^(ROOT|JOINT|End\\s+Site)", line, ignore.case = TRUE)) {
      # Recursively parse child joint
      child <- .parse_bvh_joint(env, parent_name = joint_name)
      children <- c(children, list(child))
    } else {
      # Skip unrecognized lines
      env$pos <- env$pos + 1
    }
  }

  list(
    name = joint_name,
    type = joint_type,
    offset = offset,
    channels = channels,
    children = children,
    parent = parent_name
  )
}

#' Parse BVH MOTION section
#'
#' Parses the MOTION section of a BVH file, extracting the number of frames,
#' frame time, and the numeric data matrix.
#'
#' @param lines Character vector of motion section lines (after "MOTION").
#' @param n_channels Expected number of data columns.
#' @return A list with `n_frames`, `frame_time`, and `data` (numeric matrix).
#' @keywords internal
#' @noRd
.parse_bvh_motion <- function(lines, n_channels) {
  # Remove empty lines
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]

  if (length(lines) < 2) {
    stop("MOTION section must have at least Frames and Frame Time lines",
         call. = FALSE)
  }

  # Parse "Frames: N"
  frames_line <- lines[1]
  if (!grepl("^Frames:\\s*", frames_line, ignore.case = TRUE)) {
    stop("Expected 'Frames:' line in MOTION section, got: ", frames_line,
         call. = FALSE)
  }
  n_frames <- as.integer(sub("^Frames:\\s*", "", frames_line, ignore.case = TRUE))

  # Parse "Frame Time: T"
  frametime_line <- lines[2]
  if (!grepl("^Frame\\s+Time:\\s*", frametime_line, ignore.case = TRUE)) {
    stop("Expected 'Frame Time:' line in MOTION section, got: ", frametime_line,
         call. = FALSE)
  }
  frame_time <- as.numeric(sub("^Frame\\s+Time:\\s*", "", frametime_line,
                                ignore.case = TRUE))

  # Parse data lines
  data_lines <- lines[-(1:2)]
  data_lines <- data_lines[nzchar(data_lines)]

  if (length(data_lines) == 0) {
    # Return empty matrix if no data lines
    data_mat <- matrix(NA_real_, nrow = 0, ncol = n_channels)
    return(list(n_frames = 0, frame_time = frame_time, data = data_mat))
  }

  data_mat <- do.call(rbind, lapply(data_lines, function(line) {
    as.numeric(strsplit(trimws(line), "\\s+")[[1]])
  }))

  if (!is.matrix(data_mat)) {
    data_mat <- matrix(data_mat, nrow = 1)
  }

  if (ncol(data_mat) != n_channels) {
    stop(sprintf(
      "BVH MOTION data has %d columns but HIERARCHY defines %d channels",
      ncol(data_mat), n_channels
    ), call. = FALSE)
  }

  list(n_frames = nrow(data_mat), frame_time = frame_time, data = data_mat)
}

#' Flatten BVH joint tree into an ordered list
#'
#' Traverses the joint tree depth-first and returns a flat list of joints
#' in the order their channels appear in the MOTION data.
#'
#' @param joint A joint list from `.parse_bvh_hierarchy()`.
#' @return A flat list of joint info lists.
#' @keywords internal
#' @noRd
.flatten_bvh_joints <- function(joint) {
  result <- list(list(
    name = joint$name,
    type = joint$type,
    offset = joint$offset,
    channels = joint$channels,
    parent = joint$parent
  ))

  if (length(joint$children) > 0) {
    for (child in joint$children) {
      result <- c(result, .flatten_bvh_joints(child))
    }
  }

  result
}

#' Extract rotation order from channel names
#'
#' @param channels Character vector of channel names.
#' @return Character string like "ZXY" representing rotation order.
#' @keywords internal
#' @noRd
.extract_rotation_order <- function(channels) {
  rot_channels <- channels[grepl("rotation", channels, ignore.case = TRUE)]
  if (length(rot_channels) == 0) return(NA_character_)

  # Extract axis letters (X, Y, Z) from channel names
  axes <- sub("([XYZ])rotation", "\\1", rot_channels, ignore.case = TRUE)
  axes <- toupper(axes)
  paste0(axes, collapse = "")
}
