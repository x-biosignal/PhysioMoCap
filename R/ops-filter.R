# Signal Filtering Functions for Motion Capture Data
# Provides Butterworth, Savitzky-Golay, and moving average filters

#' Filter signals in a PhysioExperiment object
#'
#' Applies a Butterworth IIR filter to signal data stored in a
#' PhysioExperiment object. The filter is applied using zero-phase filtering
#' (forward-backward) to avoid phase distortion.
#'
#' @param pe A PhysioExperiment object.
#' @param type Filter type: "lowpass", "highpass", "bandpass", or "bandstop".
#' @param cutoff Cutoff frequency in Hz. A single value for "lowpass" or
#'   "highpass"; a length-2 vector `c(low, high)` for "bandpass" or "bandstop".
#' @param order Filter order (default: 4).
#' @param assay_name Which assay to filter. If NULL, uses the first assay.
#' @param output_assay Name for the output assay. If NULL, defaults to
#'   `"{assay_name}_filtered"`.
#'
#' @return A PhysioExperiment object with filtered data stored as a new assay.
#'
#' @details
#' This function requires the \pkg{signal} package (listed in Suggests).
#' If not installed, an informative error message with install instructions
#' is provided.
#'
#' The Butterworth filter is designed using [signal::butter()] and applied
#' with [signal::filtfilt()] for zero-phase filtering. The cutoff frequency
#' is normalized to the Nyquist frequency automatically.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' Butterworth S (1930). "On the Theory of Filter Amplifiers."
#' Wireless Engineer, 7, 536-541.
#'
#' @seealso [butterworthFilter()] for filtering raw vectors and matrices,
#'   [savgolFilter()] for Savitzky-Golay polynomial smoothing,
#'   [movingAverage()] for simple moving average smoothing.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' pe <- make_mocap_markers(n_time = 500, n_markers = 4, sr = 120)
#' pe_filt <- filterSignals(pe, type = "lowpass", cutoff = 10)
#' }
filterSignals <- function(pe,
                          type = c("lowpass", "highpass", "bandpass", "bandstop"),
                          cutoff,
                          order = 4,
                          assay_name = NULL,
                          output_assay = NULL) {

  stopifnot(inherits(pe, "PhysioExperiment"))
  type <- match.arg(type)

  # Resolve assay names

  if (is.null(assay_name)) {
    assay_name <- defaultAssay(pe)
  }
  if (is.null(output_assay)) {
    output_assay <- paste0(assay_name, "_filtered")
  }

  sr <- samplingRate(pe)
  data <- SummarizedExperiment::assay(pe, assay_name)

  # Apply Butterworth filter
  filtered <- butterworthFilter(data,
                                cutoff = cutoff,
                                sampling_rate = sr,
                                type = type,
                                order = order)

  # Store as new assay
  SummarizedExperiment::assay(pe, output_assay) <- filtered
  .recordProv(pe, input_assay = assay_name, output_assay = output_assay,
              .package = "PhysioMoCap")
}


