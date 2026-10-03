# EMG Processing and MoCap Integration
# Includes rectification, RMS envelope, MVC normalization, and time alignment
# utilities for motion-capture workflows.

#' Rectify EMG signals
#'
#' @param x Numeric vector or matrix (time x channels).
#' @param method Rectification method: `"fullwave"` or `"halfwave"`.
#'
#' @return Rectified signal with the same dimensions as `x`.
#'
#' @references
#' Merletti R, Parker PA (2004). "Electromyography: Physiology, Engineering,
#' and Non-Invasive Applications." IEEE Press/Wiley.
#'
#' @seealso [computeRMSEnvelope()] for computing RMS envelope,
#'   [processEMG()] for complete EMG processing pipeline.
#'
#' @export
#'
#' @examples
#' x <- c(-1, -0.5, 0, 0.5, 1)
#' rectifyEMG(x, method = "fullwave")
rectifyEMG <- function(x, method = c("fullwave", "halfwave")) {
  method <- match.arg(method)

  if (!is.numeric(x)) {
    stop("x must be numeric.", call. = FALSE)
  }

  if (method == "fullwave") {
    return(abs(x))
  }

  pmax(x, 0)
}


#' Compute moving RMS envelope of EMG
#'
#' @param x Numeric vector or matrix (time x channels).
#' @param window_samples Window length in samples.
#' @param center Logical; if `TRUE`, uses centered window.
#'
#' @return RMS envelope with the same dimensions as `x`.
#'
#' @references
#' Merletti R, Parker PA (2004). "Electromyography: Physiology, Engineering,
#' and Non-Invasive Applications." IEEE Press/Wiley.
#'
#' @seealso [rectifyEMG()] for signal rectification,
#'   [normalizeEMG()] for MVC or peak normalization,
#'   [processEMG()] for complete EMG processing pipeline.
#'
#' @export
#'
#' @examples
#' set.seed(1)
#' sig <- rnorm(1000)
#' env <- computeRMSEnvelope(sig, window_samples = 50)
computeRMSEnvelope <- function(x, window_samples = 50L, center = TRUE) {
  stopifnot(is.numeric(window_samples), length(window_samples) == 1, window_samples >= 1)
  stopifnot(is.logical(center), length(center) == 1)

  window_samples <- as.integer(window_samples)

  if (is.matrix(x)) {
    out <- matrix(NA_real_, nrow = nrow(x), ncol = ncol(x))
    colnames(out) <- colnames(x)
    for (j in seq_len(ncol(x))) {
      out[, j] <- .moving_rms_vector(x[, j], window_samples = window_samples,
                                     center = center)
    }
    return(out)
  }

  if (!is.numeric(x)) {
    stop("x must be a numeric vector or matrix.", call. = FALSE)
  }

  .moving_rms_vector(x, window_samples = window_samples, center = center)
}


#' Normalize EMG by MVC or peak
#'
#' @param x Numeric vector or matrix (time x channels).
#' @param method Normalization method: `"mvc"` or `"peak"`.
#' @param mvc Numeric scalar or vector of MVC reference values. Required when
#'   `method = "mvc"`.
#' @param scale_percent Logical; if `TRUE`, returns percent scale (x100).
#'
#' @return Normalized signal with same dimensions as `x`.
#'
#' @references
#' Merletti R, Parker PA (2004). "Electromyography: Physiology, Engineering,
#' and Non-Invasive Applications." IEEE Press/Wiley.
#'
#' @seealso [rectifyEMG()] for signal rectification,
#'   [computeRMSEnvelope()] for RMS envelope computation,
#'   [processEMG()] for complete EMG processing pipeline.
#'
#' @export
#'
#' @examples
#' x <- matrix(abs(rnorm(500)), ncol = 2)
#' normalizeEMG(x, method = "peak")
normalizeEMG <- function(x,
                         method = c("mvc", "peak"),
                         mvc = NULL,
                         scale_percent = TRUE) {

  method <- match.arg(method)
  stopifnot(is.logical(scale_percent), length(scale_percent) == 1)

  if (!is.numeric(x)) {
    stop("x must be numeric.", call. = FALSE)
  }

  is_vec <- is.numeric(x) && !is.matrix(x)
  data <- if (is_vec) matrix(x, ncol = 1) else x

  if (method == "mvc") {
    if (is.null(mvc)) {
      stop("mvc must be provided when method = 'mvc'.", call. = FALSE)
    }

    if (!is.numeric(mvc)) {
      stop("mvc must be numeric.", call. = FALSE)
    }

    if (length(mvc) == 1) {
      denom <- rep(as.numeric(mvc), ncol(data))
    } else if (length(mvc) == ncol(data)) {
      denom <- as.numeric(mvc)
    } else {
      stop("mvc must be a scalar or have one value per channel.", call. = FALSE)
    }

  } else {
    denom <- apply(data, 2, max, na.rm = TRUE)
  }

  denom[!is.finite(denom) | denom == 0] <- NA_real_
  out <- sweep(data, 2, denom, "/")

  if (scale_percent) {
    out <- out * 100
  }

  if (is_vec) {
    return(as.numeric(out[, 1]))
  }

  out
}


