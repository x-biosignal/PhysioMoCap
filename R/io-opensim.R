# OpenSim File I/O Functions
# Readers for MOT (motion), STO (storage), and TRC (marker trajectory) formats

#' Format numeric values so they round-trip to identical doubles
#'
#' Uses 17 significant digits, the shortest fixed precision that is guaranteed
#' to recover any IEEE-754 double exactly via `as.numeric()`.
#'
#' @param v Numeric vector.
#' @return Character vector.
#' @keywords internal
.osim_num <- function(v) {
  out <- vapply(v, function(z) {
    if (is.na(z)) return("nan")
    sprintf("%.17g", z)
  }, character(1))
  out
}

#' Read OpenSim Motion File (.mot)
#'
#' Reads an OpenSim motion file containing joint angles, kinematics,
#' or other time-series data. MOT files use a tab-separated format with
#' a header block ending in "endheader".
#'
#' @param path Character string giving the path to the `.mot` file.
#' @return A `PhysioExperiment` object with the data stored in the `"raw"`
#'   assay. The first column (time) is used to compute the sampling rate.
#'   Header metadata such as `inDegrees` is stored in `metadata()`.
#'
#' @references
#' Delp SL, Anderson FC, Arnold AS, Loan P, Habib A, John CT, Guendelman E,
#' Thelen DG (2007). "OpenSim: Open-Source Software to Create and Analyze
#' Dynamic Simulations of Movement." IEEE Transactions on Biomedical
#' Engineering, 54(11), 1940-1950.
#'
#' @seealso [readSTO()], [readTRC()], [readOpenCap()]
#'
#' @export
#' @examples
#' mot_file <- system.file("testdata", "sample.mot", package = "PhysioMoCap")
#' if (nzchar(mot_file)) {
#'   pe <- readMOT(mot_file)
#'   pe
#' }
readMOT <- function(path) {
  .read_opensim_tabular(path, format = "mot")
}

#' Read OpenSim Storage File (.sto)
#'
#' Reads an OpenSim storage file containing forces, moments,
#' or other computed quantities. STO files share the same tab-separated
#' format as MOT files with a header block ending in "endheader".
#'
#' @param path Character string giving the path to the `.sto` file.
#' @return A `PhysioExperiment` object with the data stored in the `"raw"`
#'   assay. The first column (time) is used to compute the sampling rate.
#'   Header metadata is stored in `metadata()`.
#'
#' @references
#' Delp SL, Anderson FC, Arnold AS, Loan P, Habib A, John CT, Guendelman E,
#' Thelen DG (2007). "OpenSim: Open-Source Software to Create and Analyze
#' Dynamic Simulations of Movement." IEEE Transactions on Biomedical
#' Engineering, 54(11), 1940-1950.
#'
#' @seealso [readMOT()], [readTRC()], [readOpenCap()]
#'
#' @export
#' @examples
#' sto_file <- system.file("testdata", "sample.sto", package = "PhysioMoCap")
#' if (nzchar(sto_file)) {
#'   pe <- readSTO(sto_file)
#'   pe
#' }
readSTO <- function(path) {
  .read_opensim_tabular(path, format = "sto")
}

