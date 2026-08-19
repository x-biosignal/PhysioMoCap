# Resampling Functions for Motion Capture Data
# Provides resampling, rate conversion, and multi-signal synchronization

#' Resample a single numeric vector
#'
#' Resamples a numeric vector from one sampling rate to another using
#' interpolation.
#'
#' @param x Numeric vector to resample.
#' @param from_rate Original sampling rate in Hz.
#' @param to_rate Target sampling rate in Hz.
#' @param method Interpolation method: "linear" uses \code{\link[stats]{approx}},
#'   "spline" uses \code{\link[stats]{spline}}.
#'
#' @return A numeric vector resampled at the target rate.
#'
#' @references
#' Oppenheim AV, Willsky AS, Nawab SH (1997). "Signals and Systems."
#' 2nd ed. Prentice Hall.
#'
#' @seealso [resampleSignal()] for resampling PhysioExperiment objects,
#'   [synchronizeSignals()] for synchronizing multiple signals.
#'
#' @export
#'
#' @examples
#' # Resample a 100Hz signal to 200Hz
#' x <- sin(seq(0, 2 * pi, length.out = 100))
#' x_up <- resampleVector(x, from_rate = 100, to_rate = 200)
#' length(x_up)  # 200
resampleVector <- function(x, from_rate, to_rate, method = c("linear", "spline")) {
  stopifnot(is.numeric(x))
  stopifnot(is.numeric(from_rate) && length(from_rate) == 1 && from_rate > 0)
  stopifnot(is.numeric(to_rate) && length(to_rate) == 1 && to_rate > 0)

  method <- match.arg(method)
  n_in <- length(x)

  if (n_in < 2) {
    return(x)
  }

  # Duration in seconds (excluding the last sample instant for proper spacing)
  duration <- (n_in - 1) / from_rate

  # Number of output samples
n_out <- round(duration * to_rate) + 1L

  # Time axes
  t_in <- seq(0, duration, length.out = n_in)
  t_out <- seq(0, duration, length.out = n_out)

  # Check for NAs in input
  has_na <- any(is.na(x))

  if (has_na) {
    # Create an NA mask: 1 where NA, 0 where valid
    na_mask <- as.numeric(is.na(x))
    # Interpolate the mask to the output grid; values >= 0.5 become NA
    mask_out <- stats::approx(t_in, na_mask, xout = t_out,
                              method = "linear", rule = 2)$y

    # For interpolation, temporarily replace NAs with linearly interpolated
    # values so approx/spline can work, then re-apply the NA mask
    x_filled <- x
    valid <- which(!is.na(x))
    if (length(valid) >= 2) {
      x_filled <- stats::approx(t_in[valid], x[valid], xout = t_in,
                                 method = "linear", rule = 2)$y
    }

    if (method == "linear") {
      result <- stats::approx(t_in, x_filled, xout = t_out,
                               method = "linear", rule = 2)$y
    } else {
      result <- stats::spline(t_in, x_filled, xout = t_out,
                               method = "natural")$y
    }

    # Re-apply NA mask
    result[mask_out >= 0.5] <- NA_real_
    return(result)
  }

  if (method == "linear") {
    stats::approx(t_in, x, xout = t_out, method = "linear", rule = 2)$y
  } else {
    stats::spline(t_in, x, xout = t_out, method = "natural")$y
  }
}


