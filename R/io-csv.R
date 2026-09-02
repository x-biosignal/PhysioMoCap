# Generic Motion Capture CSV Reader
# Reads common CSV/TSV motion capture exports into PhysioExperiment objects

#' Read Motion Capture CSV Data
#'
#' Generic CSV reader that handles common motion capture CSV exports from
#' various systems including Qualisys, Vicon, and generic marker position
#' formats. Returns a PhysioExperiment with `position_x`, `position_y`, and
#' `position_z` assays.
#'
#' @param path Path to the CSV file.
#' @param format Format hint: `"auto"` (detect), `"xyz"` (columns like
#'   `marker1_x`, `marker1_y`, `marker1_z`), `"wide"` (columns like
#'   `Time`, `M1X`, `M1Y`, `M1Z`), `"long"` (columns: `frame`, `marker`,
#'   `x`, `y`, `z`), `"qualisys"` (Qualisys TSV export), or `"vicon"`
#'   (Vicon CSV export). Default `"auto"`.
#' @param sampling_rate Sampling rate in Hz. Required if not detectable from
#'   the file (e.g., from a Time column). If `NULL` and not detectable, an
#'   error is raised.
#' @param header_rows Number of header rows. Default 1.
#' @param skip Number of lines to skip before reading. Default 0.
#' @param sep Column separator. Default `","`.
#' @param marker_names Explicit marker names (overrides auto-detection from
#'   column names). Must match the number of markers detected from columns.
#' @param coord_columns Mapping of coordinate types as a named list of regex
#'   patterns, e.g., `list(x = "_X$", y = "_Y$", z = "_Z$")`. Used only
#'   when `format` is `"wide"` or `"auto"`.
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
#' and optionally `time` (if a Time column was found).
#'
#' @details
#' ## Auto-detection logic
#'
#' When `format = "auto"`, the function inspects column names:
#' \enumerate{
#'   \item If columns match `*_x`, `*_y`, `*_z` pattern (case-insensitive)
#'         with consistent marker prefixes, the `"xyz"` format is used.
#'   \item If columns match `*X`, `*Y`, `*Z` suffix pattern, the `"wide"`
#'         format is used.
#'   \item If the header contains "Qualisys" or "QTM", the `"qualisys"`
#'         format is used.
#'   \item If columns include `frame`, `marker`, `x`, `y`, `z`
#'         (case-insensitive), the `"long"` format is used.
#' }
#'
#' If a `Time` or `time` column is present and contains numeric values,
#' the sampling rate is computed from the median time step. An explicit
#' `sampling_rate` argument always takes precedence.
#'
#' @examples
#' \dontrun{
#' # Read xyz-format CSV
#' pe <- readMoCapCSV("markers.csv", sampling_rate = 120)
#'
#' # Read with auto-detection from Time column
#' pe <- readMoCapCSV("markers.csv")
#'
#' # Read tab-separated file
#' pe <- readMoCapCSV("qualisys_export.tsv", format = "qualisys", sep = "\t")
#'
#' # Override marker names
#' pe <- readMoCapCSV("data.csv", marker_names = c("Hip", "Knee", "Ankle"),
#'                    sampling_rate = 100)
#' }
#'
#' @references
#' Wickham H (2014). "Tidy Data." Journal of Statistical Software, 59(10), 1-23.
#'
#' @seealso [readASF()] and [readAMC()] for Acclaim skeleton and motion files,
#'   [readMoCapAuto()] for automatic format detection.
#'
#' @importFrom S4Vectors SimpleList DataFrame
#' @export
readMoCapCSV <- function(path, format = c("auto", "xyz", "wide", "long",
                                          "qualisys", "vicon"),
                         sampling_rate = NULL, header_rows = 1L,
                         skip = 0L, sep = ",", marker_names = NULL,
                         coord_columns = NULL) {
  format <- match.arg(format)

  if (!file.exists(path)) {
    stop("File does not exist: ", path, call. = FALSE)
  }

  if (!is.null(sampling_rate)) {
    stopifnot(is.numeric(sampling_rate) && length(sampling_rate) == 1 &&
                sampling_rate > 0)
  }

  # Read the raw lines to inspect headers
  all_lines <- readLines(path, warn = FALSE)
  if (length(all_lines) < skip + header_rows + 1) {
    stop("File has too few lines to read data after skip and header rows.",
         call. = FALSE)
  }

  # Lines after skip
  lines_after_skip <- all_lines[(skip + 1):length(all_lines)]

  # Detect format if auto
  if (format == "auto") {
    format <- .detect_csv_format(lines_after_skip, sep, header_rows)
  }

  # Parse based on format
  if (format == "long") {
    result <- .read_mocap_csv_long(path, skip = skip, sep = sep,
                                   header_rows = header_rows)
  } else {
    result <- .read_mocap_csv_wide_family(
      path, format = format, skip = skip, sep = sep,
      header_rows = header_rows, coord_columns = coord_columns
    )
  }

  # Override marker names if provided
  if (!is.null(marker_names)) {
    if (length(marker_names) != length(result$marker_names)) {
      stop(sprintf(
        "marker_names has %d elements but %d markers were detected.",
        length(marker_names), length(result$marker_names)
      ), call. = FALSE)
    }
    result$marker_names <- marker_names
    colnames(result$pos_x) <- marker_names
    colnames(result$pos_y) <- marker_names
    colnames(result$pos_z) <- marker_names
  }

  # Determine sampling rate
  sr <- sampling_rate
  if (is.null(sr)) {
    if (!is.null(result$time_col) && length(result$time_col) >= 2) {
      dt <- diff(result$time_col)
      sr <- 1 / stats::median(dt)
    } else {
      stop(
        "sampling_rate could not be inferred because no numeric Time column ",
        "was detected.\n",
        "Please provide 'sampling_rate' explicitly, e.g. ",
        "readMoCapCSV(path, sampling_rate = 120).",
        call. = FALSE
      )
    }
  }

  n_markers <- length(result$marker_names)

  # Build metadata
  meta <- list(
    format = format,
    source_file = basename(path)
  )
  if (!is.null(result$time_col)) {
    meta[["time"]] <- result$time_col
  }

  PhysioExperiment(
    assays = SimpleList(
      position_x = result$pos_x,
      position_y = result$pos_y,
      position_z = result$pos_z
    ),
    colData = DataFrame(
      label = result$marker_names,
      type = rep("marker", n_markers)
    ),
    metadata = meta,
    samplingRate = sr
  )
}


