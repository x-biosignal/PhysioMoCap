# ASF/AMC File I/O Functions
# Reader for Acclaim Skeleton File (ASF) and Acclaim Motion Capture (AMC) files

#' Read ASF Skeleton Definition File (.asf)
#'
#' Parses an Acclaim Skeleton File (ASF) that defines the skeleton hierarchy,
#' bone properties, and degrees of freedom. ASF files contain sections for
#' units, root configuration, bone data, and hierarchy relationships.
#'
#' @param path Character string giving the path to the `.asf` file.
#' @return An S3 object of class `"ASFSkeleton"` with components:
#'   \describe{
#'     \item{units}{Named list of unit definitions (mass, length, angle).}
#'     \item{root}{List with root joint configuration: position, orientation,
#'       order, and axis.}
#'     \item{bones}{Named list of bone definitions, each with id, name,
#'       direction, length, axis, dof, and limits.}
#'     \item{hierarchy}{Named list mapping parent joint names to character
#'       vectors of child joint names.}
#'   }
#'
#' @references
#' CMU Graphics Lab (2003). "CMU Motion Capture Database."
#' \url{http://mocap.cs.cmu.edu/}.
#'
#' @seealso [readAMC()] for reading motion data in AMC format,
#'   [print.ASFSkeleton()] for displaying skeleton structure.
#'
#' @export
#' @examples
#' asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
#' if (nzchar(asf_file)) {
#'   skel <- readASF(asf_file)
#'   skel
#' }
readASF <- function(path) {
  stopifnot(file.exists(path))


  lines <- readLines(path, warn = FALSE)

  # Remove comment lines (starting with #)
  lines <- lines[!grepl("^\\s*#", lines)]

  # Parse sections
  units <- .parse_asf_units(lines)
  root <- .parse_asf_root(lines)
  bones <- .parse_asf_bonedata(lines)
  hierarchy <- .parse_asf_hierarchy(lines)

  result <- list(
    units = units,
    root = root,
    bones = bones,
    hierarchy = hierarchy
  )
  class(result) <- "ASFSkeleton"
  result
}