#' Align EMG to motion-capture sampling grid
#'
#' @param emg Numeric vector or matrix of EMG data (time x channels).
#' @param emg_sampling_rate EMG sampling rate (Hz).
#' @param mocap_length Target number of MoCap samples.
#' @param mocap_sampling_rate Target MoCap sampling rate (Hz).
#' @param method Interpolation method passed to [stats::approx()].
#' @param emg_start_time,mocap_start_time Finite scalar start times in seconds
#'   on the same reference clock. Defaults assume both recordings start at zero.
#'   These are known offsets; no synchronization or clock drift is estimated.
#' @param outside Handling of target times outside each channel's finite-data
#'   support: `"extend"` repeats endpoints (compatibility default), `"NA"`
#'   leaves unavailable times missing, and `"error"` rejects the alignment.
#'   Fewer than two finite observations produce missing output, or an error
#'   under `"error"`. Internal gaps are still interpolated; this policy checks
#'   support boundaries, not internal gap duration. No anti-alias filter is added.
#'   Endpoint differences within floating-point roundoff are snapped to the
#'   endpoint (tolerance capped at one millionth of the shorter sample interval).
#'
#' @return Matrix of aligned EMG data with `mocap_length` rows.
#'
#' @references
#' Merletti R, Parker PA (2004). "Electromyography: Physiology, Engineering,
#' and Non-Invasive Applications." IEEE Press/Wiley.
#'
#' @seealso [integrateEMGMoCap()] for full EMG-MoCap integration,
#'   [resampleSignal()] for general signal resampling.
#'
#' @export
#'
#' @examples
#' emg <- matrix(rnorm(2000), ncol = 2)
#' emg_aligned <- alignEMGtoMoCap(emg, 1000, mocap_length = 200,
#'                                mocap_sampling_rate = 100)
alignEMGtoMoCap <- function(emg,
                            emg_sampling_rate,
                            mocap_length,
                            mocap_sampling_rate,
                            method = "linear",
                            emg_start_time = 0,
                            mocap_start_time = 0,
                            outside = c("extend", "NA", "error")) {

  outside <- match.arg(outside)
  scalar <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)
  if (!scalar(emg_sampling_rate) || emg_sampling_rate <= 0 ||
      !scalar(mocap_sampling_rate) || mocap_sampling_rate <= 0)
    stop("Sampling rates must be finite positive scalars.", call. = FALSE)
  if (!scalar(mocap_length) || mocap_length < 2 ||
      mocap_length != floor(mocap_length) || mocap_length > .Machine$integer.max)
    stop("mocap_length must be a finite integer >= 2 within integer range.", call. = FALSE)
  if (!scalar(emg_start_time) || !scalar(mocap_start_time))
    stop("Start times must be finite scalar seconds on a shared clock.", call. = FALSE)

  if (!is.numeric(emg)) {
    stop("emg must be numeric.", call. = FALSE)
  }

  emg_mat <- if (is.matrix(emg)) emg else matrix(emg, ncol = 1)
  n_emg <- nrow(emg_mat)
  if (!n_emg || !ncol(emg_mat))
    stop("emg must contain at least one sample and channel.", call. = FALSE)
  mocap_length <- as.integer(mocap_length)

  t_emg <- (seq_len(n_emg) - 1) / emg_sampling_rate
  # Work relative to the EMG origin to avoid adding a large common offset.
  t_mocap <- (mocap_start_time - emg_start_time) +
    (seq_len(mocap_length) - 1) / mocap_sampling_rate
  if (any(!is.finite(t_emg)) || any(!is.finite(t_mocap)) ||
      any(diff(t_emg) <= 0) || any(diff(t_mocap) <= 0) ||
      any(!is.finite(emg_start_time + t_emg)) ||
      any(!is.finite(emg_start_time + t_mocap)) ||
      any(diff(emg_start_time + t_emg) <= 0) ||
      any(diff(emg_start_time + t_mocap) <= 0))
    stop("Time grids must be finite and strictly increasing at numeric precision.", call. = FALSE)

  time_tol <- min(8 * .Machine$double.eps *
                    max(1, abs(emg_start_time), abs(mocap_start_time),
                        abs(t_emg), abs(t_mocap)),
                  min(1 / emg_sampling_rate, 1 / mocap_sampling_rate) * 1e-6)
  out <- matrix(NA_real_, nrow = mocap_length, ncol = ncol(emg_mat))
  colnames(out) <- colnames(emg_mat)

  for (j in seq_len(ncol(emg_mat))) {
    y <- emg_mat[, j]
    valid <- is.finite(y)

    if (sum(valid) < 2) {
      if (outside == "error")
        stop("Fewer than two finite EMG observations in channel ", j, ".", call. = FALSE)
      next
    }
    lo <- min(t_emg[valid]); hi <- max(t_emg[valid])
    target <- t_mocap
    target[abs(target - lo) <= time_tol] <- lo
    target[abs(target - hi) <= time_tol] <- hi
    if (outside == "error" && any(target < lo | target > hi))
      stop("Target times outside finite EMG support in channel ", j, ".", call. = FALSE)

    out[, j] <- stats::approx(
      x = t_emg[valid],
      y = y[valid],
      xout = target,
      method = method,
      rule = if (outside == "extend") 2 else 1
    )$y
  }

  out
}