#' Detect CSV format from header and first data rows
#'
#' @param lines Character vector of lines (after skip).
#' @param sep Column separator.
#' @param header_rows Number of header rows.
#' @return Character string: one of "xyz", "wide", "long", "qualisys", "vicon".
#' @keywords internal
#' @noRd
.detect_csv_format <- function(lines, sep, header_rows) {
  # Check for Qualisys/QTM in the first few lines
  preview <- paste(head(lines, min(10, length(lines))), collapse = " ")
  if (grepl("Qualisys|QTM", preview, ignore.case = TRUE)) {
    return("qualisys")
  }

  # Parse the header row(s) to get column names
  header_line <- lines[header_rows]
  col_names <- strsplit(header_line, sep, fixed = TRUE)[[1]]
  col_names <- trimws(col_names)
  col_names <- gsub('^["\']|["\']$', "", col_names)

  # Check for long format columns
  lower_cols <- tolower(col_names)
  if (all(c("frame", "marker", "x", "y", "z") %in% lower_cols) ||
      all(c("marker", "x", "y", "z") %in% lower_cols)) {
    return("long")
  }

  # Check for xyz pattern: *_x, *_y, *_z (case-insensitive)
  xyz_matches <- grepl("_[xX]$", col_names) |
    grepl("_[yY]$", col_names) |
    grepl("_[zZ]$", col_names)
  if (sum(xyz_matches) >= 3) {
    return("xyz")
  }

  # Check for wide pattern: *X, *Y, *Z suffix
  wide_matches <- grepl("[^_][XxYyZz]$", col_names)
  if (sum(wide_matches) >= 3) {
    return("wide")
  }

  stop(
    "Could not auto-detect CSV format.\n",
    "Try setting format explicitly: one of 'xyz', 'wide', 'long', ",
    "'qualisys', or 'vicon'.\n",
    "Example: readMoCapCSV(path, format = 'xyz', sampling_rate = 120)",
    call. = FALSE
  )
}


