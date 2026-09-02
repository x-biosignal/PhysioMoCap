# DeepLabCut Reader
# Reads DeepLabCut pose estimation output into PhysioExperiment objects

#' Read DeepLabCut output
#'
#' Reads DeepLabCut (DLC) pose estimation output from CSV or HDF5 format
#' and returns a PhysioExperiment object with keypoint coordinates and
#' confidence scores.
#'
#' @param path Path to a DeepLabCut output file (CSV or H5).
#' @param fps Frame rate in Hz (frames per second). Default 30.
#'   DeepLabCut does not store frame rate in its output, so this must be
#'   specified by the user.
#' @param format File format: `"csv"` or `"h5"`. Default `"csv"`.
#'
#' @return A PhysioExperiment with assays:
#' \describe{
#'   \item{keypoint_x}{X coordinates matrix (frames x bodyparts)}
#'   \item{keypoint_y}{Y coordinates matrix (frames x bodyparts)}
#'   \item{confidence}{Detection likelihood matrix (frames x bodyparts)}
#' }
#'
#' The `colData` contains columns `label` (bodypart names), `type`
#' (`"keypoint"`), and `scorer` (the DLC scorer/model name).
#'
#' The `metadata` list contains `dlc_scorer`, `format`, and `source_file`.
#'
#' @details
#' DeepLabCut outputs pose estimation results in CSV or HDF5 format.
#'
#' **CSV format** has a 3-row multi-level header:
#' \enumerate{
#'   \item Row 1: scorer name (the DLC model name)
#'   \item Row 2: bodypart names
#'   \item Row 3: coordinate type (x, y, likelihood)
#' }
#' Followed by numeric data where each row is a frame and columns are
#' grouped as `[x, y, likelihood]` triplets per bodypart.
#'
#' **H5 format** stores data in a hierarchical HDF5 structure under
#' `df_with_missing/table`. Requires the `rhdf5` package.
#'
#' @examples
#' \dontrun{
#' # Read DeepLabCut CSV output
#' pe <- readDeepLabCut("path/to/DLC_output.csv", fps = 30)
#'
#' # Read HDF5 format
#' pe <- readDeepLabCut("path/to/DLC_output.h5", fps = 25, format = "h5")
#' }
#'
#' @references
#' Mathis A, Mamidanna P, Cury KM, Abe T, Murthy VN, Mathis MW, Bethge M
#' (2018). "DeepLabCut: markerless pose estimation of user-defined body
#' parts with deep learning." Nature Neuroscience, 21(9), 1281-1289.
#'
#' @seealso [readOpenPose()], [readMediaPipe()], [readOpenCap()]
#'
#' @importFrom S4Vectors SimpleList DataFrame
#' @export
readDeepLabCut <- function(path, fps = 30, format = c("csv", "h5")) {
  format <- match.arg(format)

  stopifnot(is.numeric(fps) && length(fps) == 1 && fps > 0)

  if (!file.exists(path)) {
    stop("File does not exist: ", path, call. = FALSE)
  }

  if (format == "csv") {
    result <- .read_dlc_csv(path)
  } else {
    result <- .read_dlc_h5(path)
  }

  # Create PhysioExperiment
  PhysioExperiment(
    assays = SimpleList(
      keypoint_x = result$kp_x,
      keypoint_y = result$kp_y,
      confidence = result$conf
    ),
    colData = DataFrame(
      label = result$bodyparts,
      type = rep("keypoint", length(result$bodyparts)),
      scorer = rep(result$scorer, length(result$bodyparts))
    ),
    metadata = list(
      dlc_scorer = result$scorer,
      format = format,
      source_file = normalizePath(path, mustWork = FALSE)
    ),
    samplingRate = fps
  )
}