#' Read AMC Motion Capture File (.amc)
#'
#' Parses an Acclaim Motion Capture (AMC) file containing frame-by-frame joint
#' angle data. AMC files store joint angles per frame, with each frame listing
#' joint names followed by their DOF values. An optional ASF skeleton can be
#' provided for validation and DOF mapping.
#'
#' @param path Character string giving the path to the `.amc` file.
#' @param asf An `ASFSkeleton` object (from [readASF()]), or `NULL`. If
#'   provided, used for DOF validation and enriched metadata.
#' @param fps Numeric frame rate in Hz. AMC files do not store frame rate, so
#'   this must be specified (default: 120).
#' @return A `PhysioExperiment` object with:
#'   \describe{
#'     \item{assays}{`rotation_x`, `rotation_y`, `rotation_z` for all joints;
#'       `position_x`, `position_y`, `position_z` for the root joint only.}
#'     \item{colData}{DataFrame with `label` (joint names), `type`
#'       (`"root"` or `"joint"`), and `dof_count` (number of DOFs).}
#'     \item{metadata}{List with `asf_skeleton` (if provided), `source_file`,
#'       and `units` (from ASF if provided).}
#'     \item{samplingRate}{Set to `fps`.}
#'   }
#'
#' @references
#' CMU Graphics Lab (2003). "CMU Motion Capture Database."
#' \url{http://mocap.cs.cmu.edu/}.
#'
#' @seealso [readASF()] for reading skeleton definitions in ASF format,
#'   [readMoCapCSV()] for reading motion capture data from CSV files.
#'
#' @export
#' @examples
#' asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
#' amc_file <- system.file("testdata", "sample.amc", package = "PhysioMoCap")
#' if (nzchar(asf_file) && nzchar(amc_file)) {
#'   skel <- readASF(asf_file)
#'   pe <- readAMC(amc_file, asf = skel)
#'   pe
#' }
readAMC <- function(path, asf = NULL, fps = 120) {
  stopifnot(file.exists(path))
  if (!is.null(asf)) {
    stopifnot(inherits(asf, "ASFSkeleton"))
  }
  stopifnot(is.numeric(fps) && fps > 0)

  lines <- readLines(path, warn = FALSE)

  # Remove comment lines and header directives
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]
  lines <- lines[!grepl("^#", lines)]
  lines <- lines[!grepl("^:", lines)]

  # Parse frames
  frames <- .parse_amc_frames(lines)

  if (length(frames) == 0) {
    stop("No frame data found in AMC file: ", path, call. = FALSE)
  }

  n_frames <- length(frames)

  # Determine all joint names and their DOF counts from the data
  # Use the first frame as reference
  first_frame <- frames[[1]]
  joint_names <- names(first_frame)

  # Determine if each joint is root or regular joint
  # Root has 6 DOFs (3 position + 3 rotation), joints have 1-3 rotation DOFs
  # Convention: "root" is the root joint name in AMC
  joint_types <- character(length(joint_names))
  dof_counts <- integer(length(joint_names))
  for (i in seq_along(joint_names)) {
    n_dof <- length(first_frame[[joint_names[i]]])
    dof_counts[i] <- n_dof
    if (tolower(joint_names[i]) == "root") {
      joint_types[i] <- "root"
    } else {
      joint_types[i] <- "joint"
    }
  }

  # Build assay matrices
  # Rotation assays: all joints get rotation columns
  # Position assays: only root gets non-NA values
  rot_x <- matrix(NA_real_, nrow = n_frames, ncol = length(joint_names))
  rot_y <- matrix(NA_real_, nrow = n_frames, ncol = length(joint_names))
  rot_z <- matrix(NA_real_, nrow = n_frames, ncol = length(joint_names))
  colnames(rot_x) <- joint_names
  colnames(rot_y) <- joint_names
  colnames(rot_z) <- joint_names

  pos_x <- matrix(NA_real_, nrow = n_frames, ncol = length(joint_names))
  pos_y <- matrix(NA_real_, nrow = n_frames, ncol = length(joint_names))
  pos_z <- matrix(NA_real_, nrow = n_frames, ncol = length(joint_names))
  colnames(pos_x) <- joint_names
  colnames(pos_y) <- joint_names
  colnames(pos_z) <- joint_names

  # Fill in data from frames
  for (f in seq_len(n_frames)) {
    frame <- frames[[f]]
    for (jname in joint_names) {
      if (!jname %in% names(frame)) next
      values <- frame[[jname]]
      j_idx <- which(joint_names == jname)

      if (tolower(jname) == "root") {
        # Root: first 3 values are position (TX, TY, TZ),
        # next 3 are rotation (RX, RY, RZ)
        if (length(values) >= 6) {
          pos_x[f, j_idx] <- values[1]
          pos_y[f, j_idx] <- values[2]
          pos_z[f, j_idx] <- values[3]
          rot_x[f, j_idx] <- values[4]
          rot_y[f, j_idx] <- values[5]
          rot_z[f, j_idx] <- values[6]
        }
      } else {
        # Non-root joints: DOF values are rotation axes
        # Map based on ASF dof if available, otherwise assume rx, ry, rz order
        dof_names <- NULL
        if (!is.null(asf) && jname %in% names(asf$bones)) {
          dof_names <- asf$bones[[jname]]$dof
        }

        if (!is.null(dof_names)) {
          # Map each DOF value to its axis
          for (d in seq_along(dof_names)) {
            if (d > length(values)) break
            dof_name <- tolower(dof_names[d])
            if (dof_name == "rx") {
              rot_x[f, j_idx] <- values[d]
            } else if (dof_name == "ry") {
              rot_y[f, j_idx] <- values[d]
            } else if (dof_name == "rz") {
              rot_z[f, j_idx] <- values[d]
            }
          }
        } else {
          # No ASF: assume rx, ry, rz order based on count
          if (length(values) >= 1) rot_x[f, j_idx] <- values[1]
          if (length(values) >= 2) rot_y[f, j_idx] <- values[2]
          if (length(values) >= 3) rot_z[f, j_idx] <- values[3]
        }
      }
    }
  }

  # Build assays list
  assays_list <- list(
    rotation_x = rot_x,
    rotation_y = rot_y,
    rotation_z = rot_z,
    position_x = pos_x,
    position_y = pos_y,
    position_z = pos_z
  )

  # Build metadata
  meta <- list(
    source_file = basename(path)
  )
  if (!is.null(asf)) {
    meta$asf_skeleton <- asf
    meta$units <- asf$units
  }

  PhysioExperiment(
    assays = S4Vectors::SimpleList(assays_list),
    colData = S4Vectors::DataFrame(
      label = joint_names,
      type = joint_types,
      dof_count = dof_counts
    ),
    metadata = meta,
    samplingRate = fps
  )
}