#' Parse marker names and coordinate mapping from _x/_y/_z column pattern
#'
#' @param col_names Character vector of column names.
#' @return A list with `markers` (unique marker names) and `mapping`
#'   (named list mapping each marker to x/y/z column indices).
#' @keywords internal
#' @noRd
.parse_xyz_columns <- function(col_names) {
  # Find columns ending in _x, _y, _z (case-insensitive)
  x_cols <- grep("_[xX]$", col_names, value = TRUE)
  y_cols <- grep("_[yY]$", col_names, value = TRUE)
  z_cols <- grep("_[zZ]$", col_names, value = TRUE)

  # Extract marker prefixes
  x_markers <- sub("_[xX]$", "", x_cols)
  y_markers <- sub("_[yY]$", "", y_cols)
  z_markers <- sub("_[zZ]$", "", z_cols)

  # Use markers that have all three coordinates
  common_markers <- intersect(intersect(x_markers, y_markers), z_markers)

  if (length(common_markers) == 0) {
    stop("No markers found with matching _x, _y, _z columns.", call. = FALSE)
  }

  # Preserve order of first appearance in x columns
  markers <- common_markers[order(match(common_markers, x_markers))]

  mapping <- list()
  for (m in markers) {
    mapping[[m]] <- list(
      x = which(col_names == paste0(m, "_x") | col_names == paste0(m, "_X")),
      y = which(col_names == paste0(m, "_y") | col_names == paste0(m, "_Y")),
      z = which(col_names == paste0(m, "_z") | col_names == paste0(m, "_Z"))
    )
  }

  list(markers = markers, mapping = mapping)
}


#' Parse marker names and coordinate mapping from XYZ suffix pattern
#'
#' @param col_names Character vector of column names.
#' @param coord_columns Optional named list of regex patterns for coordinates.
#' @return A list with `markers` (unique marker names) and `mapping`
#'   (named list mapping each marker to x/y/z column indices).
#' @keywords internal
#' @noRd
.parse_wide_columns <- function(col_names, coord_columns = NULL) {
  if (!is.null(coord_columns)) {
    x_pat <- coord_columns$x
    y_pat <- coord_columns$y
    z_pat <- coord_columns$z
  } else {
    x_pat <- "[Xx]$"
    y_pat <- "[Yy]$"
    z_pat <- "[Zz]$"
  }

  x_cols <- grep(x_pat, col_names, value = TRUE)
  y_cols <- grep(y_pat, col_names, value = TRUE)
  z_cols <- grep(z_pat, col_names, value = TRUE)

  # Extract marker prefixes by removing the coordinate suffix
  x_markers <- sub(x_pat, "", x_cols)
  y_markers <- sub(y_pat, "", y_cols)
  z_markers <- sub(z_pat, "", z_cols)

  common_markers <- intersect(intersect(x_markers, y_markers), z_markers)

  if (length(common_markers) == 0) {
    stop("No markers found with matching X/Y/Z columns.", call. = FALSE)
  }

  markers <- common_markers[order(match(common_markers, x_markers))]

  mapping <- list()
  for (m in markers) {
    # Find the actual column for each coordinate
    x_idx <- grep(paste0("^", gsub("([.\\|(){}^$*+?\\[\\]])", "\\\\\\1", m),
                         x_pat), col_names)
    y_idx <- grep(paste0("^", gsub("([.\\|(){}^$*+?\\[\\]])", "\\\\\\1", m),
                         y_pat), col_names)
    z_idx <- grep(paste0("^", gsub("([.\\|(){}^$*+?\\[\\]])", "\\\\\\1", m),
                         z_pat), col_names)
    mapping[[m]] <- list(x = x_idx[1], y = y_idx[1], z = z_idx[1])
  }

  list(markers = markers, mapping = mapping)
}


#' Parse long format and pivot to wide matrices
#'
#' @param data A data.frame with columns like frame, marker, x, y, z.
#' @return A list with `pos_x`, `pos_y`, `pos_z` matrices, `marker_names`,
#'   and optionally `time_col`.
#' @keywords internal
#' @noRd
.parse_long_format <- function(data) {
  # Normalize column names to lowercase for matching
  names(data) <- tolower(names(data))

  if (!"marker" %in% names(data)) {
    stop("Long format requires a 'marker' column.", call. = FALSE)
  }
  if (!all(c("x", "y", "z") %in% names(data))) {
    stop("Long format requires 'x', 'y', 'z' columns.", call. = FALSE)
  }

  marker_names <- unique(data$marker)
  n_markers <- length(marker_names)

  # Determine frame ordering
  if ("frame" %in% names(data)) {
    frames <- sort(unique(data$frame))
  } else if ("time" %in% names(data)) {
    frames <- sort(unique(data$time))
  } else {
    # Assume rows are grouped by frame; each group of n_markers rows = 1 frame
    n_total <- nrow(data)
    n_frames <- n_total / n_markers
    if (n_frames != floor(n_frames)) {
      stop("Long format data has inconsistent row count for the number of markers.",
           call. = FALSE)
    }
    frames <- seq_len(n_frames)
    data$frame <- rep(frames, each = n_markers)
  }

  n_frames <- length(frames)

  pos_x <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_y <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_z <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  frame_col <- if ("frame" %in% names(data)) "frame" else "time"

  for (mi in seq_along(marker_names)) {
    m <- marker_names[mi]
    sub_data <- data[data$marker == m, , drop = FALSE]
    for (fi in seq_along(frames)) {
      row <- sub_data[sub_data[[frame_col]] == frames[fi], , drop = FALSE]
      if (nrow(row) >= 1) {
        pos_x[fi, mi] <- as.numeric(row$x[1])
        pos_y[fi, mi] <- as.numeric(row$y[1])
        pos_z[fi, mi] <- as.numeric(row$z[1])
      }
    }
  }

  time_col <- NULL
  if ("time" %in% names(data)) {
    time_col <- sort(unique(data$time))
  }

  list(
    pos_x = pos_x,
    pos_y = pos_y,
    pos_z = pos_z,
    marker_names = marker_names,
    time_col = time_col
  )
}


