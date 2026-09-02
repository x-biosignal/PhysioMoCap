# C3D File I/O Functions
# Reader for C3D motion capture files via the c3dr package

#' Read C3D Motion Capture File
#'
#' Reads a C3D file containing 3D marker position data using the \pkg{c3dr}
#' package. C3D is a widely used binary format for storing biomechanical
#' motion capture data including point (marker) positions and optional
#' analog channel data (e.g., force plate signals).
#'
#' @param path Character string giving the path to the `.c3d` file.
#' @param include_analog Logical; if `TRUE`, analog data (e.g., force plate
#'   channels) is extracted and stored in `metadata(pe)$analog_data` as a
#'   data frame. Default is `FALSE`.
#' @return A `PhysioExperiment` object with three assays: `"position_x"`,
#'   `"position_y"`, and `"position_z"`, each a matrix with rows as time
#'   frames and columns as markers. If the C3D file contains residual data,
#'   a `"quality"` assay is also included. Column metadata (`colData`)
#'   contains `label` (marker names from POINT:LABELS), `type` (`"marker"`),
#'   and `body_segment` (`NA`). Metadata includes `c3d_parameters`,
#'   `source_file`, and a `time` vector computed from frame rate.
#' @references
#' C3D.org. "The C3D File Format." \url{https://www.c3d.org/}.
#'
#' @seealso [readTRC()], [readBVH()], [readOpenPose()]
#'
#' @export
#' @examples
#' if (requireNamespace("c3dr", quietly = TRUE)) {
#'   c3d_file <- c3dr::c3d_example()
#'   pe <- readC3D(c3d_file)
#'   pe
#' }
readC3D <- function(path, include_analog = FALSE) {
  if (!requireNamespace("c3dr", quietly = TRUE)) {
    stop(
      "Package 'c3dr' required. Install with: install.packages('c3dr')",
      call. = FALSE
    )
  }

  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("'path' must be a non-empty character string pointing to a .c3d file.",
         call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("C3D file not found: ", path, call. = FALSE)
  }
  if (!is.logical(include_analog) || length(include_analog) != 1 || is.na(include_analog)) {
    stop("'include_analog' must be TRUE or FALSE.", call. = FALSE)
  }

  ext <- tolower(tools::file_ext(path))
  if (!identical(ext, "c3d")) {
    warning(
      "The file extension is '.", ext, "' (expected '.c3d'). ",
      "Proceeding anyway.",
      call. = FALSE
    )
  }

  # Read the C3D file

  c3d <- c3dr::c3d_read(path)

  # Extract point data in wide format (columns: MarkerName_x, MarkerName_y, MarkerName_z)
  point_data <- c3dr::c3d_data(c3d, format = "wide")

  # Parse the wide format to extract marker names and coordinate matrices
  result <- .parse_c3d_wide(point_data)

  # Extract sampling rate from POINT:RATE parameter or header framerate
  sr <- NA_real_
  if (!is.null(c3d$parameters$POINT$RATE)) {
    sr <- as.numeric(c3d$parameters$POINT$RATE)
  } else if (!is.null(c3d$header$framerate)) {
    sr <- as.numeric(c3d$header$framerate)
  }

  # Compute time vector
  n_frames <- nrow(result$pos_x)
  if (!is.na(sr) && sr > 0) {
    time_vec <- (seq_len(n_frames) - 1) / sr
  } else {
    time_vec <- seq_len(n_frames) - 1
  }

  # Build assays list
  assay_list <- S4Vectors::SimpleList(
    position_x = result$pos_x,
    position_y = result$pos_y,
    position_z = result$pos_z
  )

  # Build colData
  marker_names <- result$marker_names
  n_markers <- length(marker_names)
  col_data <- S4Vectors::DataFrame(
    label = marker_names,
    type = rep("marker", n_markers),
    body_segment = rep(NA_character_, n_markers)
  )

  # Build metadata
  meta <- list(
    c3d_parameters = c3d$parameters,
    source_file = basename(path),
    time = time_vec
  )

  # Include analog data if requested

  if (include_analog) {
    analog_df <- c3dr::c3d_analog(c3d)
    if (!is.null(analog_df) && nrow(analog_df) > 0) {
      meta[["analog_data"]] <- analog_df
    }
  }

  PhysioExperiment(
    assays = assay_list,
    colData = col_data,
    metadata = meta,
    samplingRate = sr
  )
}

