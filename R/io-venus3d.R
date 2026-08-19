# Venus3D CSV Reader
# Reads Venus3D CSV exports (OptiTrack -> Motive -> Venus3D pipeline)

#' Parse Venus3D CSV header lines
#'
#' Extracts metadata from `#`-prefixed header lines in a Venus3D CSV file.
#'
#' @param lines Character vector of header lines (starting with `#`).
#' @return A named list with elements: `format_version`, `sampling_rate`,
#'   `n_points`, `units`, `coordinate_system`, `point_types` (character vector
#'   of point labels like `"P1"`, `"P2"`, ...).
#' @noRd
.parse_venus3d_header <- function(lines) {
  header <- list(
    format_version = NA_integer_,
    sampling_rate = NA_real_,
    n_points = NA_integer_,
    units = NA_character_,
    coordinate_system = NA_character_,
    point_types = character(0)
  )

  for (line in lines) {
    # Remove leading #
    content <- sub("^#", "", line)

    if (grepl("^FormatVersion", content)) {
      vals <- strsplit(content, ",")[[1]]
      header$format_version <- as.integer(trimws(vals[length(vals)]))

    } else if (grepl("^Sample Rate", content, ignore.case = TRUE)) {
      vals <- strsplit(content, ",")[[1]]
      header$sampling_rate <- as.numeric(trimws(vals[length(vals)]))

    } else if (grepl("^Number Of Points", content, ignore.case = TRUE)) {
      vals <- strsplit(content, ",")[[1]]
      header$n_points <- as.integer(trimws(vals[length(vals)]))

    } else if (grepl("^Units", content, ignore.case = TRUE)) {
      vals <- strsplit(content, ",")[[1]]
      header$units <- trimws(vals[length(vals)])

    } else if (grepl("^Coordinate System", content, ignore.case = TRUE)) {
      vals <- strsplit(content, ",")[[1]]
      header$coordinate_system <- trimws(vals[length(vals)])

    } else if (grepl("^Point Type", content, ignore.case = TRUE)) {
      vals <- strsplit(content, ",")[[1]]
      # Extract point labels: e.g. "P1(X)", "P1(Y)", ... -> unique "P1", "P2", ...
      pt_cols <- trimws(vals[nzchar(trimws(vals))])
      pt_cols <- pt_cols[grepl("\\(X\\)$", pt_cols)]
      pt_labels <- sub("\\(X\\)$", "", pt_cols)
      header$point_types <- pt_labels
    }
  }

  header
}


