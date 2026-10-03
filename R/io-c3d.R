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
#'   frames and columns as markers. Residual quality data are not exposed by
#'   this reader. Column metadata (`colData`)
#'   contains `label` (marker names from POINT:LABELS), `type` (`"marker"`),
#'   and `body_segment` (`NA`). Metadata includes `c3d_parameters`,
#'   `source_file`, and a `time` vector computed from frame rate.
#' @references
#' C3D.org. "The C3D File Format." \url{https://www.c3d.org/}.
#'
#' @seealso [c3dEventTable()], [readTRC()], [readBVH()], [readOpenPose()]
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
#'   `MultiPhysioExperiment` whose marker stream carries those assays.
#' @param path Character string giving the output `.c3d` path.
#' @param include_analog Logical; if `TRUE` (default) and the object carries
#'   analog data (in `metadata(x)$analog_data`, or as an `"analog"` stream of
#'   a `MultiPhysioExperiment`), that data is written as C3D analog
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
      !inherits(x, "MultiPhysioExperiment")) {
    stop("'x' must be a PhysioExperiment or MultiPhysioExperiment.",
         call. = FALSE)
  }
  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("'path' must be a non-empty character string.", call. = FALSE)
  }
  if (!is.logical(include_analog) || length(include_analog) != 1 ||
      is.na(include_analog)) {
    stop("'include_analog' must be TRUE or FALSE.", call. = FALSE)
  }

  # A MultiPhysioExperiment carries markers in its marker stream and
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
#' `MultiPhysioExperiment` it is the stream whose assays include the
#' `"position_*"` markers (falling back to a `"recording"` stream).
#'
#' @param x A PhysioExperiment or MultiPhysioExperiment.
#' @return A PhysioExperiment holding the marker assays.
#' @keywords internal
.c3d_point_source <- function(x) {
  if (!inherits(x, "MultiPhysioExperiment")) return(x)
  streams <- PhysioExperiment::streams(x)
  need <- c("position_x", "position_y", "position_z")
  for (nm in names(streams)) {
    s <- streams[[nm]]
    if (all(need %in% SummarizedExperiment::assayNames(s))) return(s)
  }
  if ("recording" %in% names(streams)) return(streams[["recording"]])
  stop("MultiPhysioExperiment has no stream with 'position_*' marker ",
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
#' @param x The original PhysioExperiment or MultiPhysioExperiment.
#' @param point_pe The marker-bearing PhysioExperiment (may equal `x`).
#' @param n_frames Number of point frames.
#' @param point_rate Point sampling rate (Hz).
#' @return A list `list(df, rate, perframe)` or `NULL`.
#' @keywords internal
.c3d_resolve_analog <- function(x, point_pe, n_frames, point_rate) {
  adf <- NULL

  if (inherits(x, "MultiPhysioExperiment") &&
      "analog" %in% PhysioExperiment::streamNames(x)) {
    stream <- PhysioExperiment::streams(x)[["analog"]]
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

#' Extract C3D Parameter Events on the Recording Clock
#'
#' Converts the `EVENT` parameter group retained by [readC3D()] into a table
#' of seconds relative to the first stored point sample. The event clock must
#' be declared explicitly. Header events are not read by this function.
#'
#' @param x A `PhysioExperiment` with `metadata(x)$c3d_parameters`.
#' @param event_time_reference Either `"trial"` (C3D frame 1 is time zero)
#'   or `"recording"` (first stored sample is time zero). Required; not inferred.
#' @param first_frame Optional positive, one-based original first point frame,
#'   for trial-referenced events. Otherwise read from `TRIAL:ACTUAL_START_FIELD`.
#'   An explicit value overrides the stored parameter and is reported in output.
#' @param snap `"none"` preserves continuous event times. `"point"` explicitly
#'   requests rounding to the nearest point-sample grid, for frame annotations.
#' @param tolerance Maximum absolute rounding residual in seconds when
#'   `snap="point"`. Must be nonnegative and less than half a point period.
#' @param outside `"error"` rejects events outside the stored point sample
#'   times; `"keep"` retains them with `in_recording=FALSE`.
#' @return A data frame in original event order with `event_index`, `label`,
#'   `context`, `raw_minutes`, `raw_seconds`, `raw_time`, `time`,
#'   `snap_residual_s`, `recording_origin`, `first_frame`, `event_time_reference`,
#'   `snap`, and `in_recording`. `time` is relative to the recording start;
#'   `raw_time` is the declared event clock. Residual is raw minus snapped time
#'   on that clock, or zero when snapping is disabled. No-event files return
#'   a typed empty table. No sorting, event detection, or gait-cycle inference
#'   is performed. Event accuracy and the declared clock remain caller concerns.
#' @details
#' Point rate must match `samplingRate(x)`. A trial origin is never silently
#' replaced with zero. `ACTUAL_START_FIELD` comprises two unsigned 16-bit words,
#' low word first; signed 16-bit storage is decoded as unsigned. Snapping is
#' opt-in because a continuous event need not lie on a point frame. This adapter
#' does not change the signals or their local sample grid. Applying it after
#' cropping requires updating the first frame to match the stored samples.
#' @references C3D.org, EVENT:TIMES:
#'   \url{https://www.c3d.org/HTML/Documents/eventtimes1.htm}
#' @seealso [readC3D()], [segmentCohortCycles()]
#' @export
#' @details Operates on a parsed C3D object from the optional `c3dr` package,
#'   built from a binary `.c3d` file, so the example cannot run offline and is
#'   not executed.
#' @examples
#' \dontrun{
#' # `x` is a C3D object read via the c3dr package from a .c3d file.
#' c3dEventTable(x, event_time_reference = "trial_start")
#' }
c3dEventTable <- function(x, event_time_reference, first_frame = NULL,
                         snap = c("none", "point"), tolerance = 1e-5,
                         outside = c("error", "keep")) {
  if (!inherits(x, "PhysioExperiment"))
    stop("x must be a PhysioExperiment.", call. = FALSE)
  if (missing(event_time_reference) || !is.character(event_time_reference) ||
      length(event_time_reference) != 1L || is.na(event_time_reference) ||
      !event_time_reference %in% c("trial", "recording"))
    stop("Declare event_time_reference as 'trial' or 'recording'.", call. = FALSE)
  event_time_reference <- match.arg(event_time_reference, c("trial", "recording"))
  snap <- match.arg(snap); outside <- match.arg(outside)
  scalar <- function(v) is.numeric(v) && !is.complex(v) && length(v) == 1L && is.finite(v)
  params <- S4Vectors::metadata(x)$c3d_parameters
  if (!is.list(params) || !is.list(params$POINT))
    stop("Missing C3D POINT parameters.", call. = FALSE)
  rate <- params$POINT$RATE
  if (!scalar(rate) || rate <= 0 || !scalar(PhysioExperiment::samplingRate(x)) ||
      rate != PhysioExperiment::samplingRate(x))
    stop("POINT:RATE must be positive and match samplingRate(x).", call. = FALSE)
  if (!scalar(tolerance) || tolerance < 0 || (snap == "point" && tolerance >= 0.5 / rate))
    stop("tolerance must be nonnegative and less than half a point period.", call. = FALSE)
  ev <- params$EVENT
  empty <- data.frame(event_index = integer(), label = character(), context = character(),
    raw_minutes = numeric(), raw_seconds = numeric(), raw_time = numeric(), time = numeric(),
    snap_residual_s = numeric(), recording_origin = numeric(), first_frame = numeric(),
    event_time_reference = character(), snap = character(), in_recording = logical())
  if (is.null(ev)) return(empty)
  if (!is.list(ev) || !scalar(ev$USED) || ev$USED < 0 || ev$USED != floor(ev$USED))
    stop("EVENT:USED must be a nonnegative integer.", call. = FALSE)
  n <- ev$USED
  if (n > .Machine$integer.max) stop("EVENT:USED is too large.", call. = FALSE)
  if (n == 0) return(empty)
  if (!is.matrix(ev$TIMES) || !is.numeric(ev$TIMES) || is.complex(ev$TIMES) ||
      !identical(dim(ev$TIMES), c(2L, as.integer(n))) || any(!is.finite(ev$TIMES)))
    stop("EVENT:TIMES must be a finite 2 by USED numeric matrix.", call. = FALSE)
  labels_ok <- function(v) is.character(v) && length(v) == n && !anyNA(v)
  if (!labels_ok(ev$LABELS) || !labels_ok(ev$CONTEXTS))
    stop("EVENT labels and contexts must match USED without NA.", call. = FALSE)
  origin <- 0; first <- NA_real_
  if (event_time_reference == "recording" && !is.null(first_frame))
    stop("first_frame applies only to trial-referenced events.", call. = FALSE)
  if (event_time_reference == "trial") {
    if (is.null(first_frame)) {
      words <- params$TRIAL$ACTUAL_START_FIELD
      if (!is.numeric(words) || is.complex(words) || length(words) != 2L ||
          any(!is.finite(words)) || any(words != floor(words)) ||
          any(words < -32768 | words > 65535))
        stop("Supply first_frame or valid TRIAL:ACTUAL_START_FIELD words.", call. = FALSE)
      first_frame <- sum((words %% 65536) * c(1, 65536))
    }
    if (!scalar(first_frame) || first_frame < 1 || first_frame != floor(first_frame) ||
        first_frame > 2^32 - 1)
      stop("first_frame must be a positive one-based 32-bit frame number.", call. = FALSE)
    first <- first_frame; origin <- (first - 1) / rate
  }
  raw <- ev$TIMES[1, ] * 60 + ev$TIMES[2, ]
  converted <- raw; residual <- rep(0, n)
  if (any(!is.finite(raw))) stop("Nonfinite event time.", call. = FALSE)
  if (snap == "point") {
    frame <- raw * rate
    if (any(!is.finite(frame)) || any(abs(frame) >= 2^53))
      stop("Event frame is not representable precisely.", call. = FALSE)
    converted <- round(frame) / rate
    residual <- raw - converted
    if (any(abs(residual) > tolerance))
      stop("Event does not match the point grid within tolerance.", call. = FALSE)
  }
  origin_frame <- if (event_time_reference == "trial") first - 1 else 0
  if (snap == "point") {
    local_frame <- round(raw * rate) - origin_frame
    time <- local_frame / rate
    inside <- nrow(x) > 0 & local_frame >= 0 & local_frame <= nrow(x) - 1
  } else {
    time <- raw - origin
    # Compare on the source clock: subtracting a nonzero origin can otherwise
    # put an exact final event a few ulps beyond the local last sample.
    last_source_time <- (origin_frame + nrow(x) - 1) / rate
    inside <- nrow(x) > 0 & raw >= origin & raw <= last_source_time
  }
  if (any(!is.finite(c(origin, time, (origin_frame + nrow(x) - 1) / rate))))
    stop("Converted recording clock is not finite.", call. = FALSE)
  if (outside == "error" && any(!inside))
    stop("Events outside the stored point sample times; use outside='keep' explicitly.", call. = FALSE)
  data.frame(event_index = seq_len(n), label = ev$LABELS, context = ev$CONTEXTS,
    raw_minutes = as.numeric(ev$TIMES[1, ]), raw_seconds = as.numeric(ev$TIMES[2, ]),
    raw_time = as.numeric(raw), time = as.numeric(time), snap_residual_s = as.numeric(residual),
    recording_origin = rep(origin, n), first_frame = rep(first, n),
    event_time_reference = rep(event_time_reference, n), snap = rep(snap, n), in_recording = inside)
}