#' Resample signal assays to a new sampling rate
#'
#' Resamples all (or selected) numeric assays of a PhysioExperiment object to a
#' new target sampling rate. Both upsampling and downsampling are supported.
#'
#' @param pe A PhysioExperiment object.
#' @param target_rate Target sampling rate in Hz.
#' @param method Interpolation method: "linear" (default) or "spline".
#' @param assay_names Character vector of assay names to resample. If NULL
#'   (default), all numeric assays are resampled.
#'
#' @return A new PhysioExperiment with resampled assays, updated
#'   \code{samplingRate}, and updated \code{metadata$time} vector.
#'
#' @references
#' Oppenheim AV, Willsky AS, Nawab SH (1997). "Signals and Systems."
#' 2nd ed. Prentice Hall.
#'
#' @seealso [resampleVector()] for resampling individual numeric vectors,
#'   [synchronizeSignals()] for synchronizing multiple experiments.
#'
#' @export
#'
#' @examples
#' pe <- PhysioCore::PhysioExperiment(
#'   assays = S4Vectors::SimpleList(
#'     position_x = matrix(sin(seq(0, 2 * pi, length.out = 100)), ncol = 1)
#'   ),
#'   colData = S4Vectors::DataFrame(label = "M1", type = "marker"),
#'   samplingRate = 100
#' )
#' pe2 <- resampleSignal(pe, target_rate = 200)
#' PhysioCore::samplingRate(pe2)  # 200
resampleSignal <- function(pe, target_rate, method = c("linear", "spline"),
                           assay_names = NULL) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  stopifnot(is.numeric(target_rate) && length(target_rate) == 1 && target_rate > 0)

  method <- match.arg(method)
  from_rate <- PhysioCore::samplingRate(pe)

  if (is.na(from_rate) || from_rate <= 0) {
    stop("Source PhysioExperiment must have a valid positive samplingRate.",
         call. = FALSE)
  }

  # Determine which assays to resample
  all_names <- SummarizedExperiment::assayNames(pe)
  if (is.null(assay_names)) {
    # Select all numeric assays
    assay_names <- vapply(all_names, function(nm) {
      is.numeric(SummarizedExperiment::assay(pe, nm))
    }, logical(1))
    assay_names <- all_names[assay_names]
  } else {
    missing <- setdiff(assay_names, all_names)
    if (length(missing) > 0) {
      stop(sprintf("Assay(s) not found: %s", paste(missing, collapse = ", ")),
           call. = FALSE)
    }
  }

  if (length(assay_names) == 0) {
    warning("No numeric assays found to resample.", call. = FALSE)
    return(pe)
  }

  # Resample each assay
  new_assays <- list()
  for (nm in all_names) {
    mat <- SummarizedExperiment::assay(pe, nm)
    if (nm %in% assay_names) {
      new_assays[[nm]] <- .resampleMatrix(mat, from_rate, target_rate, method)
    } else {
      new_assays[[nm]] <- mat
    }
  }

  # Compute new time vector
  n_out <- nrow(new_assays[[assay_names[1]]])
  duration <- (n_out - 1) / target_rate
  new_time <- seq(0, duration, length.out = n_out)

  # Build new PhysioExperiment
  md <- S4Vectors::metadata(pe)
  md[["time"]] <- new_time

  pe_new <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(new_assays),
    colData = SummarizedExperiment::colData(pe),
    metadata = md,
    samplingRate = target_rate
  )

  .recordProv(pe_new, output_assay = "resampled", .package = "PhysioMoCap",
              from = pe)
}