#' Apply a Butterworth filter to numeric data
#'
#' Designs a Butterworth IIR filter and applies it using zero-phase filtering
#' (forward-backward) to avoid phase distortion.
#'
#' @param x A numeric vector or matrix (time x channels).
#' @param cutoff Cutoff frequency in Hz. A single value for "lowpass" or
#'   "highpass"; a length-2 vector `c(low, high)` for "bandpass" or "bandstop".
#' @param sampling_rate Sampling rate in Hz.
#' @param type Filter type: "lowpass", "highpass", "bandpass", or "bandstop".
#' @param order Filter order (default: 4).
#'
#' @return Filtered data with the same dimensions as `x`.
#'
#' @details
#' Requires the \pkg{signal} package. NAs in the input are temporarily
#' interpolated before filtering and restored afterward.
#'
#' @references
#' Butterworth S (1930). "On the Theory of Filter Amplifiers."
#' Wireless Engineer, 7, 536-541.
#'
#' @seealso [filterSignals()] for filtering PhysioExperiment objects,
#'   [savgolFilter()] for Savitzky-Golay polynomial smoothing.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Filter a single vector
#' x <- sin(2 * pi * 5 * seq(0, 1, length.out = 1000)) +
#'      sin(2 * pi * 50 * seq(0, 1, length.out = 1000))
#' x_filt <- butterworthFilter(x, cutoff = 20, sampling_rate = 1000, type = "lowpass")
#' }
butterworthFilter <- function(x,
                              cutoff,
                              sampling_rate,
                              type = c("lowpass", "highpass", "bandpass", "bandstop"),
                              order = 4) {

  if (!requireNamespace("signal", quietly = TRUE)) {
    stop(
      "The 'signal' package is required for Butterworth filtering.\n",
      "Install it with: install.packages('signal')",
      call. = FALSE
    )
  }

  type <- match.arg(type)

  # Validate inputs
  stopifnot(is.numeric(cutoff), length(cutoff) >= 1)
  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1, sampling_rate > 0)
  stopifnot(is.numeric(order), length(order) == 1, order >= 1)

  nyquist <- sampling_rate / 2

  # Validate cutoff vs Nyquist
  if (any(cutoff >= nyquist)) {
    stop(
      sprintf(
        "Cutoff frequency (%.1f Hz) must be less than the Nyquist frequency (%.1f Hz).",
        max(cutoff), nyquist
      ),
      call. = FALSE
    )
  }
  if (any(cutoff <= 0)) {
    stop("Cutoff frequency must be positive.", call. = FALSE)
  }

  # Validate cutoff length for band filters

  if (type %in% c("bandpass", "bandstop")) {
    if (length(cutoff) != 2) {
      stop(
        sprintf("Filter type '%s' requires a length-2 cutoff vector c(low, high).", type),
        call. = FALSE
      )
    }
    if (cutoff[1] >= cutoff[2]) {
      stop("For band filters, cutoff[1] must be less than cutoff[2].", call. = FALSE)
    }
  }

  # Normalize cutoff to Nyquist (signal::butter expects W in [0,1])
  W <- cutoff / nyquist

  # Map type names to signal::butter convention
  signal_type <- switch(type,
    lowpass  = "low",
    highpass = "high",
    bandpass = "pass",
    bandstop = "stop"
  )

  # Design Butterworth filter
  bf <- signal::butter(n = order, W = W, type = signal_type)

  # Handle vector input
  if (is.numeric(x) && !is.matrix(x)) {
    return(.apply_butter_to_vector(x, bf))
  }

  # Handle matrix input (time x channels)
  if (!is.matrix(x)) {
    stop("Input must be a numeric vector or matrix.", call. = FALSE)
  }

  result <- matrix(NA_real_, nrow = nrow(x), ncol = ncol(x))
  colnames(result) <- colnames(x)

  for (j in seq_len(ncol(x))) {
    result[, j] <- .apply_butter_to_vector(x[, j], bf)
  }

  result
}


#' Apply Butterworth filter to a single vector with NA handling
#'
#' @param x Numeric vector.
#' @param bf Filter object from `signal::butter()`.
#' @return Filtered numeric vector.
#' @keywords internal
#' @noRd
.apply_butter_to_vector <- function(x, bf) {
  na_mask <- is.na(x)
  has_na <- any(na_mask)

  if (has_na) {
    x <- .interpolate_na_for_filter(x)
  }

  # Apply zero-phase filter
  filtered <- signal::filtfilt(bf, x)

  # Restore NAs

  if (has_na) {
    filtered[na_mask] <- NA_real_
  }

  as.numeric(filtered)
}