#' Print method for ASFSkeleton objects
#'
#' @param x An `ASFSkeleton` object.
#' @param ... Additional arguments (ignored).
#' @return Invisibly returns `x`.
#'
#' @references
#' CMU Graphics Lab (2003). "CMU Motion Capture Database."
#' \url{http://mocap.cs.cmu.edu/}.
#'
#' @seealso [readASF()] for reading ASF skeleton files,
#'   [readAMC()] for reading AMC motion data.
#'
#' @export
print.ASFSkeleton <- function(x, ...) {
  cat("ASF Skeleton\n")

  # Units
  if (length(x$units) > 0) {
    cat("  Units:", paste(names(x$units), "=", x$units, collapse = ", "), "\n")
  }

  # Root
  if (!is.null(x$root)) {
    cat("  Root: position =", paste(x$root$position, collapse = ", "),
        "| order =", paste(x$root$order, collapse = " "), "\n")
  }

  # Bones
  n_bones <- length(x$bones)
  cat("  Bones:", n_bones, "\n")
  if (n_bones > 0) {
    bone_names <- vapply(x$bones, function(b) b$name, character(1))
    cat("    Names:", paste(bone_names, collapse = ", "), "\n")
  }

  # Hierarchy
  if (length(x$hierarchy) > 0) {
    cat("  Hierarchy:\n")
    for (parent in names(x$hierarchy)) {
      children <- x$hierarchy[[parent]]
      cat("    ", parent, "->", paste(children, collapse = ", "), "\n")
    }
  }

  invisible(x)
}

# ---------------------------------------------------------------------------
# Internal ASF parsers
# ---------------------------------------------------------------------------

#' Find lines belonging to a named ASF section
#'
#' @param lines Character vector of file lines.
#' @param section Section name (e.g., "units", "root", "bonedata", "hierarchy").
#' @return Character vector of lines within that section.
#' @keywords internal
#' @noRd
.asf_section_lines <- function(lines, section) {
  # Sections start with ":sectionname" and end before the next ":" section
  pattern <- paste0("^\\s*:", section, "\\b")
  start <- which(grepl(pattern, lines, ignore.case = TRUE))
  if (length(start) == 0) return(character(0))
  start <- start[1]

  # Find the next section start (lines starting with ":")
  remaining <- lines[(start + 1):length(lines)]
  next_section <- which(grepl("^\\s*:", remaining))
  if (length(next_section) == 0) {
    end <- length(lines)
  } else {
    end <- start + next_section[1] - 1
  }

  lines[(start + 1):end]
}

#' Parse ASF :units section
#'
#' @param lines Character vector of all file lines.
#' @return Named list of unit values.
#' @keywords internal
#' @noRd
.parse_asf_units <- function(lines) {
  section <- .asf_section_lines(lines, "units")
  section <- trimws(section)
  section <- section[nzchar(section)]

  units <- list()
  for (line in section) {
    parts <- strsplit(line, "\\s+")[[1]]
    if (length(parts) >= 2) {
      key <- parts[1]
      val <- parts[2]
      # Try to convert to numeric; keep as character if it fails
      num_val <- suppressWarnings(as.numeric(val))
      if (!is.na(num_val)) {
        units[[key]] <- num_val
      } else {
        units[[key]] <- val
      }
    }
  }
  units
}

#' Parse ASF :root section
#'
#' @param lines Character vector of all file lines.
#' @return List with position, orientation, order, axis.
#' @keywords internal
#' @noRd
.parse_asf_root <- function(lines) {
  section <- .asf_section_lines(lines, "root")
  section <- trimws(section)
  section <- section[nzchar(section)]

  root <- list(
    order = character(0),
    axis = character(0),
    position = c(0, 0, 0),
    orientation = c(0, 0, 0)
  )

  for (line in section) {
    parts <- strsplit(line, "\\s+")[[1]]
    key <- tolower(parts[1])
    vals <- parts[-1]

    if (key == "order") {
      root$order <- vals
    } else if (key == "axis") {
      root$axis <- vals
    } else if (key == "position") {
      root$position <- as.numeric(vals)
    } else if (key == "orientation") {
      root$orientation <- as.numeric(vals)
    }
  }

  root
}