#' Process EMG for biomechanics workflows
#'
#' Applies optional band-pass filtering, rectification, RMS envelope
#' extraction, optional low-pass smoothing, and optional MVC normalization.
#'
#' @param x Numeric vector or matrix (time x channels).
#' @param sampling_rate Sampling rate in Hz.
#' @param bandpass Optional length-2 numeric vector (Hz). If `NULL`, no
#'   band-pass filtering is applied.
#' @param envelope_cutoff Low-pass cutoff (Hz) applied to RMS envelope.
#' @param rms_window_ms RMS window length in milliseconds.
#' @param mvc Optional MVC value(s) for normalization.
#' @param filter_method Filter method used in low-pass steps.
#'
#' @return A list with `filtered`, `rectified`, `envelope`, and
#'   (when `mvc` is provided) `normalized`.
#'
#' @references
#' Merletti R, Parker PA (2004). "Electromyography: Physiology, Engineering,
#' and Non-Invasive Applications." IEEE Press/Wiley.
#'
#' @seealso [rectifyEMG()] for signal rectification,
#'   [computeRMSEnvelope()] for RMS envelope computation,
#'   [normalizeEMG()] for MVC or peak normalization,
#'   [integrateEMGMoCap()] for EMG-MoCap data integration.
#'
#' @export
#'
#' @examples
#' set.seed(1)
#' emg <- matrix(rnorm(2000), ncol = 2)
#' out <- processEMG(emg, sampling_rate = 1000)
processEMG <- function(x,
                       sampling_rate,
                       bandpass = c(20, 450),
                       envelope_cutoff = 6,
                       rms_window_ms = 50,
                       mvc = NULL,
                       filter_method = c("butterworth", "moving_average")) {

  filter_method <- match.arg(filter_method)
  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1, sampling_rate > 0)
  stopifnot(is.numeric(envelope_cutoff), length(envelope_cutoff) == 1,
            envelope_cutoff > 0)
  stopifnot(is.numeric(rms_window_ms), length(rms_window_ms) == 1,
            rms_window_ms > 0)

  if (!is.numeric(x)) {
    stop("x must be numeric.", call. = FALSE)
  }

  filtered <- x

  if (!is.null(bandpass)) {
    if (!is.numeric(bandpass) || length(bandpass) != 2 || bandpass[1] <= 0 ||
        bandpass[2] <= bandpass[1]) {
      stop("bandpass must be NULL or a length-2 increasing numeric vector.",
           call. = FALSE)
    }

    nyq <- sampling_rate / 2
    hi <- min(bandpass[2], nyq * 0.95)
    lo <- max(bandpass[1], 0.1)

    if (hi > lo) {
      if (filter_method == "butterworth" && requireNamespace("signal", quietly = TRUE)) {
        filtered <- butterworthFilter(
          filtered,
          cutoff = c(lo, hi),
          sampling_rate = sampling_rate,
          type = "bandpass",
          order = 4
        )
      } else {
        # Approximate fallback without external dependencies.
        lp <- filterGRF(filtered, sampling_rate = sampling_rate,
                        cutoff = hi, method = "moving_average")
        slow <- filterGRF(filtered, sampling_rate = sampling_rate,
                          cutoff = lo, method = "moving_average")
        filtered <- lp - slow
      }
    }
  }

  rectified <- rectifyEMG(filtered, method = "fullwave")

  window_samples <- as.integer(round(rms_window_ms / 1000 * sampling_rate))
  window_samples <- max(window_samples, 3L)

  envelope <- computeRMSEnvelope(rectified, window_samples = window_samples,
                                 center = TRUE)
  envelope <- filterGRF(envelope,
                        sampling_rate = sampling_rate,
                        cutoff = envelope_cutoff,
                        method = filter_method)

  out <- list(
    filtered = filtered,
    rectified = rectified,
    envelope = envelope
  )

  if (!is.null(mvc)) {
    out$normalized <- normalizeEMG(envelope, method = "mvc", mvc = mvc,
                                   scale_percent = TRUE)
  }

  out
}