#' Internal parser for tab-separated OpenSim files (MOT/STO)
#'
#' Both MOT and STO files share the same general structure: a header block
#' with key=value metadata lines ending at "endheader", followed by a
#' tab-separated data table whose first column is time.
#'
#' @param path File path.
#' @param format Character, either `"mot"` or `"sto"`.
#' @return A PhysioExperiment object.
#' @keywords internal
.read_opensim_tabular <- function(path, format = c("mot", "sto")) {
  format <- match.arg(format)
  stopifnot(file.exists(path))

  lines <- readLines(path, warn = FALSE)

  # Locate "endheader" line (case-insensitive)
  endheader_idx <- which(tolower(trimws(lines)) == "endheader")
  if (length(endheader_idx) == 0) {
    stop("Could not find 'endheader' marker in file: ", path, call. = FALSE)
  }
  endheader_idx <- endheader_idx[1]

  # Parse header metadata
  header_lines <- lines[seq_len(endheader_idx - 1)]
  header_meta <- .parse_opensim_header(header_lines)
  header_meta[["format"]] <- format
  # The first non-blank header line without '=' is the data-set name (OpenSim
  # convention, e.g. "Coordinates"); capture it so writeMOT can round-trip it.
  name_lines <- header_lines[nzchar(trimws(header_lines)) &
                               !grepl("=", header_lines)]
  if (length(name_lines) > 0) header_meta[["name"]] <- trimws(name_lines[1])

  # Data starts after endheader
  data_lines <- lines[(endheader_idx + 1):length(lines)]

  # Remove blank lines
  data_lines <- data_lines[nzchar(trimws(data_lines))]
  if (length(data_lines) < 2) {
    stop("No data found after header in file: ", path, call. = FALSE)
  }

  # First data line is the column header
  col_names <- strsplit(data_lines[1], "\t")[[1]]
  col_names <- trimws(col_names)

  # Remaining lines are numeric data
  data_text <- data_lines[-1]
  data_mat <- do.call(rbind, lapply(data_text, function(line) {
    as.numeric(strsplit(line, "\t")[[1]])
  }))

  if (ncol(data_mat) != length(col_names)) {
    stop(sprintf(
      "Column count mismatch: header has %d columns but data has %d",
      length(col_names), ncol(data_mat)
    ), call. = FALSE)
  }
  colnames(data_mat) <- col_names

  # First column is time
  time_col <- data_mat[, 1]
  signal_mat <- data_mat[, -1, drop = FALSE]
  signal_names <- col_names[-1]

  # Compute sampling rate from time differences
  if (length(time_col) >= 2) {
    dt <- diff(time_col)
    sr <- 1 / stats::median(dt)
  } else {
    sr <- NA_real_
  }

  # Build PhysioExperiment
  PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = signal_mat),
    colData = S4Vectors::DataFrame(
      label = signal_names,
      type = rep(format, length(signal_names))
    ),
    metadata = c(
      header_meta,
      list(time = time_col, source_file = basename(path))
    ),
    samplingRate = sr
  )
}

#' Parse key=value pairs from an OpenSim header block
#'
#' @param header_lines Character vector of header lines (before endheader).
#' @return A named list of parsed header values.
#' @keywords internal
.parse_opensim_header <- function(header_lines) {
  meta <- list()
  for (line in header_lines) {
    line <- trimws(line)
    if (grepl("=", line)) {
      parts <- strsplit(line, "=", fixed = TRUE)[[1]]
      key <- trimws(parts[1])
      value <- trimws(paste(parts[-1], collapse = "="))
      # Try to convert numeric values
      num_val <- suppressWarnings(as.numeric(value))
      if (!is.na(num_val)) {
        meta[[key]] <- num_val
      } else {
        meta[[key]] <- value
      }
    }
  }
  meta
}