#' Parse ASF :bonedata section
#'
#' @param lines Character vector of all file lines.
#' @return Named list of bone definitions.
#' @keywords internal
#' @noRd
.parse_asf_bonedata <- function(lines) {
  section <- .asf_section_lines(lines, "bonedata")
  section <- trimws(section)
  section <- section[nzchar(section)]

  bones <- list()

  # Split into begin...end blocks
  in_block <- FALSE
  current_bone <- NULL

  for (line in section) {
    lline <- tolower(line)

    if (lline == "begin") {
      in_block <- TRUE
      current_bone <- list(
        id = NA_integer_,
        name = NA_character_,
        direction = c(0, 0, 0),
        length = 0,
        axis = list(values = c(0, 0, 0), order = "XYZ"),
        dof = character(0),
        limits = list()
      )
      next
    }

    if (lline == "end") {
      in_block <- FALSE
      if (!is.null(current_bone) && !is.na(current_bone$name)) {
        bones[[current_bone$name]] <- current_bone
      }
      current_bone <- NULL
      next
    }

    if (in_block && !is.null(current_bone)) {
      parts <- strsplit(line, "\\s+")[[1]]
      key <- tolower(parts[1])
      vals <- parts[-1]

      if (key == "id") {
        current_bone$id <- as.integer(vals[1])
      } else if (key == "name") {
        current_bone$name <- vals[1]
      } else if (key == "direction") {
        current_bone$direction <- as.numeric(vals)
      } else if (key == "length") {
        current_bone$length <- as.numeric(vals[1])
      } else if (key == "axis") {
        # Last token may be axis order (e.g., "XYZ")
        num_vals <- suppressWarnings(as.numeric(vals))
        non_na <- which(!is.na(num_vals))
        na_pos <- which(is.na(num_vals))
        current_bone$axis <- list(
          values = num_vals[non_na],
          order = if (length(na_pos) > 0) vals[na_pos[1]] else "XYZ"
        )
      } else if (key == "dof") {
        current_bone$dof <- vals
      } else if (key == "limits") {
        # Limits can be on one line or multiple lines
        current_bone$limits <- .parse_asf_limits(line, vals)
      }
    }
  }

  bones
}

#' Parse limit specifications from ASF bone data
#'
#' Limits are specified as `(-160 20) (-70 70) (-60 70)` on one line.
#'
#' @param line The full line text.
#' @param vals Already split parts (after "limits").
#' @return A list of numeric(2) vectors, one per DOF.
#' @keywords internal
#' @noRd
.parse_asf_limits <- function(line, vals) {
  # Extract everything after "limits"
  limit_str <- sub("^\\s*limits\\s*", "", line, ignore.case = TRUE)

  # Find all (min max) pairs
  matches <- gregexpr("\\(([^)]+)\\)", limit_str)
  matched_strings <- regmatches(limit_str, matches)[[1]]

  limits <- lapply(matched_strings, function(m) {
    inner <- gsub("[()]", "", m)
    as.numeric(strsplit(trimws(inner), "\\s+")[[1]])
  })

  limits
}

#' Parse ASF :hierarchy section
#'
#' @param lines Character vector of all file lines.
#' @return Named list mapping parent to children.
#' @keywords internal
#' @noRd
.parse_asf_hierarchy <- function(lines) {
  section <- .asf_section_lines(lines, "hierarchy")
  section <- trimws(section)
  section <- section[nzchar(section)]

  hierarchy <- list()

  # Skip "begin" and "end" lines
  for (line in section) {
    if (tolower(line) %in% c("begin", "end")) next

    parts <- strsplit(line, "\\s+")[[1]]
    if (length(parts) >= 2) {
      parent <- parts[1]
      children <- parts[-1]
      hierarchy[[parent]] <- children
    }
  }

  hierarchy
}

# ---------------------------------------------------------------------------
# Internal AMC parser
# ---------------------------------------------------------------------------

#' Parse AMC frame data
#'
#' Parses the body of an AMC file into a list of frames, where each frame
#' is a named list of numeric vectors keyed by joint name.
#'
#' @param lines Character vector of trimmed, non-empty lines (headers removed).
#' @return A list of frames. Each frame is a named list of numeric vectors.
#' @keywords internal
#' @noRd
.parse_amc_frames <- function(lines) {
  frames <- list()
  current_frame <- NULL
  current_frame_num <- NULL

  for (line in lines) {
    parts <- strsplit(line, "\\s+")[[1]]

    # A line that is a single integer starts a new frame
    if (length(parts) == 1) {
      num <- suppressWarnings(as.integer(parts[1]))
      if (!is.na(num)) {
        # Save previous frame if it exists
        if (!is.null(current_frame)) {
          frames[[length(frames) + 1]] <- current_frame
        }
        current_frame <- list()
        current_frame_num <- num
        next
      }
    }

    # Joint data line: joint_name val1 val2 ...
    if (!is.null(current_frame) && length(parts) >= 2) {
      joint_name <- parts[1]
      values <- as.numeric(parts[-1])
      current_frame[[joint_name]] <- values
    }
  }

  # Save the last frame
  if (!is.null(current_frame)) {
    frames[[length(frames) + 1]] <- current_frame
  }

  frames
}