#' Savitzky-Golay filter for smoothing and differentiation
#'
#' Pure R implementation of the Savitzky-Golay filter using local polynomial
#' fitting. Useful for smoothing noisy signals while preserving features like
#' peak height and width better than simple moving averages.
#'
#' @param x A numeric vector or matrix (time x channels).
#' @param window_length Window length for the filter. Must be a positive odd
#'   integer.
#' @param poly_order Polynomial order for local fitting (must be less than
#'   `window_length`).
#' @param deriv Derivative order. 0 for smoothing, 1 for first derivative,
#'   2 for second derivative, etc.
#'
#' @return Filtered/smoothed data with the same dimensions as `x`.
#'
#' @details
#' The Savitzky-Golay filter fits a local polynomial of degree `poly_order`
#' to a window of `window_length` points, using least-squares. The filter
#' coefficients are computed analytically and applied via convolution.
#'
#' For differentiation (`deriv > 0`), the result is the derivative of the
#' fitted polynomial, which provides a smooth estimate of the derivative.
#'
#' Edge handling: the first and last `floor(window_length/2)` points are
#' computed with truncated windows where possible, or set to NA.
#'
#' @references
#' Savitzky A, Golay MJE (1964). "Smoothing and Differentiation of Data
#' by Simplified Least Squares Procedures." Analytical Chemistry, 36(8),
#' 1627-1639.
#'
#' @seealso [butterworthFilter()] for frequency-domain Butterworth filtering,
#'   [movingAverage()] for simple moving average smoothing,
#'   [differentiate()] for numerical differentiation.
#'
#' @export
#'
#' @examples
#' # Smooth a noisy sine wave
#' t <- seq(0, 2 * pi, length.out = 200)
#' x <- sin(t) + rnorm(200, sd = 0.2)
#' x_smooth <- savgolFilter(x, window_length = 11, poly_order = 3)
#'
#' # Compute first derivative
#' dx <- savgolFilter(x, window_length = 11, poly_order = 3, deriv = 1)
savgolFilter <- function(x, window_length = 11, poly_order = 3, deriv = 0) {

  # Validate inputs
  stopifnot(is.numeric(window_length), length(window_length) == 1)
  stopifnot(is.numeric(poly_order), length(poly_order) == 1)
  stopifnot(is.numeric(deriv), length(deriv) == 1, deriv >= 0)

  window_length <- as.integer(window_length)
  poly_order <- as.integer(poly_order)
  deriv <- as.integer(deriv)

  if (window_length < 1 || window_length %% 2 == 0) {
    stop("window_length must be a positive odd integer.", call. = FALSE)
  }
  if (poly_order >= window_length) {
    stop("poly_order must be less than window_length.", call. = FALSE)
  }
  if (deriv > poly_order) {
    stop("deriv must be <= poly_order.", call. = FALSE)
  }

  # Compute SG coefficients
  coeffs <- .savgol_coefficients(window_length, poly_order, deriv)

  # Handle vector input
  if (is.numeric(x) && !is.matrix(x)) {
    return(.apply_savgol_to_vector(x, coeffs, window_length))
  }

  # Handle matrix input (time x channels)
  if (!is.matrix(x)) {
    stop("Input must be a numeric vector or matrix.", call. = FALSE)
  }

  result <- matrix(NA_real_, nrow = nrow(x), ncol = ncol(x))
  colnames(result) <- colnames(x)

  for (j in seq_len(ncol(x))) {
    result[, j] <- .apply_savgol_to_vector(x[, j], coeffs, window_length)
  }

  result
}


#' Compute Savitzky-Golay filter coefficients
#'
#' Computes convolution coefficients for the Savitzky-Golay filter via
#' local polynomial fitting using the Vandermonde matrix approach.
#'
#' @param window_length Window length (odd integer).
#' @param poly_order Polynomial order.
#' @param deriv Derivative order.
#' @return Numeric vector of filter coefficients.
#' @keywords internal
#' @noRd
.savgol_coefficients <- function(window_length, poly_order, deriv) {

  half_window <- (window_length - 1L) %/% 2L
  # Position indices from -half_window to +half_window
  pos <- seq(-half_window, half_window)

  # Build Vandermonde-like matrix: each row is [1, i, i^2, ..., i^poly_order]
  J <- outer(pos, 0:poly_order, "^")

  # Solve for coefficients using pseudoinverse: (J'J)^-1 J'
  # The row of (J'J)^-1 J' corresponding to the derivative gives the
  # filter coefficients
  QR <- qr(J)
  Q <- qr.Q(QR)
  R <- qr.R(QR)

  # The coefficients for the d-th derivative are in row (d+1) of

  # solve(R) %*% t(Q), scaled by factorial(deriv)
  Rinv <- backsolve(R, diag(ncol(R)))
  coeffs_matrix <- Rinv %*% t(Q)

  # The (deriv+1)-th row gives coefficients for the deriv-th derivative
  coeffs <- coeffs_matrix[deriv + 1L, ] * factorial(deriv)

  coeffs
}