#' Read OpenSim TRC File (.trc)
#'
#' Reads marker trajectory data from an OpenSim TRC file. TRC files store
#' 3D marker positions (X, Y, Z) in a specific header format that differs
#' from MOT/STO files.
#'
#' @param path Character string giving the path to the `.trc` file.
#' @return A `PhysioExperiment` object with three assays: `"position_x"`,
#'   `"position_y"`, and `"position_z"`, each with columns named by marker.
#'   Header metadata (DataRate, Units, etc.) is stored in `metadata()`.
#'
#' @references
#' Delp SL, Anderson FC, Arnold AS, Loan P, Habib A, John CT, Guendelman E,
#' Thelen DG (2007). "OpenSim: Open-Source Software to Create and Analyze
#' Dynamic Simulations of Movement." IEEE Transactions on Biomedical
#' Engineering, 54(11), 1940-1950.
#'
#' @seealso [readMOT()], [readSTO()], [readC3D()]
#'
#' @export
#' @examples
#' trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
#' if (nzchar(trc_file)) {
#'   pe <- readTRC(trc_file)
#'   pe
#' }
readTRC <- function(path) {
  stopifnot(file.exists(path))

  lines <- readLines(path, warn = FALSE)
  if (length(lines) < 6) {
    stop("TRC file too short; expected at least 6 lines: ", path, call. = FALSE)
  }

  # Line 1: PathFileType header (informational)
  # Line 2: Header field names (DataRate, CameraRate, etc.)
  # Line 3: Header field values
  # Line 4: Marker names row (Frame#, Time, MarkerName1, ..., MarkerNameN)
  # Line 5: Coordinate labels (blank, blank, X1, Y1, Z1, X2, Y2, Z2, ...)
  # Line 6+: Data rows

  # Parse header metadata from lines 2-3
  header_names <- strsplit(lines[2], "\t")[[1]]
  header_values <- strsplit(lines[3], "\t")[[1]]
  header_names <- trimws(header_names)
  header_values <- trimws(header_values)

  header_meta <- list(format = "trc")
  n_header <- min(length(header_names), length(header_values))
  for (i in seq_len(n_header)) {
    key <- header_names[i]
    val <- header_values[i]
    if (nzchar(key)) {
      num_val <- suppressWarnings(as.numeric(val))
      header_meta[[key]] <- if (!is.na(num_val)) num_val else val
    }
  }

  # Extract data rate for sampling rate
  sr <- NA_real_
  if (!is.null(header_meta[["DataRate"]])) {
    sr <- as.numeric(header_meta[["DataRate"]])
  } else if (!is.null(header_meta[["CameraRate"]])) {
    sr <- as.numeric(header_meta[["CameraRate"]])
  }

  # Parse marker names from line 4
  marker_line <- strsplit(lines[4], "\t")[[1]]
  marker_line <- trimws(marker_line)
  # First two entries are "Frame#" and "Time", rest are marker names
  # Marker names appear once then blank tabs for Y and Z
  raw_markers <- marker_line[-(1:2)]
  marker_names <- raw_markers[nzchar(raw_markers)]

  if (length(marker_names) == 0) {
    stop("No marker names found in TRC header line 4", call. = FALSE)
  }

  n_markers <- length(marker_names)

  # Parse data lines (line 6 onward)
  data_lines <- lines[6:length(lines)]
  data_lines <- data_lines[nzchar(trimws(data_lines))]

  if (length(data_lines) == 0) {
    stop("No data rows found in TRC file: ", path, call. = FALSE)
  }

  data_mat <- do.call(rbind, lapply(data_lines, function(line) {
    as.numeric(strsplit(line, "\t")[[1]])
  }))

  n_frames <- nrow(data_mat)

  # Columns: Frame#, Time, X1, Y1, Z1, X2, Y2, Z2, ...
  # We need at least 2 + 3*n_markers columns
  expected_cols <- 2 + 3 * n_markers
  actual_cols <- ncol(data_mat)
  if (actual_cols < expected_cols) {
    stop(sprintf(
      "TRC data has %d columns but expected %d (2 + 3 * %d markers)",
      actual_cols, expected_cols, n_markers
    ), call. = FALSE)
  }

  time_col <- data_mat[, 2]

  # Extract X, Y, Z for each marker
  pos_x <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_y <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_z <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)

  for (i in seq_len(n_markers)) {
    col_offset <- 2 + (i - 1) * 3  # 0-indexed offset from column 3
    pos_x[, i] <- data_mat[, col_offset + 1]
    pos_y[, i] <- data_mat[, col_offset + 2]
    pos_z[, i] <- data_mat[, col_offset + 3]
  }

  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  # Build metadata
  header_meta[["time"]] <- time_col
  header_meta[["source_file"]] <- basename(path)

  PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names,
      type = rep("marker", n_markers)
    ),
    metadata = header_meta,
    samplingRate = sr
  )
}