#' Integrate EMG and MoCap signals onto a common timeline
#'
#' Processes EMG at its native sampling rate, then aligns the resulting envelope
#' (or MVC-normalized envelope) to MoCap sample times for feature analysis.
#' Start times must be expressed on a shared clock. Alignment uses linear
#' interpolation with the selected support policy; it does not estimate offsets.
#' With `process = FALSE`, raw samples are interpolated without anti-alias filtering.
#' With `outside = "NA"`, combined features remain missing outside raw-data
#' support even if processing produces finite values beyond that support.
#'
#' @param mocap A numeric matrix/data.frame (time x features), or a
#'   PhysioExperiment object.
#' @param emg Numeric vector or matrix (time x channels).
#' @param mocap_sampling_rate MoCap sampling rate in Hz. If `mocap` is a
#'   PhysioExperiment and this is `NULL`, uses `samplingRate(mocap)`.
#' @param emg_sampling_rate EMG sampling rate in Hz.
#' @param mocap_assay Assay name to use when `mocap` is a PhysioExperiment.
#' @param process Logical; if `TRUE`, runs `processEMG()` before combining.
#' @param ... Additional arguments passed to `processEMG()`.
#' @inheritParams alignEMGtoMoCap
#'
#' @return A list with `mocap`, `emg_aligned` (aligned raw EMG, retained for
#'   compatibility), and `combined` data.frame (processed EMG when requested).
#'
#' @references
#' Merletti R, Parker PA (2004). "Electromyography: Physiology, Engineering,
#' and Non-Invasive Applications." IEEE Press/Wiley.
#'
#' @seealso [processEMG()] for EMG processing pipeline,
#'   [alignEMGtoMoCap()] for time-alignment of EMG to MoCap,
#'   [synchronizeSignals()] for general multi-signal synchronization.
#'
#' @export
#'
#' @examples
#' mocap <- matrix(rnorm(500), ncol = 5)
#' emg <- matrix(rnorm(5000), ncol = 2)
#' out <- integrateEMGMoCap(mocap, emg, mocap_sampling_rate = 100,
#'                          emg_sampling_rate = 1000)
integrateEMGMoCap <- function(mocap,
                              emg,
                              mocap_sampling_rate = NULL,
                              emg_sampling_rate,
                              mocap_assay = NULL,
                              process = TRUE,
                              ...,
                              emg_start_time = 0,
                              mocap_start_time = 0,
                              outside = c("extend", "NA", "error")) {

  stopifnot(is.numeric(emg_sampling_rate), length(emg_sampling_rate) == 1,
            emg_sampling_rate > 0)
  stopifnot(is.logical(process), length(process) == 1)
  outside <- match.arg(outside)

  mocap_mat <- NULL

  if (inherits(mocap, "PhysioExperiment")) {
    if (is.null(mocap_assay)) {
      mocap_assay <- defaultAssay(mocap)
    }
    mocap_mat <- SummarizedExperiment::assay(mocap, mocap_assay)

    if (is.null(mocap_sampling_rate)) {
      mocap_sampling_rate <- samplingRate(mocap)
    }
  } else {
    if (!is.matrix(mocap) && !is.data.frame(mocap)) {
      stop("mocap must be a matrix/data.frame or PhysioExperiment.",
           call. = FALSE)
    }
    mocap_mat <- as.matrix(mocap)
  }

  if (!is.numeric(mocap_sampling_rate) || length(mocap_sampling_rate) != 1 ||
      mocap_sampling_rate <= 0) {
    stop("mocap_sampling_rate must be provided as a positive numeric value.",
         call. = FALSE)
  }

  emg_mat <- if (is.matrix(emg)) emg else matrix(emg, ncol = 1)

  emg_aligned <- alignEMGtoMoCap(
    emg_mat,
    emg_sampling_rate = emg_sampling_rate,
    mocap_length = nrow(mocap_mat),
    mocap_sampling_rate = mocap_sampling_rate,
    emg_start_time = emg_start_time, mocap_start_time = mocap_start_time,
    outside = outside
  )

  if (process) {
    processed <- processEMG(emg_mat,
                            sampling_rate = emg_sampling_rate,
                            ...)
    emg_features <- if (!is.null(processed$normalized)) {
      processed$normalized
    } else {
      processed$envelope
    }
    emg_features <- alignEMGtoMoCap(
      emg_features, emg_sampling_rate = emg_sampling_rate,
      mocap_length = nrow(mocap_mat),
      mocap_sampling_rate = mocap_sampling_rate,
      emg_start_time = emg_start_time, mocap_start_time = mocap_start_time,
      outside = outside
    )
    if (outside == "NA") emg_features[is.na(emg_aligned)] <- NA_real_
  } else {
    emg_features <- emg_aligned
  }

  mocap_df <- as.data.frame(mocap_mat)
  emg_df <- as.data.frame(emg_features)

  if (is.null(colnames(mocap_df))) {
    colnames(mocap_df) <- paste0("mocap_", seq_len(ncol(mocap_df)))
  } else {
    colnames(mocap_df) <- paste0("mocap_", colnames(mocap_df))
  }

  if (is.null(colnames(emg_df))) {
    colnames(emg_df) <- paste0("emg_", seq_len(ncol(emg_df)))
  } else {
    colnames(emg_df) <- paste0("emg_", colnames(emg_df))
  }

  combined <- data.frame(
    time = mocap_start_time + (seq_len(nrow(mocap_df)) - 1) / mocap_sampling_rate,
    mocap_df,
    emg_df,
    stringsAsFactors = FALSE
  )

  list(
    mocap = mocap_mat,
    emg_aligned = emg_aligned,
    combined = combined
  )
}


#' Moving RMS for a vector
#' @keywords internal
#' @noRd
.moving_rms_vector <- function(x, window_samples, center = TRUE) {
  n <- length(x)
  if (n == 0) {
    return(numeric(0))
  }

  if (window_samples <= 1) {
    return(abs(x))
  }

  out <- rep(NA_real_, n)
  x2 <- x^2

  if (center) {
    half <- window_samples %/% 2
    for (i in seq_len(n)) {
      lo <- max(1L, i - half)
      hi <- min(n, i + half)
      seg <- x2[lo:hi]
      if (any(is.finite(seg))) {
        out[i] <- sqrt(mean(seg, na.rm = TRUE))
      }
    }
  } else {
    for (i in seq_len(n)) {
      lo <- max(1L, i - window_samples + 1L)
      seg <- x2[lo:i]
      if (any(is.finite(seg))) {
        out[i] <- sqrt(mean(seg, na.rm = TRUE))
      }
    }
  }

  out
}