#' Read Venus3D CSV Data
#'
#' Reads motion capture data exported from the OptiTrack -> Motive -> Venus3D
#' pipeline. The Venus3D CSV format uses `#`-prefixed header lines for metadata
#' and stores 3D marker coordinates in wide format with columns like `1(X)`,
#' `1(Y)`, `1(Z)`, `2(X)`, etc.
#'
#' Because Venus3D randomly reassigns marker labels across frames, downstream
#' use of [trackMarkers()] is typically required to establish consistent marker
#' identities.
#'
#' @param path Path to the Venus3D CSV file.
#' @param marker_names Optional character vector of marker names to assign. Must
#'   match the number of markers in the file. If `NULL` (default), markers are
#'   labelled `P1`, `P2`, ... based on the Point Type header, or `M1`, `M2`,
#'   ... if that header is absent.
#'
#' @return A PhysioExperiment with assays:
#' \describe{
#'   \item{position_x}{X coordinates matrix (frames x markers)}
#'   \item{position_y}{Y coordinates matrix (frames x markers)}
#'   \item{position_z}{Z coordinates matrix (frames x markers)}
#' }
#'
#' The `colData` contains columns `label` (marker names) and `type`
#' (`"marker"`). The `metadata` list contains `format`, `source_file`,
#' `format_version`, `units`, `coordinate_system`, and `time` (numeric vector
#' of frame times).
#'
#' @examples
#' \dontrun{
#' pe <- readVenus3D("capture.csv")
#'
#' # Assign meaningful marker names
#' pe <- readVenus3D("capture.csv",
#'                   marker_names = c("Hip", "Knee", "Ankle"))
#'
#' # Follow with marker tracking to resolve label shuffling
#' pe_tracked <- trackMarkers(pe)
#' }
#'
#' @seealso [trackMarkers()] for resolving Venus3D's random label assignment,
#'   [readMoCapCSV()] for generic CSV formats, [readMoCapAuto()] for automatic
#'   format detection.
#'
#' @references
#' Venus3D Software Documentation, C-Motion Inc.
#'
#' @export
readVenus3D <- function(path, marker_names = NULL) {
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }

  all_lines <- readLines(path, warn = FALSE)
  if (length(all_lines) == 0) {
    stop("File is empty: ", path, call. = FALSE)
  }

  # Separate header lines (starting with #) from data

  header_mask <- grepl("^#", all_lines)
  header_lines <- all_lines[header_mask]

  # Parse header metadata
  hdr <- .parse_venus3d_header(header_lines)

  # Find the column header line (first non-# line starting with "ID")
  non_header_lines <- all_lines[!header_mask]
  if (length(non_header_lines) == 0) {
    stop("No data found in Venus3D CSV file.", call. = FALSE)
  }

  col_header_idx <- which(grepl("^ID,", non_header_lines[1], ignore.case = TRUE))
  if (length(col_header_idx) == 0 && grepl("^ID", non_header_lines[1], ignore.case = TRUE)) {
    col_header_idx <- 1
  }

  # Parse column names from the first non-header line
  col_names <- strsplit(non_header_lines[1], ",")[[1]]
  col_names <- trimws(col_names)

  # Data lines start after the column header

  data_lines <- non_header_lines[-1]
  if (length(data_lines) == 0) {
    stop("No data rows found in Venus3D CSV file.", call. = FALSE)
  }

  # Parse data into matrix
  data_split <- strsplit(data_lines, ",")
  n_cols <- length(col_names)
  n_frames <- length(data_split)

  data_mat <- matrix(NA_real_, nrow = n_frames, ncol = n_cols)
  for (i in seq_len(n_frames)) {
    vals <- data_split[[i]]
    n_vals <- min(length(vals), n_cols)
    parsed <- suppressWarnings(as.numeric(trimws(vals[seq_len(n_vals)])))
    data_mat[i, seq_len(n_vals)] <- parsed
  }
  colnames(data_mat) <- col_names

  # Extract time column
  time_col <- NULL
  if ("Time" %in% col_names) {
    time_col <- data_mat[, "Time"]
  }

  # Identify coordinate columns: pattern like "1(X)", "1(Y)", "1(Z)", "2(X)", ...
  coord_pattern <- "^(\\d+)\\(([XYZ])\\)$"
  coord_cols <- grep(coord_pattern, col_names, value = TRUE)
  if (length(coord_cols) == 0) {
    stop(
      "No coordinate columns found (expected pattern like '1(X)', '1(Y)', '1(Z)').",
      call. = FALSE
    )
  }

  # Parse marker IDs and axes
  marker_ids <- sub(coord_pattern, "\\1", coord_cols)
  axes <- sub(coord_pattern, "\\2", coord_cols)
  unique_markers <- unique(marker_ids)
  n_markers <- length(unique_markers)

  # Build position matrices (frames x markers)
  pos_x <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_y <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_z <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)

  for (j in seq_along(unique_markers)) {
    mid <- unique_markers[j]
    x_col <- paste0(mid, "(X)")
    y_col <- paste0(mid, "(Y)")
    z_col <- paste0(mid, "(Z)")

    if (x_col %in% col_names) pos_x[, j] <- data_mat[, x_col]
    if (y_col %in% col_names) pos_y[, j] <- data_mat[, y_col]
    if (z_col %in% col_names) pos_z[, j] <- data_mat[, z_col]
  }

  # Determine marker labels
  if (!is.null(marker_names)) {
    if (length(marker_names) != n_markers) {
      stop(
        sprintf(
          "Length of marker_names (%d) does not match number of markers (%d).",
          length(marker_names), n_markers
        ),
        call. = FALSE
      )
    }
    labels <- marker_names
  } else if (length(hdr$point_types) == n_markers) {
    labels <- hdr$point_types
  } else {
    labels <- paste0("M", seq_len(n_markers))
  }

  colnames(pos_x) <- labels
  colnames(pos_y) <- labels
  colnames(pos_z) <- labels

  # Determine sampling rate
  sr <- hdr$sampling_rate
  if (is.na(sr) && !is.null(time_col) && length(time_col) >= 2) {
    dt <- median(diff(time_col), na.rm = TRUE)
    if (dt > 0) sr <- 1 / dt
  }
  if (is.na(sr)) {
    stop(
      "Could not determine sampling rate. ",
      "No 'Sample Rate' header found and no Time column available.",
      call. = FALSE
    )
  }

  # Build PhysioExperiment
  col_data <- S4Vectors::DataFrame(
    label = labels,
    type = rep("marker", n_markers)
  )

  md <- list(
    format = "venus3d",
    source_file = basename(path),
    format_version = hdr$format_version,
    units = hdr$units,
    coordinate_system = hdr$coordinate_system
  )
  if (!is.null(time_col)) {
    md$time <- time_col
  }

  PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = col_data,
    metadata = md,
    samplingRate = sr
  )
}