#' Read CSV in wide-family formats (xyz, wide, qualisys, vicon)
#'
#' @param path File path.
#' @param format One of "xyz", "wide", "qualisys", "vicon".
#' @param skip Lines to skip.
#' @param sep Column separator.
#' @param header_rows Number of header rows.
#' @param coord_columns Optional coordinate column regex patterns.
#' @return A list with `pos_x`, `pos_y`, `pos_z` matrices, `marker_names`,
#'   and `time_col`.
#' @keywords internal
#' @noRd
.read_mocap_csv_wide_family <- function(path, format, skip, sep,
                                         header_rows, coord_columns) {
  # Read data: skip initial lines + header rows, then parse
  total_skip <- skip + header_rows
  data <- utils::read.csv(path, skip = total_skip, header = FALSE,
                          sep = sep, stringsAsFactors = FALSE)

  # Read header line(s) to get column names
  all_lines <- readLines(path, warn = FALSE)
  header_line_idx <- skip + header_rows  # last header row
  header_line <- all_lines[header_line_idx]
  col_names <- strsplit(header_line, sep, fixed = TRUE)[[1]]
  col_names <- trimws(col_names)
  col_names <- gsub('^["\']|["\']$', "", col_names)

  # Assign column names to data
  if (ncol(data) >= length(col_names)) {
    names(data)[seq_along(col_names)] <- col_names
  } else {
    # Truncate col_names to match
    col_names <- col_names[seq_len(ncol(data))]
    names(data) <- col_names
  }

  # Extract time column if present
  time_col <- NULL
  time_col_idx <- which(tolower(col_names) %in% c("time", "frame_time"))
  if (length(time_col_idx) > 0) {
    time_values <- suppressWarnings(as.numeric(data[[time_col_idx[1]]]))
    if (!all(is.na(time_values))) {
      time_col <- time_values
    }
  }

  # Parse columns based on format
  if (format == "xyz") {
    parsed <- .parse_xyz_columns(col_names)
  } else if (format %in% c("wide", "qualisys", "vicon")) {
    parsed <- .parse_wide_columns(col_names, coord_columns)
  } else {
    stop("Unsupported format for wide-family parser: ", format, call. = FALSE)
  }

  markers <- parsed$markers
  mapping <- parsed$mapping
  n_frames <- nrow(data)
  n_markers <- length(markers)

  pos_x <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_y <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_z <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  colnames(pos_x) <- markers
  colnames(pos_y) <- markers
  colnames(pos_z) <- markers

  for (mi in seq_along(markers)) {
    m <- markers[mi]
    pos_x[, mi] <- as.numeric(data[[mapping[[m]]$x]])
    pos_y[, mi] <- as.numeric(data[[mapping[[m]]$y]])
    pos_z[, mi] <- as.numeric(data[[mapping[[m]]$z]])
  }

  list(
    pos_x = pos_x,
    pos_y = pos_y,
    pos_z = pos_z,
    marker_names = markers,
    time_col = time_col
  )
}


#' Read CSV in long format
#'
#' @param path File path.
#' @param skip Lines to skip.
#' @param sep Column separator.
#' @param header_rows Number of header rows.
#' @return A list with `pos_x`, `pos_y`, `pos_z` matrices, `marker_names`,
#'   and `time_col`.
#' @keywords internal
#' @noRd
.read_mocap_csv_long <- function(path, skip, sep, header_rows) {
  # For long format, header_rows is typically 1

  total_skip <- skip + (header_rows - 1)
  data <- utils::read.csv(path, skip = total_skip, header = TRUE,
                          sep = sep, stringsAsFactors = FALSE)

  .parse_long_format(data)
}