#' Write an OpenSim Motion File (.mot)
#'
#' Writes tabular time-series data (joint angles, kinematics, ...) from a
#' `PhysioExperiment` to an OpenSim `.mot` file. This is the inverse of
#' [readMOT()]: a `readMOT() -> writeMOT() -> readMOT()` round-trip reproduces
#' every numeric column exactly and the derived sampling rate.
#'
#' The time column is taken from `metadata(x)$time` when present, otherwise it
#' is reconstructed from `samplingRate(x)`. The `inDegrees` header flag is
#' preserved from `metadata(x)$inDegrees` (default `"yes"`).
#'
#' @param x A `PhysioExperiment` whose first assay holds the data columns.
#' @param path Character string giving the output `.mot` path.
#' @return The output `path`, invisibly.
#'
#' @seealso [readMOT()], [writeTRC()]
#'
#' @export
#' @examples
#' mot_file <- system.file("testdata", "sample.mot", package = "PhysioMoCap")
#' if (nzchar(mot_file)) {
#'   pe <- readMOT(mot_file)
#'   out <- tempfile(fileext = ".mot")
#'   writeMOT(pe, out)
#' }
writeMOT <- function(x, path) {
  .write_opensim_tabular(x, path, format = "mot")
}

#' Internal writer for tab-separated OpenSim files (MOT/STO)
#'
#' @param x A PhysioExperiment.
#' @param path Output path.
#' @param format Either `"mot"` or `"sto"`.
#' @return `path`, invisibly.
#' @keywords internal
.write_opensim_tabular <- function(x, path, format = c("mot", "sto")) {
  format <- match.arg(format)
  stopifnot(inherits(x, "PhysioExperiment"))
  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("'path' must be a non-empty character string.", call. = FALSE)
  }

  data <- as.matrix(SummarizedExperiment::assay(x, 1L))
  labels <- colnames(data)
  if (is.null(labels)) labels <- channelNames(x)
  if (is.null(labels)) labels <- paste0("col", seq_len(ncol(data)))
  n_rows <- nrow(data)
  meta <- S4Vectors::metadata(x)

  time <- meta$time
  if (is.null(time) || length(time) != n_rows) {
    sr <- samplingRate(x)
    if (length(sr) != 1 || is.na(sr) || sr <= 0) sr <- 1
    time <- (seq_len(n_rows) - 1) / sr
  }

  in_degrees <- meta$inDegrees
  if (is.null(in_degrees) || !nzchar(as.character(in_degrees)[1])) {
    in_degrees <- "yes"
  }
  name <- meta$name
  if (is.null(name) || !nzchar(as.character(name)[1])) {
    name <- tools::file_path_sans_ext(basename(path))
  }
  # The name is the first header line; an '=' would be misread as a key=value
  # metadata entry by the reader, so neutralise it.
  name <- gsub("=", "_", as.character(name)[1])

  header <- c(
    name,
    "version=1",
    paste0("nRows=", n_rows),
    paste0("nColumns=", ncol(data) + 1L),
    paste0("inDegrees=", as.character(in_degrees)[1]),
    "endheader"
  )
  col_header <- paste(c("time", labels), collapse = "\t")
  data_lines <- vapply(seq_len(n_rows), function(i) {
    paste(c(.osim_num(time[i]), .osim_num(data[i, ])), collapse = "\t")
  }, character(1))

  writeLines(c(header, col_header, data_lines), path)
  invisible(path)
}