#' Parse DeepLabCut CSV file
#'
#' Reads the 3-row multi-level header and numeric data from a DLC CSV file.
#'
#' @param path Path to CSV file.
#' @return A list with components `kp_x`, `kp_y`, `conf` (matrices),
#'   `bodyparts` (character vector of unique bodypart names), and
#'   `scorer` (character scalar).
#' @keywords internal
#' @noRd
.read_dlc_csv <- function(path) {
  # Read header lines to parse multi-level header
  header_lines <- readLines(path, n = 3)

  if (length(header_lines) < 3) {
    stop("DeepLabCut CSV must have at least 3 header rows (scorer, bodyparts, coords).",
         call. = FALSE)
  }

  scorer_row <- strsplit(header_lines[1], ",")[[1]][-1]
  bodyparts_row <- strsplit(header_lines[2], ",")[[1]][-1]
  coords_row <- strsplit(header_lines[3], ",")[[1]][-1]

  # Validate header structure
  if (length(scorer_row) == 0 || length(bodyparts_row) == 0 || length(coords_row) == 0) {
    stop("DeepLabCut CSV header rows appear to be empty.", call. = FALSE)
  }

  # Lengths must match
  if (length(scorer_row) != length(bodyparts_row) ||
      length(scorer_row) != length(coords_row)) {
    stop("DeepLabCut CSV header rows have inconsistent lengths.", call. = FALSE)
  }

  # Extract scorer (should be consistent across all columns)
  scorer <- scorer_row[1]

  # Identify unique bodyparts (preserving order of first appearance)
  unique_bodyparts <- unique(bodyparts_row)

  # Determine the coordinate columns for each bodypart
  # DLC outputs x, y, likelihood triplets per bodypart
  n_bodyparts <- length(unique_bodyparts)
  n_cols <- length(coords_row)

  # Read numeric data (skip 3 header rows, drop first index column)
  data <- utils::read.csv(path, skip = 3, header = FALSE)

  # Drop the index column (first column)
  data <- data[, -1, drop = FALSE]

  n_frames <- nrow(data)

  # Initialize matrices
  kp_x <- matrix(NA_real_, nrow = n_frames, ncol = n_bodyparts)
  kp_y <- matrix(NA_real_, nrow = n_frames, ncol = n_bodyparts)
  conf <- matrix(NA_real_, nrow = n_frames, ncol = n_bodyparts)
  colnames(kp_x) <- unique_bodyparts
  colnames(kp_y) <- unique_bodyparts
  colnames(conf) <- unique_bodyparts

  # Map each bodypart to its columns
  for (bp_idx in seq_along(unique_bodyparts)) {
    bp <- unique_bodyparts[bp_idx]
    # Find all column indices for this bodypart
    bp_cols <- which(bodyparts_row == bp)
    # Get the corresponding coordinate types
    bp_coords <- coords_row[bp_cols]

    x_col <- bp_cols[bp_coords == "x"]
    y_col <- bp_cols[bp_coords == "y"]
    like_col <- bp_cols[bp_coords == "likelihood"]

    if (length(x_col) > 0) {
      kp_x[, bp_idx] <- as.numeric(data[, x_col[1]])
    }
    if (length(y_col) > 0) {
      kp_y[, bp_idx] <- as.numeric(data[, y_col[1]])
    }
    if (length(like_col) > 0) {
      conf[, bp_idx] <- as.numeric(data[, like_col[1]])
    }
  }

  list(
    kp_x = kp_x,
    kp_y = kp_y,
    conf = conf,
    bodyparts = unique_bodyparts,
    scorer = scorer
  )
}