#' Write a C3D Motion Capture File
#'
#' Writes 3D marker trajectories (and optional analog channels) from a
#' `PhysioExperiment` to a binary C3D file via the \pkg{c3dr} package. This
#' is the inverse of [readC3D()]: a `readC3D() -> writeC3D() -> readC3D()`
#' round-trip reproduces the marker coordinates (within 32-bit float
#' precision) and preserves the point/analog sampling-rate ratio.
#'
#' The point (marker) rate is taken from `samplingRate(x)`. When analog data
#' is written, the analog rate and the integer point/analog ratio
#' (`ANALOG:RATE / POINT:RATE`, i.e. analog subframes per point frame) are
#' derived from the analog block so the ratio round-trips exactly. Force
#' platform metadata is not written (the marker and analog signals are
#' preserved; force-plate corner/calibration parameters are dropped).
#'
#' @param x A `PhysioExperiment` with `"position_x"`, `"position_y"`, and
#'   `"position_z"` assays (as produced by [readC3D()] or [readTRC()]), or a
#'   `MultiRatePhysioExperiment` whose marker stream carries those assays.
#' @param path Character string giving the output `.c3d` path.
#' @param include_analog Logical; if `TRUE` (default) and the object carries
#'   analog data (in `metadata(x)$analog_data`, or as an `"analog"` stream of
#'   a `MultiRatePhysioExperiment`), that data is written as C3D analog
#'   channels. If `FALSE`, a marker-only C3D file is written.
#' @return The output `path`, invisibly.
#' @references
#' C3D.org. "The C3D File Format." \url{https://www.c3d.org/}.
#'
#' @seealso [readC3D()], [writeTRC()], [writeMOT()]
#'
#' @export
#' @examples
#' if (requireNamespace("c3dr", quietly = TRUE)) {
#'   pe <- readC3D(c3dr::c3d_example(), include_analog = TRUE)
#'   out <- tempfile(fileext = ".c3d")
#'   writeC3D(pe, out)
#'   pe2 <- readC3D(out)
#' }
writeC3D <- function(x, path, include_analog = TRUE) {
  if (!inherits(x, "PhysioExperiment") &&
      !inherits(x, "MultiRatePhysioExperiment")) {
    stop("'x' must be a PhysioExperiment or MultiRatePhysioExperiment.",
         call. = FALSE)
  }
  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("'path' must be a non-empty character string.", call. = FALSE)
  }
  if (!is.logical(include_analog) || length(include_analog) != 1 ||
      is.na(include_analog)) {
    stop("'include_analog' must be TRUE or FALSE.", call. = FALSE)
  }

  # A MultiRatePhysioExperiment carries markers in its marker stream and
  # analog channels in a separate stream at its own rate.
  point_pe <- .c3d_point_source(x)

  an <- SummarizedExperiment::assayNames(point_pe)
  need <- c("position_x", "position_y", "position_z")
  if (!all(need %in% an)) {
    stop("writeC3D requires 'position_x', 'position_y', 'position_z' assays ",
         "(as produced by readC3D()/readTRC()).", call. = FALSE)
  }
  if (!requireNamespace("c3dr", quietly = TRUE)) {
    stop("Package 'c3dr' required. Install with: install.packages('c3dr')",
         call. = FALSE)
  }

  px <- as.matrix(SummarizedExperiment::assay(point_pe, "position_x"))
  py <- as.matrix(SummarizedExperiment::assay(point_pe, "position_y"))
  pz <- as.matrix(SummarizedExperiment::assay(point_pe, "position_z"))
  markers <- colnames(px)
  if (is.null(markers)) markers <- channelNames(point_pe)
  if (is.null(markers)) markers <- paste0("M", seq_len(ncol(px)))
  .validate_marker_labels(markers)
  n_frames <- nrow(px)
  n_markers <- ncol(px)

  point_rate <- samplingRate(point_pe)
  if (length(point_rate) != 1 || is.na(point_rate) || point_rate <= 0) {
    point_rate <- 1
  }
  units <- .c3d_point_units(point_pe)

  # Interleave X/Y/Z into wide layout: M1_x, M1_y, M1_z, M2_x, ...
  wide <- matrix(NA_real_, n_frames, 3L * n_markers)
  wide[, seq(1L, by = 3L, length.out = n_markers)] <- px
  wide[, seq(2L, by = 3L, length.out = n_markers)] <- py
  wide[, seq(3L, by = 3L, length.out = n_markers)] <- pz
  colnames(wide) <- as.vector(rbind(paste0(markers, "_x"),
                                    paste0(markers, "_y"),
                                    paste0(markers, "_z")))
  nd <- as.data.frame(wide, check.names = FALSE)
  class(nd) <- c("c3d_data_wide", "c3d_data", "data.frame")

  ana <- if (isTRUE(include_analog)) {
    .c3d_resolve_analog(x, point_pe, n_frames, point_rate)
  } else {
    NULL
  }

  template <- c3dr::c3d_read(c3dr::c3d_example())
  apf <- if (!is.null(ana)) ana$perframe else 1L
  template$header$analogperframe <- as.integer(apf)

  obj <- suppressWarnings(
    c3dr::c3d_setdata(template, newdata = nd,
                      newanalog = if (!is.null(ana)) ana$df else NULL))

  # Force-platform parameters reference specific analog channels; drop them so
  # arbitrary marker/analog counts write cleanly.
  obj <- .c3d_strip_forceplatforms(obj)
  obj$residuals <- matrix(0, n_frames, n_markers)

  obj$parameters$POINT$RATE <- point_rate
  obj$header$framerate <- point_rate
  obj$parameters$POINT$UNITS <- units
  obj$parameters$POINT$FRAMES <- n_frames

  if (!is.null(ana)) {
    # c3d_setdata sets ANALOG LABELS/USED only; resize the remaining per-channel
    # parameter vectors to the new channel count.
    obj <- .c3d_resize_analog_params(obj, colnames(ana$df))
    obj$parameters$ANALOG$RATE <- ana$rate
    obj$header$analogperframe <- as.integer(ana$perframe)
  } else {
    A <- obj$parameters$ANALOG
    A$LABELS <- character(0); A$DESCRIPTIONS <- character(0)
    A$UNITS <- character(0); A$SCALE <- numeric(0)
    A$OFFSET <- numeric(0); A$USED <- 0L
    obj$parameters$ANALOG <- A
    obj$header$nanalogs <- 0L
    obj$header$analogperframe <- 1L
    obj$analog <- replicate(n_frames, matrix(numeric(0), 1, 0),
                            simplify = FALSE)
  }

  c3dr::c3d_write(obj, path)
  invisible(path)
}