#' Apply Savitzky-Golay coefficients to a vector
#'
#' @param x Numeric vector.
#' @param coeffs SG filter coefficients.
#' @param window_length Window length.
#' @return Filtered numeric vector.
#' @keywords internal
#' @noRd
.apply_savgol_to_vector <- function(x, coeffs, window_length) {
  n <- length(x)
  half_window <- (window_length - 1L) %/% 2L

  if (n < window_length) {
    warning("Signal length is shorter than window_length. Returning NAs.",
            call. = FALSE)
    return(rep(NA_real_, n))
  }

  result <- rep(NA_real_, n)

  # Apply convolution for interior points
  for (i in (half_window + 1L):(n - half_window)) {
    idx <- (i - half_window):(i + half_window)
    result[i] <- sum(coeffs * x[idx])
  }

  # Handle edges: use reduced windows where possible
  # For the leading edge
  for (i in seq_len(half_window)) {
    # Mirror/reflect start: pad with reflected values
    pad_len <- half_window - i + 1L
    padded <- c(rev(x[2:(pad_len + 1L)]), x[1:min(i + half_window, n)])
    if (length(padded) >= window_length) {
      result[i] <- sum(coeffs * padded[1:window_length])
    }
  }

  # For the trailing edge
  for (i in (n - half_window + 1L):n) {
    pad_len <- i + half_window - n
    padded <- c(x[max(1, i - half_window):n],
                rev(x[(n - pad_len):(n - 1L)]))
    if (length(padded) >= window_length) {
      result[i] <- sum(coeffs * padded[1:window_length])
    }
  }

  result
}


#' Simple moving average filter
#'
#' Applies a symmetric moving average for quick smoothing of signal data.
#' Uses [stats::filter()] internally with equal weights.
#'
#' @param x A numeric vector or matrix (time x channels).
#' @param window Window size for the moving average (default: 5). Will be
#'   coerced to an odd integer.
#'
#' @return Smoothed data with the same dimensions as `x`. Edge values where
#'   the full window cannot be applied are set to NA.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [butterworthFilter()] for Butterworth low-pass filtering,
#'   [savgolFilter()] for Savitzky-Golay polynomial smoothing.
#'
#' @export
#'
#' @examples
#' # Smooth a noisy signal
#' x <- sin(seq(0, 4 * pi, length.out = 200)) + rnorm(200, sd = 0.3)
#' x_smooth <- movingAverage(x, window = 7)
movingAverage <- function(x, window = 5) {

  stopifnot(is.numeric(window), length(window) == 1, window >= 1)
  window <- as.integer(window)

  # Ensure odd window for symmetry
  if (window %% 2 == 0) {
    window <- window + 1L
  }

  weights <- rep(1 / window, window)

  # Handle vector input
  if (is.numeric(x) && !is.matrix(x)) {
    return(as.numeric(stats::filter(x, filter = weights, sides = 2)))
  }

  # Handle matrix input
  if (!is.matrix(x)) {
    stop("Input must be a numeric vector or matrix.", call. = FALSE)
  }

  result <- matrix(NA_real_, nrow = nrow(x), ncol = ncol(x))
  colnames(result) <- colnames(x)

  for (j in seq_len(ncol(x))) {
    result[, j] <- as.numeric(stats::filter(x[, j], filter = weights, sides = 2))
  }

  result
}


#' Temporarily interpolate NA values for filtering
#'
#' Uses linear interpolation to fill NA values so that filters can be applied.
#' Leading and trailing NAs are filled with the nearest non-NA value.
#'
#' @param x Numeric vector.
#' @return Numeric vector with NAs replaced by interpolated values.
#' @keywords internal
#' @noRd
.interpolate_na_for_filter <- function(x) {
  na_idx <- which(is.na(x))

  if (length(na_idx) == 0) return(x)
  if (all(is.na(x))) return(x)

  non_na_idx <- which(!is.na(x))

  # Use approx for interior NAs
  x_interp <- stats::approx(
    x = non_na_idx,
    y = x[non_na_idx],
    xout = seq_along(x),
    method = "linear",
    rule = 2  # extrapolate at edges using nearest value
  )$y

  x_interp
}
