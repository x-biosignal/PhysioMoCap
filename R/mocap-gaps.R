# Gap Detection and Filling for Motion Capture Data
# Provides functions to detect, report, and fill gaps (NA runs) in MoCap data

#' Detect gaps (contiguous NA runs) in assay data
#'
#' Scans the specified assay of a PhysioExperiment object for contiguous runs
#' of NA values and returns a data.frame describing each gap.
#'
#' @param pe A PhysioExperiment object
#' @param assay_name Name of the assay to scan (default: "position_x")
#'
#' @return A data.frame with columns:
#'   \itemize{
#'     \item channel - Channel (column) name or index
#'     \item start - Start index of the gap (1-based)
#'     \item end - End index of the gap (1-based)
#'     \item size - Number of consecutive NA values
#'   }
#'
#' @references
#' Federolf PA (2013). "A novel approach to solve the 'missing marker problem'
#' in marker-based motion analysis that does not require additional
#' assumptions about the biodynamic model." Journal of Biomechanics,
#' 46(13), 2173-2178.
#'
#' @seealso [reportGaps()], [fillGaps()], [fillGapsLinear()]
#'
#' @export
#'
#' @examples
#' pe <- PhysioCore::PhysioExperiment(
#'   assays = S4Vectors::SimpleList(position_x = matrix(c(1, NA, NA, 4), ncol = 1)),
#'   colData = S4Vectors::DataFrame(label = "M1", type = "marker"),
#'   samplingRate = 120
#' )
#' gaps <- detectGaps(pe, assay_name = "position_x")
detectGaps <- function(pe, assay_name = "position_x") {
  stopifnot(inherits(pe, "PhysioExperiment"))
  mat <- SummarizedExperiment::assay(pe, assay_name)

  results <- list()

  for (j in seq_len(ncol(mat))) {
    ch_name <- if (!is.null(colnames(mat))) colnames(mat)[j] else as.character(j)
    runs <- rle(is.na(mat[, j]))
    # Find NA runs
    na_idx <- which(runs$values)
    if (length(na_idx) == 0L) next

    # Compute cumulative start positions
    end_positions <- cumsum(runs$lengths)
    start_positions <- end_positions - runs$lengths + 1L

    for (k in na_idx) {
      results[[length(results) + 1L]] <- data.frame(
        channel = ch_name,
        start = start_positions[k],
        end = end_positions[k],
        size = runs$lengths[k],
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(results) == 0L) {
    return(data.frame(
      channel = character(0),
      start = integer(0),
      end = integer(0),
      size = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  do.call(rbind, results)
}


#' Report summary statistics for detected gaps
#'
#' Prints a human-readable summary of gap statistics including total number of
#' gaps, average gap size, and percentage of missing data.
#'
#' @param gaps A data.frame as returned by \code{\link{detectGaps}}
#' @param sampling_rate Sampling rate in Hz (used to report gap durations)
#'
#' @return Invisibly returns a list with summary statistics:
#'   \itemize{
#'     \item total_gaps - Total number of gaps
#'     \item avg_size - Average gap size in samples
#'     \item total_missing - Total number of missing samples
#'     \item pct_missing - Percentage of missing data (if computable)
#'   }
#'
#' @references
#' Federolf PA (2013). "A novel approach to solve the 'missing marker problem'
#' in marker-based motion analysis that does not require additional
#' assumptions about the biodynamic model." Journal of Biomechanics,
#' 46(13), 2173-2178.
#'
#' @seealso [detectGaps()], [fillGaps()], [fillGapsLinear()]
#'
#' @export
#'
#' @examples
#' gaps <- data.frame(
#'   channel = c("M1", "M1", "M2"),
#'   start = c(10, 50, 20),
#'   end = c(15, 55, 30),
#'   size = c(6, 6, 11)
#' )
#' reportGaps(gaps, sampling_rate = 120)
reportGaps <- function(gaps, sampling_rate) {
  stopifnot(is.data.frame(gaps))
  stopifnot(is.numeric(sampling_rate) && length(sampling_rate) == 1L && sampling_rate > 0)

  total_gaps <- nrow(gaps)

  if (total_gaps == 0L) {
    cat("No gaps detected.\n")
    return(invisible(list(
      total_gaps = 0L,
      avg_size = 0,
      total_missing = 0L,
      pct_missing = 0
    )))
  }

  avg_size <- mean(gaps$size)
  total_missing <- sum(gaps$size)
  avg_duration <- avg_size / sampling_rate

  cat(sprintf("Gap Report\n"))
  cat(sprintf("  Total gaps:       %d\n", total_gaps))
  cat(sprintf("  Average size:     %.1f samples (%.4f s)\n", avg_size, avg_duration))
  cat(sprintf("  Total missing:    %d samples\n", total_missing))
  cat(sprintf("  Channels affected: %d\n", length(unique(gaps$channel))))

  invisible(list(
    total_gaps = total_gaps,
    avg_size = avg_size,
    total_missing = total_missing
  ))
}


#' Fill gaps in motion capture data
#'
#' Fills NA gaps in one or more position assays of a PhysioExperiment object
#' using interpolation. Gaps larger than \code{max_gap} are left as NA.
#'
#' @param pe A PhysioExperiment object
#' @param method Interpolation method: \code{"linear"} uses
#'   \code{\link[stats]{approx}}, \code{"spline"} uses
#'   \code{\link[stats]{smooth.spline}}
#' @param max_gap Maximum gap size (in samples) to fill. Gaps larger than this
#'   are left as NA. Set to \code{Inf} to fill all gaps.
#' @param assay_names Character vector of assay names to fill. If \code{NULL}
#'   (default), fills all position assays that are present
#'   (position_x, position_y, position_z, keypoint_x, keypoint_y).
#'
#' @return PhysioExperiment with filled assays (modified in place)
#'
#' @references
#' Federolf PA (2013). "A novel approach to solve the 'missing marker problem'
#' in marker-based motion analysis that does not require additional
#' assumptions about the biodynamic model." Journal of Biomechanics,
#' 46(13), 2173-2178.
#'
#' @seealso [detectGaps()], [reportGaps()], [fillGapsLinear()], [fillGapsSpline()]
#'
#' @export
#'
#' @examples
#' pe <- PhysioCore::PhysioExperiment(
#'   assays = S4Vectors::SimpleList(
#'     position_x = matrix(c(1, NA, NA, 4, 5), ncol = 1),
#'     position_y = matrix(c(10, NA, NA, 40, 50), ncol = 1)
#'   ),
#'   colData = S4Vectors::DataFrame(label = "M1", type = "marker"),
#'   samplingRate = 120
#' )
#' pe_filled <- fillGaps(pe, method = "linear", max_gap = 50)
fillGaps <- function(pe,
                     method = c("spline", "linear"),
                     max_gap = 50,
                     assay_names = NULL) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  method <- match.arg(method)
  stopifnot(is.numeric(max_gap) && length(max_gap) == 1L && max_gap > 0)


  # Determine which assays to fill
  all_assay_names <- SummarizedExperiment::assayNames(pe)
  if (is.null(assay_names)) {
    position_assays <- c("position_x", "position_y", "position_z",
                         "keypoint_x", "keypoint_y")
    assay_names <- intersect(position_assays, all_assay_names)
    if (length(assay_names) == 0L) {
      warning("No position assays found to fill.", call. = FALSE)
      return(pe)
    }
  } else {
    missing <- setdiff(assay_names, all_assay_names)
    if (length(missing) > 0L) {
      stop(sprintf("Assay(s) not found: %s", paste(missing, collapse = ", ")),
           call. = FALSE)
    }
  }

  # Choose fill function
  fill_fn <- switch(method,
    "linear" = fillGapsLinear,
    "spline" = fillGapsSpline
  )

  # Fill each assay

  for (aname in assay_names) {
    mat <- SummarizedExperiment::assay(pe, aname)

    for (j in seq_len(ncol(mat))) {
      x <- mat[, j]
      if (!any(is.na(x))) next

      # Identify gaps and check sizes
      runs <- rle(is.na(x))
      end_positions <- cumsum(runs$lengths)
      start_positions <- end_positions - runs$lengths + 1L
      na_idx <- which(runs$values)

      # Track which positions to protect (gaps too large)
      protect <- logical(length(x))
      for (k in na_idx) {
        if (runs$lengths[k] > max_gap) {
          protect[start_positions[k]:end_positions[k]] <- TRUE
        }
      }

      # Fill the vector
      filled <- fill_fn(x)

      # Restore protected (too-large) gaps to NA
      if (any(protect)) {
        filled[protect] <- NA_real_
      }

      mat[, j] <- filled
    }

    SummarizedExperiment::assay(pe, aname) <- mat
  }

  pe
}


#' Linear interpolation for a single vector
#'
#' Fills NA values in a numeric vector using linear interpolation via
#' \code{\link[stats]{approx}}.
#'
#' @param x Numeric vector potentially containing NAs
#'
#' @return Numeric vector with NAs filled by linear interpolation. Leading and
#'   trailing NAs (outside the range of valid data) remain as NA.
#'
#' @references
#' Federolf PA (2013). "A novel approach to solve the 'missing marker problem'
#' in marker-based motion analysis that does not require additional
#' assumptions about the biodynamic model." Journal of Biomechanics,
#' 46(13), 2173-2178.
#'
#' @seealso [fillGapsSpline()], [fillGaps()], [detectGaps()]
#'
#' @export
#'
#' @examples
#' x <- c(1, NA, NA, 4, 5, NA, 7)
#' fillGapsLinear(x)
fillGapsLinear <- function(x) {
  stopifnot(is.numeric(x))
  valid <- which(!is.na(x))
  if (length(valid) < 2L) return(x)

  stats::approx(
    x = valid,
    y = x[valid],
    xout = seq_along(x),
    method = "linear",
    rule = 1  # NAs outside range remain NA
  )$y
}


#' Spline interpolation for a single vector
#'
#' Fills NA values in a numeric vector using smooth spline interpolation via
#' \code{\link[stats]{smooth.spline}}.
#'
#' @param x Numeric vector potentially containing NAs
#' @param spar Smoothing parameter passed to \code{\link[stats]{smooth.spline}}.
#'   If \code{NULL} (default), the smoothing parameter is chosen automatically.
#'
#' @return Numeric vector with NAs filled by spline interpolation. Leading and
#'   trailing NAs (outside the range of valid data) remain as NA.
#'
#' @references
#' Federolf PA (2013). "A novel approach to solve the 'missing marker problem'
#' in marker-based motion analysis that does not require additional
#' assumptions about the biodynamic model." Journal of Biomechanics,
#' 46(13), 2173-2178.
#'
#' @seealso [fillGapsLinear()], [fillGaps()], [detectGaps()]
#'
#' @export
#'
#' @examples
#' x <- c(1, NA, NA, 4, 5, NA, 7)
#' fillGapsSpline(x)
fillGapsSpline <- function(x, spar = NULL) {
  stopifnot(is.numeric(x))
  valid <- which(!is.na(x))
  if (length(valid) < 4L) {
    # smooth.spline needs at least 4 unique points; fall back to linear
    return(fillGapsLinear(x))
  }

  # Determine range of valid data
  first_valid <- min(valid)
  last_valid <- max(valid)

  # Fit spline on valid points
  fit_args <- list(x = valid, y = x[valid])
  if (!is.null(spar)) {
    fit_args$spar <- spar
  }
  fit <- do.call(stats::smooth.spline, fit_args)

  # Predict at all positions within valid range
  result <- x
  predict_idx <- first_valid:last_valid
  predicted <- stats::predict(fit, predict_idx)
  result[predict_idx] <- predicted$y

  result
}