#' Parse DeepLabCut HDF5 file
#'
#' Reads DLC output from HDF5 format using the rhdf5 package.
#'
#' @param path Path to H5 file.
#' @return A list with components `kp_x`, `kp_y`, `conf` (matrices),
#'   `bodyparts` (character vector of unique bodypart names), and
#'   `scorer` (character scalar).
#' @keywords internal
#' @noRd
.read_dlc_h5 <- function(path) {
  if (!requireNamespace("rhdf5", quietly = TRUE)) {
    stop("Package 'rhdf5' is required for reading DeepLabCut H5 files. ",
         "Install it with BiocManager::install('rhdf5').", call. = FALSE)
  }

  # DLC H5 files store data under "df_with_missing/table"
  # The structure contains block items (column names) and values
  h5_contents <- rhdf5::h5ls(path)

  # Try to find the data in common DLC H5 structures
  # DLC typically stores as a pandas DataFrame in HDF5
  # with multi-level column index

  # Read the axis information
  # Try "df_with_missing" group first (DLC standard)
  if ("df_with_missing" %in% h5_contents$name) {
    base_path <- "df_with_missing"
  } else {
    # Fall back to first group
    groups <- h5_contents$name[h5_contents$otype == "H5I_GROUP"]
    if (length(groups) == 0) {
      stop("No valid HDF5 groups found in DLC H5 file.", call. = FALSE)
    }
    base_path <- groups[1]
  }

  # Read the table data
  table_data <- rhdf5::h5read(path, paste0(base_path, "/table"))

  # Extract column multi-index (scorer, bodyparts, coords)
  axis_path <- paste0(base_path, "/table")

  # Read block items for column names
  # DLC stores columns as a multi-index with levels
  if (!is.null(table_data$values_block_0)) {
    values <- table_data$values_block_0
  } else {
    stop("Unexpected HDF5 structure in DLC file.", call. = FALSE)
  }

  # Read axis1 (column multi-index)
  axis1 <- rhdf5::h5read(path, paste0(base_path, "/axis1"))

  # Parse the multi-index to extract bodyparts and coords
  # axis1 is typically a list of tuples (scorer, bodypart, coord)
  if (is.list(axis1)) {
    scorer <- as.character(axis1[[1]][1])
    bodyparts_all <- as.character(axis1[[2]])
    coords_all <- as.character(axis1[[3]])
  } else if (is.matrix(axis1)) {
    scorer <- as.character(axis1[1, 1])
    bodyparts_all <- as.character(axis1[2, ])
    coords_all <- as.character(axis1[3, ])
  } else {
    stop("Cannot parse column multi-index from DLC H5 file.", call. = FALSE)
  }

  unique_bodyparts <- unique(bodyparts_all)
  n_bodyparts <- length(unique_bodyparts)
  n_frames <- if (is.matrix(values)) ncol(values) else length(values) / length(bodyparts_all)

  # Transpose if needed (HDF5 is column-major)
  if (is.matrix(values)) {
    values <- t(values)
  }

  n_frames <- nrow(values)

  # Initialize matrices
  kp_x <- matrix(NA_real_, nrow = n_frames, ncol = n_bodyparts)
  kp_y <- matrix(NA_real_, nrow = n_frames, ncol = n_bodyparts)
  conf <- matrix(NA_real_, nrow = n_frames, ncol = n_bodyparts)
  colnames(kp_x) <- unique_bodyparts
  colnames(kp_y) <- unique_bodyparts
  colnames(conf) <- unique_bodyparts

  for (bp_idx in seq_along(unique_bodyparts)) {
    bp <- unique_bodyparts[bp_idx]
    bp_cols <- which(bodyparts_all == bp)
    bp_coords <- coords_all[bp_cols]

    x_col <- bp_cols[bp_coords == "x"]
    y_col <- bp_cols[bp_coords == "y"]
    like_col <- bp_cols[bp_coords == "likelihood"]

    if (length(x_col) > 0) kp_x[, bp_idx] <- values[, x_col[1]]
    if (length(y_col) > 0) kp_y[, bp_idx] <- values[, y_col[1]]
    if (length(like_col) > 0) conf[, bp_idx] <- values[, like_col[1]]
  }

  list(
    kp_x = kp_x,
    kp_y = kp_y,
    conf = conf,
    bodyparts = unique_bodyparts,
    scorer = scorer
  )
}