#' Validate marker labels for a marker-trajectory write
#'
#' Empty labels are indistinguishable from padding in the TRC/C3D layout, and
#' duplicate labels collapse markers on a C3D write; both silently corrupt the
#' round-trip, so they are rejected up front.
#'
#' @param markers Character vector of marker labels.
#' @return Invisibly `TRUE`; stops on empty or duplicated labels.
#' @keywords internal
.validate_marker_labels <- function(markers) {
  if (any(is.na(markers) | !nzchar(markers))) {
    stop("marker labels must be non-empty (blank labels cannot round-trip ",
         "through the TRC/C3D marker layout).", call. = FALSE)
  }
  dup <- unique(markers[duplicated(markers)])
  if (length(dup) > 0) {
    stop("marker labels must be unique; duplicated: ",
         paste(dup, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

#' Resolve the marker-bearing PhysioExperiment for a C3D write
#'
#' For a plain `PhysioExperiment` this is the object itself. For a
#' `MultiRatePhysioExperiment` it is the stream whose assays include the
#' `"position_*"` markers (falling back to a `"recording"` stream).
#'
#' @param x A PhysioExperiment or MultiRatePhysioExperiment.
#' @return A PhysioExperiment holding the marker assays.
#' @keywords internal
.c3d_point_source <- function(x) {
  if (!inherits(x, "MultiRatePhysioExperiment")) return(x)
  streams <- PhysioCore::streams(x)
  need <- c("position_x", "position_y", "position_z")
  for (nm in names(streams)) {
    s <- streams[[nm]]
    if (all(need %in% SummarizedExperiment::assayNames(s))) return(s)
  }
  if ("recording" %in% names(streams)) return(streams[["recording"]])
  stop("MultiRatePhysioExperiment has no stream with 'position_*' marker ",
       "assays.", call. = FALSE)
}

#' Determine the POINT units for a C3D write
#'
#' @param x A PhysioExperiment.
#' @return A single character string (defaults to `"mm"`).
#' @keywords internal
.c3d_point_units <- function(x) {
  meta <- S4Vectors::metadata(x)
  u <- meta$c3d_parameters$POINT$UNITS
  if (is.null(u) || !nzchar(u[1])) u <- meta$Units
  if (is.null(u) || !nzchar(u[1])) {
    cd <- SummarizedExperiment::colData(x)
    if (!is.null(cd$unit) && length(cd$unit) > 0 && nzchar(as.character(cd$unit)[1])) {
      u <- as.character(cd$unit)[1]
    }
  }
  if (is.null(u) || !nzchar(u[1])) u <- "mm"
  as.character(u[1])
}

#' Resolve analog data to write into a C3D file
#'
#' Returns the analog data frame (class `c3d_analog`), its sampling rate, and
#' the integer analog-subframes-per-point-frame ratio, or `NULL` if the object
#' carries no analog data.
#'
#' @param x The original PhysioExperiment or MultiRatePhysioExperiment.
#' @param point_pe The marker-bearing PhysioExperiment (may equal `x`).
#' @param n_frames Number of point frames.
#' @param point_rate Point sampling rate (Hz).
#' @return A list `list(df, rate, perframe)` or `NULL`.
#' @keywords internal
.c3d_resolve_analog <- function(x, point_pe, n_frames, point_rate) {
  adf <- NULL

  if (inherits(x, "MultiRatePhysioExperiment") &&
      "analog" %in% PhysioCore::streamNames(x)) {
    stream <- PhysioCore::streams(x)[["analog"]]
    adf <- as.data.frame(as.matrix(SummarizedExperiment::assay(stream, 1L)),
                         check.names = FALSE)
  } else {
    meta <- S4Vectors::metadata(point_pe)
    if (!is.null(meta$analog_data) && nrow(meta$analog_data) > 0) {
      adf <- as.data.frame(meta$analog_data, check.names = FALSE)
    }
  }

  if (is.null(adf) || nrow(adf) == 0) return(NULL)

  # Coerce to numeric columns.
  adf[] <- lapply(adf, function(col) as.numeric(as.character(col)))

  perframe <- round(nrow(adf) / n_frames)
  if (perframe < 1) perframe <- 1L
  if (nrow(adf) != n_frames * perframe) {
    stop(sprintf(paste0("analog data has %d rows, not an integer multiple of ",
                        "the %d point frames; cannot derive a point/analog ",
                        "rate ratio."), nrow(adf), n_frames), call. = FALSE)
  }
  # The C3D analog rate MUST be an integer multiple of the point rate: the
  # writer derives analog-subframes-per-frame from ANALOG:RATE / POINT:RATE, so
  # a stale/declared rate that disagrees with the actual row count would
  # silently truncate or pad the analog block. Always derive it from the frame
  # ratio to keep the file self-consistent.
  arate <- point_rate * perframe
  class(adf) <- c("c3d_analog", "data.frame")
  list(df = adf, rate = as.numeric(arate), perframe = as.integer(perframe))
}

#' Drop force-platform parameters/data from a c3d object
#'
#' Force-platform parameters (`FORCE_PLATFORM:CHANNEL`, `CORNERS`, ...) index
#' specific analog channels; removing them lets a c3d object with an arbitrary
#' number of markers/analog channels be written by \pkg{c3dr}.
#'
#' @param obj A `c3d` object.
#' @return The object with force platforms cleared.
#' @keywords internal
.c3d_strip_forceplatforms <- function(obj) {
  fp <- obj$parameters$FORCE_PLATFORM
  if (!is.null(fp)) {
    fp$USED <- 0L
    fp$TYPE <- integer(0)
    fp$ZERO <- integer(0)
    fp$CORNERS <- array(numeric(0), dim = c(3, 4, 0))
    fp$ORIGIN <- array(numeric(0), dim = c(3, 0))
    fp$CHANNEL <- matrix(integer(0), 0, 0)
    fp$CAL_MATRIX <- array(numeric(0), dim = c(6, 6, 0))
    obj$parameters$FORCE_PLATFORM <- fp
  }
  obj$forceplatform <- list()
  obj
}

#' Resize per-channel ANALOG parameter vectors to a new channel count
#'
#' @param obj A `c3d` object (after `c3d_setdata`).
#' @param labels Character vector of analog channel labels.
#' @return The object with `ANALOG` parameter vectors sized to `labels`.
#' @keywords internal
.c3d_resize_analog_params <- function(obj, labels) {
  n <- length(labels)
  A <- obj$parameters$ANALOG
  A$USED <- as.integer(n)
  A$LABELS <- labels
  A$DESCRIPTIONS <- rep("", n)
  A$SCALE <- rep(1, n)
  A$OFFSET <- rep(0L, n)
  A$UNITS <- rep("", n)
  obj$parameters$ANALOG <- A
  obj$header$nanalogs <- as.integer(n)
  obj
}

#' Parse wide-format C3D point data into coordinate matrices
#'
#' Takes the data frame returned by `c3dr::c3d_data(c3d, format = "wide")`
#' and splits it into separate X, Y, Z matrices with marker name columns.
#' The wide format has columns named `MarkerName_x`, `MarkerName_y`,
#' `MarkerName_z` for each marker.
#'
#' @param point_data A data frame from `c3dr::c3d_data()` in wide format.
#' @return A list with elements `pos_x`, `pos_y`, `pos_z` (matrices) and
#'   `marker_names` (character vector).
#' @keywords internal
.parse_c3d_wide <- function(point_data) {
  col_names <- colnames(point_data)

  # Identify X columns (ending in _x)
  x_cols <- grep("_x$", col_names, value = TRUE)
  y_cols <- grep("_y$", col_names, value = TRUE)
  z_cols <- grep("_z$", col_names, value = TRUE)

  # Extract marker names from X columns (remove _x suffix)
  marker_names <- sub("_x$", "", x_cols)

  if (length(marker_names) == 0) {
    stop("No marker data found in C3D point data", call. = FALSE)
  }

  # Verify matching Y and Z columns exist
  expected_y <- paste0(marker_names, "_y")
  expected_z <- paste0(marker_names, "_z")

  missing_y <- setdiff(expected_y, y_cols)
  missing_z <- setdiff(expected_z, z_cols)

  if (length(missing_y) > 0) {
    stop(
      "Missing Y coordinates for markers: ",
      paste(sub("_y$", "", missing_y), collapse = ", "),
      call. = FALSE
    )
  }
  if (length(missing_z) > 0) {
    stop(
      "Missing Z coordinates for markers: ",
      paste(sub("_z$", "", missing_z), collapse = ", "),
      call. = FALSE
    )
  }

  # Build matrices
  n_frames <- nrow(point_data)
  n_markers <- length(marker_names)

  pos_x <- as.matrix(point_data[, paste0(marker_names, "_x"), drop = FALSE])
  pos_y <- as.matrix(point_data[, paste0(marker_names, "_y"), drop = FALSE])
  pos_z <- as.matrix(point_data[, paste0(marker_names, "_z"), drop = FALSE])

  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  list(
    pos_x = pos_x,
    pos_y = pos_y,
    pos_z = pos_z,
    marker_names = marker_names
  )
}