#' Write an OpenSim TRC File (.trc)
#'
#' Writes 3D marker trajectories from a `PhysioExperiment` to an OpenSim `.trc`
#' file. This is the inverse of [readTRC()]: a
#' `readTRC() -> writeTRC() -> readTRC()` round-trip reproduces the marker
#' coordinates exactly and the `DataRate` header field.
#'
#' Marker labels, units (`metadata(x)$Units`, default `"mm"`), frame rate, and
#' the time column (`metadata(x)$time`, else derived from `samplingRate(x)`)
#' are preserved on write.
#'
#' @param x A `PhysioExperiment` with `"position_x"`, `"position_y"`, and
#'   `"position_z"` assays (as produced by [readTRC()] or [readC3D()]).
#' @param path Character string giving the output `.trc` path.
#' @return The output `path`, invisibly.
#'
#' @seealso [readTRC()], [writeMOT()], [writeC3D()]
#'
#' @export
#' @examples
#' trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
#' if (nzchar(trc_file)) {
#'   pe <- readTRC(trc_file)
#'   out <- tempfile(fileext = ".trc")
#'   writeTRC(pe, out)
#' }
writeTRC <- function(x, path) {
  stopifnot(inherits(x, "PhysioExperiment"))
  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("'path' must be a non-empty character string.", call. = FALSE)
  }
  an <- SummarizedExperiment::assayNames(x)
  need <- c("position_x", "position_y", "position_z")
  if (!all(need %in% an)) {
    stop("writeTRC requires 'position_x', 'position_y', 'position_z' assays ",
         "(as produced by readTRC()/readC3D()).", call. = FALSE)
  }

  px <- as.matrix(SummarizedExperiment::assay(x, "position_x"))
  py <- as.matrix(SummarizedExperiment::assay(x, "position_y"))
  pz <- as.matrix(SummarizedExperiment::assay(x, "position_z"))
  markers <- colnames(px)
  if (is.null(markers)) markers <- channelNames(x)
  if (is.null(markers)) markers <- paste0("M", seq_len(ncol(px)))
  .validate_marker_labels(markers)
  n_frames <- nrow(px)
  n_markers <- ncol(px)
  meta <- S4Vectors::metadata(x)

  rate <- samplingRate(x)
  if (length(rate) != 1 || is.na(rate) || rate <= 0) {
    rate <- meta$DataRate
    if (is.null(rate) || is.na(rate) || rate <= 0) rate <- 1
  }
  camera_rate <- meta$CameraRate %||% rate
  units <- meta$Units
  if (is.null(units) || !nzchar(as.character(units)[1])) units <- "mm"
  orig_rate <- meta$OrigDataRate %||% rate
  orig_start <- meta$OrigDataStartFrame %||% 1
  orig_nframes <- meta$OrigNumFrames %||% n_frames

  time <- meta$time
  if (is.null(time) || length(time) != n_frames) {
    time <- (seq_len(n_frames) - 1) / rate
  }

  line1 <- paste("PathFileType", "4", "(X/Y/Z)", basename(path), sep = "\t")
  line2 <- paste("DataRate", "CameraRate", "NumFrames", "NumMarkers", "Units",
                 "OrigDataRate", "OrigDataStartFrame", "OrigNumFrames",
                 sep = "\t")
  line3 <- paste(.osim_num(rate), .osim_num(camera_rate), n_frames, n_markers,
                 as.character(units)[1], .osim_num(orig_rate),
                 as.integer(orig_start), as.integer(orig_nframes), sep = "\t")

  # Line 4: marker names, each followed by two blank (Y, Z) columns
  marker_row <- c("Frame#", "Time",
                  as.vector(rbind(markers,
                                  matrix("", nrow = 2, ncol = n_markers))))
  line4 <- paste(marker_row, collapse = "\t")

  # Line 5: coordinate labels
  coord_row <- c("", "", as.vector(vapply(seq_len(n_markers), function(i) {
    c(paste0("X", i), paste0("Y", i), paste0("Z", i))
  }, character(3))))
  line5 <- paste(coord_row, collapse = "\t")

  data_lines <- vapply(seq_len(n_frames), function(i) {
    xyz <- as.vector(rbind(px[i, ], py[i, ], pz[i, ]))
    paste(c(i, .osim_num(time[i]), .osim_num(xyz)), collapse = "\t")
  }, character(1))

  writeLines(c(line1, line2, line3, line4, line5, data_lines), path)
  invisible(path)
}