#' Synchronize multiple PhysioExperiment objects
#'
#' Resamples a list of PhysioExperiment objects so they all share the same
#' sampling rate and have the same number of time points.
#'
#' @param pe_list A list of PhysioExperiment objects.
#' @param target_rate Target sampling rate in Hz. If NULL (default), the
#'   highest sampling rate among the inputs is used.
#' @param method Interpolation method: "linear" (default) or "spline".
#'
#' @return A list of PhysioExperiment objects, all with the same sampling rate
#'   and the same number of rows (time points).
#'
#' @references
#' Oppenheim AV, Willsky AS, Nawab SH (1997). "Signals and Systems."
#' 2nd ed. Prentice Hall.
#'
#' @seealso [resampleSignal()] for resampling individual PhysioExperiment objects,
#'   [resampleVector()] for resampling raw numeric vectors.
#'
#' @export
#'
#' @examples
#' pe1 <- PhysioCore::PhysioExperiment(
#'   assays = S4Vectors::SimpleList(
#'     raw = matrix(rnorm(100), ncol = 1)
#'   ),
#'   colData = S4Vectors::DataFrame(label = "ch1", type = "marker"),
#'   samplingRate = 100
#' )
#' pe2 <- PhysioCore::PhysioExperiment(
#'   assays = S4Vectors::SimpleList(
#'     raw = matrix(rnorm(200), ncol = 1)
#'   ),
#'   colData = S4Vectors::DataFrame(label = "ch1", type = "marker"),
#'   samplingRate = 200
#' )
#' synced <- synchronizeSignals(list(pe1, pe2))
synchronizeSignals <- function(pe_list, target_rate = NULL,
                               method = c("linear", "spline")) {
  stopifnot(is.list(pe_list) && length(pe_list) >= 1)
  stopifnot(all(vapply(pe_list, inherits, logical(1), "PhysioExperiment")))

  method <- match.arg(method)

  # Get sampling rates
  rates <- vapply(pe_list, PhysioCore::samplingRate, numeric(1))
  if (any(is.na(rates) | rates <= 0)) {
    stop("All PhysioExperiment objects must have valid positive samplingRate.",
         call. = FALSE)
  }

  # Determine target rate
  if (is.null(target_rate)) {
    target_rate <- max(rates)
  }
  stopifnot(is.numeric(target_rate) && length(target_rate) == 1 && target_rate > 0)

  # Resample each to target rate
  resampled <- lapply(pe_list, function(pe) {
    if (PhysioCore::samplingRate(pe) == target_rate) {
      pe
    } else {
      resampleSignal(pe, target_rate = target_rate, method = method)
    }
  })

  # Find the minimum number of time points across all resampled objects
  n_rows <- vapply(resampled, function(pe) {
    nrow(SummarizedExperiment::assay(pe, SummarizedExperiment::assayNames(pe)[1]))
  }, integer(1))
  min_rows <- min(n_rows)

  # Trim all to the same length
  result <- lapply(resampled, function(pe) {
    current_rows <- nrow(SummarizedExperiment::assay(
      pe, SummarizedExperiment::assayNames(pe)[1]
    ))
    if (current_rows == min_rows) {
      return(pe)
    }
    # Truncate to min_rows
    .truncatePE(pe, min_rows, target_rate)
  })

  result
}


# ---- Internal helpers -------------------------------------------------------

#' Resample a matrix column by column
#' @keywords internal
#' @noRd
.resampleMatrix <- function(mat, from_rate, to_rate, method) {
  n_in <- nrow(mat)
  n_cols <- ncol(mat)

  # Compute expected output length
  duration <- (n_in - 1) / from_rate
  n_out <- round(duration * to_rate) + 1L

  result <- matrix(NA_real_, nrow = n_out, ncol = n_cols)
  colnames(result) <- colnames(mat)

  for (j in seq_len(n_cols)) {
    result[, j] <- resampleVector(mat[, j], from_rate, to_rate, method)
  }

  result
}


#' Truncate a PhysioExperiment to a specified number of rows
#' @keywords internal
#' @noRd
.truncatePE <- function(pe, n_rows, target_rate) {
  all_names <- SummarizedExperiment::assayNames(pe)
  new_assays <- list()
  for (nm in all_names) {
    mat <- SummarizedExperiment::assay(pe, nm)
    new_assays[[nm]] <- mat[seq_len(n_rows), , drop = FALSE]
  }

  duration <- (n_rows - 1) / target_rate
  new_time <- seq(0, duration, length.out = n_rows)

  md <- S4Vectors::metadata(pe)
  md[["time"]] <- new_time

  PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(new_assays),
    colData = SummarizedExperiment::colData(pe),
    metadata = md,
    samplingRate = target_rate
  )
}
